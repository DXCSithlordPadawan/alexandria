"""
librarian_tool.py — Alexandria Research Librarian Tool
=======================================================
Compliance: OWASP A03:2021 (Injection prevention), NIST SI-10 (Input validation)
Author: Iain Reid
Version: 1.0.0

Registers as an Open WebUI Tool that bridges the LLM to:
  - Local Kiwix Wikipedia API  (FR-3, FR-5)
  - Local Markdown edits via ChromaDB RAG  (FR-6, FR-7)

Priority rule (FR-7): Local Edits always override Wikipedia on factual conflict.
Citation prefixes: [Wikipedia] or [Local Edit] on every result.
Hallucination guard: returns explicit "not found" string when no local data exists.

Dependencies (installed in Containerfile):
    chromadb==0.6.3
    httpx==0.28.1
    sentence-transformers==3.4.1
"""

from __future__ import annotations

import logging
import os
import re
from typing import Any

import chromadb
import httpx

logger = logging.getLogger(__name__)

# ── Configuration (injected from environment) ─────────────────────────────────
_KIWIX_HOST: str = os.environ.get("KIWIX_HOST", "kiwix")
_KIWIX_PORT: int = int(os.environ.get("KIWIX_PORT", "8080"))
_CHROMA_HOST: str = os.environ.get("CHROMA_HOST", "chromadb")
_CHROMA_PORT: int = int(os.environ.get("CHROMA_PORT", "8000"))
_CHROMA_COLLECTION: str = "local_edits"
_MAX_RESULTS: int = 5
_KIWIX_TIMEOUT: float = 10.0

# Hallucination guard string (FR-7)
_NOT_FOUND_MSG = "The local archives do not contain information on this topic."

# Allowed characters in a search query (OWASP A03 — injection prevention)
_SAFE_QUERY_RE = re.compile(r"^[\w\s\-\(\)\.\,\'\"]{1,512}$", re.UNICODE)


def _sanitise_query(query: str) -> str:
    """Validate and sanitise user query. Raises ValueError on unsafe input."""
    stripped = query.strip()
    if not stripped:
        raise ValueError("Query must not be empty.")
    if not _SAFE_QUERY_RE.match(stripped):
        raise ValueError("Query contains disallowed characters.")
    return stripped


def _search_kiwix(query: str) -> list[dict[str, str]]:
    """
    Query the local Kiwix search API.

    Returns a list of result dicts with keys: title, snippet, url.
    Returns empty list on any network or parse error (fail-safe).
    """
    url = f"http://{_KIWIX_HOST}:{_KIWIX_PORT}/search"
    params: dict[str, Any] = {"pattern": query, "pageLength": _MAX_RESULTS}
    try:
        with httpx.Client(timeout=_KIWIX_TIMEOUT) as client:
            response = client.get(url, params=params)
            response.raise_for_status()
    except httpx.HTTPError as exc:
        logger.warning("Kiwix search failed: %s", exc)
        return []

    # Kiwix returns OpenSearch suggestions or OPDS; parse simple JSON response
    try:
        data = response.json()
    except Exception:
        logger.warning("Kiwix response was not valid JSON")
        return []

    results: list[dict[str, str]] = []
    for item in data.get("results", [])[:_MAX_RESULTS]:
        results.append(
            {
                "title": item.get("title", ""),
                "snippet": item.get("snippet", ""),
                "url": f"http://{_KIWIX_HOST}:{_KIWIX_PORT}{item.get('path', '')}",
            }
        )
    return results


def _search_local_edits(query: str) -> list[dict[str, str]]:
    """
    Query ChromaDB for relevant local Markdown edits.

    Returns a list of result dicts with keys: title, snippet, source.
    Returns empty list on any error (fail-safe).
    """
    try:
        client = chromadb.HttpClient(host=_CHROMA_HOST, port=_CHROMA_PORT)
        collection = client.get_or_create_collection(_CHROMA_COLLECTION)
        results = collection.query(
            query_texts=[query],
            n_results=_MAX_RESULTS,
            include=["documents", "metadatas", "distances"],
        )
    except Exception as exc:
        logger.warning("ChromaDB query failed: %s", exc)
        return []

    hits: list[dict[str, str]] = []
    documents = results.get("documents", [[]])[0]
    metadatas = results.get("metadatas", [[]])[0]

    for doc, meta in zip(documents, metadatas):
        hits.append(
            {
                "title": meta.get("title", meta.get("source", "Local Edit")),
                "snippet": doc[:500],  # truncate for context window safety
                "source": meta.get("source", ""),
            }
        )
    return hits


def _format_response(
    local_hits: list[dict[str, str]],
    wiki_hits: list[dict[str, str]],
    query: str,
) -> str:
    """
    Build the final librarian response following the system prompt rules:
      - Local Edits take priority (FR-7)
      - Each result is prefixed [Wikipedia] or [Local Edit]
      - Hallucination guard fires when nothing is found
    """
    sections: list[str] = []

    # Priority 1: Local Edits
    if local_hits:
        sections.append("**Local Edit results:**")
        for hit in local_hits:
            sections.append(
                f"[Local Edit] **{hit['title']}**\n{hit['snippet']}"
            )

    # Priority 2: Wikipedia (only shown if no local edit conflicts)
    if wiki_hits and not local_hits:
        sections.append("**Wikipedia (Kiwix) results:**")
        for hit in wiki_hits:
            sections.append(
                f"[Wikipedia] **{hit['title']}**\n{hit['snippet']}\n"
                f"Source: {hit['url']}"
            )
    elif wiki_hits and local_hits:
        # Append wiki results with a conflict notice
        sections.append("\n**Additional Wikipedia context:**")
        for hit in wiki_hits:
            sections.append(
                f"[Wikipedia] **{hit['title']}** (see local edit for authoritative version)\n"
                f"{hit['snippet']}"
            )

    if not sections:
        return _NOT_FOUND_MSG

    return "\n\n".join(sections)


# ── Open WebUI Tool entrypoint ────────────────────────────────────────────────

class Tools:
    """Alexandria Librarian — Open WebUI tool class."""

    def search(self, query: str) -> str:
        """
        Search the local Alexandria knowledge base.

        Args:
            query: The research question or topic to search for.

        Returns:
            Formatted results from local edits and/or Wikipedia mirror.
            Results are prefixed [Local Edit] or [Wikipedia].
            Returns a "not found" message if the archives contain no match.
        """
        try:
            safe_query = _sanitise_query(query)
        except ValueError as exc:
            return f"Invalid query: {exc}"

        logger.info("Librarian search: %r", safe_query)

        local_hits = _search_local_edits(safe_query)
        wiki_hits = _search_kiwix(safe_query)

        return _format_response(local_hits, wiki_hits, safe_query)
