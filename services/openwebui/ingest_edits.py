"""
ingest_edits.py — Local Markdown Overlay RAG Ingestor
======================================================
Compliance: NIST SI-12 (Information Management), OWASP A03 (path traversal prevention)
Author: Iain Reid
Version: 1.0.0

Walks /data/edits, reads all Markdown files, chunks them, embeds them,
and upserts into the ChromaDB collection 'local_edits'.

Run manually or via a systemd oneshot / cron after adding new edit files:
    python ingest_edits.py [--edits-dir /data/edits] [--chroma-host chromadb]

Supports incremental updates — only changed files are re-ingested
(tracked by comparing stored metadata hash vs current sha256).
"""

from __future__ import annotations

import argparse
import hashlib
import logging
import os
import re
import sys
from pathlib import Path
from typing import Generator

import chromadb
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

# ── Constants ─────────────────────────────────────────────────────────────────
COLLECTION_NAME = "local_edits"
CHUNK_SIZE = 800        # characters per chunk (≈200 tokens)
CHUNK_OVERLAP = 100     # character overlap between chunks
EMBEDDING_MODEL = "all-MiniLM-L6-v2"  # lightweight, runs CPU-only

# Path traversal guard — only .md files within the edits root are processed
_ALLOWED_EXTENSION = ".md"


def _file_sha256(path: Path) -> str:
    """Return hex SHA-256 of file content for change detection."""
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def _is_safe_path(base: Path, candidate: Path) -> bool:
    """
    Prevent path traversal (OWASP A01/A03).
    Returns True only if candidate is a real descendant of base.
    """
    try:
        candidate.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def _chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Split text into overlapping chunks for embedding."""
    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + size, len(text))
        chunks.append(text[start:end])
        start += size - overlap
    return chunks


def _markdown_title(content: str, fallback: str) -> str:
    """Extract first H1 heading from Markdown, or use filename fallback."""
    match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
    return match.group(1).strip() if match else fallback


def iter_markdown_files(edits_dir: Path) -> Generator[Path, None, None]:
    """
    Yield .md files from edits_dir recursively.
    Guards against path traversal and symlink attacks.
    """
    for path in sorted(edits_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() != _ALLOWED_EXTENSION:
            continue
        if path.is_symlink():
            logger.warning("Skipping symlink: %s", path)
            continue
        if not _is_safe_path(edits_dir, path):
            logger.warning("Path traversal attempt blocked: %s", path)
            continue
        yield path


def ingest(
    edits_dir: Path,
    chroma_host: str,
    chroma_port: int,
    force: bool = False,
) -> None:
    """
    Main ingest routine.

    Args:
        edits_dir:  Root directory of local Markdown edits.
        chroma_host: ChromaDB hostname.
        chroma_port: ChromaDB port.
        force:      If True, re-ingest all files even if unchanged.
    """
    if not edits_dir.is_dir():
        logger.error("Edits directory not found: %s", edits_dir)
        sys.exit(1)

    embedding_fn = SentenceTransformerEmbeddingFunction(model_name=EMBEDDING_MODEL)
    client = chromadb.HttpClient(host=chroma_host, port=chroma_port)
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=embedding_fn,
    )

    files_processed = 0
    chunks_upserted = 0

    for md_path in iter_markdown_files(edits_dir):
        file_hash = _file_sha256(md_path)
        relative = str(md_path.relative_to(edits_dir))

        # Check if already ingested and unchanged
        if not force:
            existing = collection.get(
                where={"source": relative, "file_hash": file_hash},
                limit=1,
            )
            if existing["ids"]:
                logger.debug("Unchanged, skipping: %s", relative)
                continue

        # Remove stale chunks for this file (re-ingest fresh)
        collection.delete(where={"source": relative})

        content = md_path.read_text(encoding="utf-8", errors="replace")
        title = _markdown_title(content, md_path.stem)
        chunks = _chunk_text(content)

        ids = [f"{relative}::chunk::{i}" for i in range(len(chunks))]
        metadatas = [
            {
                "source": relative,
                "title": title,
                "file_hash": file_hash,
                "chunk_index": i,
                "total_chunks": len(chunks),
            }
            for i in range(len(chunks))
        ]

        collection.upsert(ids=ids, documents=chunks, metadatas=metadatas)
        chunks_upserted += len(chunks)
        files_processed += 1
        logger.info("Ingested: %s (%d chunks)", relative, len(chunks))

    logger.info(
        "Ingest complete — %d files, %d chunks upserted",
        files_processed,
        chunks_upserted,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ingest local Markdown edits into ChromaDB for RAG."
    )
    parser.add_argument(
        "--edits-dir",
        type=Path,
        default=Path(os.environ.get("EDITS_PATH", "/data/edits")),
        help="Path to the local edits directory (default: /data/edits)",
    )
    parser.add_argument(
        "--chroma-host",
        default=os.environ.get("CHROMA_HOST", "chromadb"),
        help="ChromaDB hostname (default: chromadb)",
    )
    parser.add_argument(
        "--chroma-port",
        type=int,
        default=int(os.environ.get("CHROMA_PORT", "8000")),
        help="ChromaDB port (default: 8000)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force re-ingest all files regardless of change detection",
    )
    args = parser.parse_args()

    logger.info(
        "Starting ingest: edits_dir=%s, chroma=%s:%d, force=%s",
        args.edits_dir,
        args.chroma_host,
        args.chroma_port,
        args.force,
    )
    ingest(
        edits_dir=args.edits_dir,
        chroma_host=args.chroma_host,
        chroma_port=args.chroma_port,
        force=args.force,
    )


if __name__ == "__main__":
    main()
