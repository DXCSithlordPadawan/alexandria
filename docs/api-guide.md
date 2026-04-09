# Project Alexandria — API Guide
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Overview

Project Alexandria exposes two internal APIs consumed by the Librarian tool:

| API | Host | Port | Consumer |
|:----|:-----|:-----|:---------|
| Kiwix Search API | `kiwix` (internal bridge) | `8080` | `librarian_tool.py` |
| ChromaDB HTTP API | `chromadb` (ai-backend bridge) | `8000` | `librarian_tool.py`, `ingest_edits.py` |

The **Ollama API** is consumed by Open WebUI internally and is not directly accessed by researchers.

Neither API is externally reachable — all access is via the Open WebUI Librarian tool or administrative scripts running inside the container network.

---

## 2. Kiwix Search API

Kiwix-serve exposes an OpenSearch-compatible endpoint.

### 2.1 Search Endpoint

```
GET http://kiwix:8080/search
```

**Query parameters:**

| Parameter | Type | Required | Description |
|:----------|:-----|:--------:|:------------|
| `pattern` | string | ✅ | Search query (URL-encoded) |
| `pageLength` | integer | ❌ | Max results to return (default: 10, max: 50) |
| `start` | integer | ❌ | Offset for pagination (default: 0) |

**Example request:**
```
GET http://kiwix:8080/search?pattern=photosynthesis&pageLength=5
```

**Example response (JSON):**
```json
{
  "results": [
    {
      "title": "Photosynthesis",
      "snippet": "Photosynthesis is a process used by plants...",
      "path": "/A/Photosynthesis"
    }
  ],
  "totalResults": 1
}
```

**Error responses:**

| HTTP Code | Meaning |
|:----------|:--------|
| 200 | Success (may return empty `results` array if no match) |
| 503 | ZIM file not loaded (container starting or ZIM corrupt) |

### 2.2 Article Retrieval

```
GET http://kiwix:8080/A/<ArticleTitle>
```

Returns full article HTML. Used for deep reference; not currently called by the Librarian tool (search snippets are sufficient for RAG context).

### 2.3 Catalog

```
GET http://kiwix:8080/catalog/root.xml
```

Returns OPDS XML listing all loaded ZIM files. Used by healthcheck.

---

## 3. ChromaDB HTTP API

ChromaDB exposes a REST API for collection management and vector querying.

**Base URL (internal):** `http://chromadb:8000`

### 3.1 Heartbeat

```
GET /api/v1/heartbeat
```

Returns `{"nanosecond heartbeat": <timestamp>}` when healthy.

### 3.2 List Collections

```
GET /api/v1/collections
```

Returns all collection names. The Librarian uses the `local_edits` collection.

### 3.3 Query a Collection

```
POST /api/v1/collections/{collection_id}/query
Content-Type: application/json
```

**Request body:**
```json
{
  "query_texts": ["your search query here"],
  "n_results": 5,
  "include": ["documents", "metadatas", "distances"]
}
```

**Response:**
```json
{
  "ids": [["local_edits::chunk::0"]],
  "documents": [["chunk content here..."]],
  "metadatas": [[{"source": "my-topic.md", "title": "My Topic", "file_hash": "abc123"}]],
  "distances": [[0.23]]
}
```

### 3.4 Upsert Documents (used by ingest_edits.py)

```
POST /api/v1/collections/{collection_id}/upsert
Content-Type: application/json
```

**Request body:**
```json
{
  "ids": ["local_edits::chunk::0"],
  "documents": ["chunk text..."],
  "metadatas": [{"source": "file.md", "title": "Title", "file_hash": "abc"}]
}
```

### 3.5 Delete Documents

```
POST /api/v1/collections/{collection_id}/delete
Content-Type: application/json

{"where": {"source": "old-file.md"}}
```

---

## 4. Librarian Tool API (Open WebUI)

The Librarian is registered as an Open WebUI Tool. It is invoked by the LLM when the user asks a research question.

### 4.1 Tool Method

**Class:** `Tools`
**Method:** `search(query: str) -> str`

**Input:** Natural language query string (max 512 chars, alphanumeric + basic punctuation)

**Output:** Formatted Markdown string with results prefixed `[Local Edit]` or `[Wikipedia]`, or the hallucination guard string if nothing is found.

**Example output:**
```
**Local Edit results:**

[Local Edit] **JSP 939 Compliance**
JSP 939 defines the UK MoD policy for modelling and simulation...

**Additional Wikipedia context:**

[Wikipedia] **Modelling and simulation** (see local edit for authoritative version)
Modelling and simulation (M&S) involves using models...
```

**Hallucination guard response:**
```
The local archives do not contain information on this topic.
```

---

## 5. Ollama API (Internal Reference)

The Ollama API is consumed exclusively by Open WebUI. Direct access is via `http://ollama:11434`.

| Endpoint | Method | Purpose |
|:---------|:-------|:--------|
| `/api/tags` | GET | List loaded models |
| `/api/generate` | POST | Single-turn generation |
| `/api/chat` | POST | Multi-turn chat (used by WebUI) |
| `/api/pull` | POST | Pull a new model |

Refer to the [Ollama API documentation](https://github.com/ollama/ollama/blob/main/docs/api.md) for full reference.
