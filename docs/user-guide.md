# Project Alexandria — User Guide
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Introduction

Project Alexandria gives you a private, AI-powered research assistant that works entirely offline. You can ask it questions in plain English and it will search the full English Wikipedia (local mirror) and any specialist notes your team has written, then give you a cited answer.

All data stays on your local system. Nothing is sent to the internet when you are researching.

---

## 2. Accessing Alexandria

Open your web browser and navigate to:

```
https://alexandria.internal
```

(Replace `alexandria.internal` with the hostname your SysAdmin has configured.)

You will be prompted to log in with your Open WebUI credentials. Contact your SysAdmin if you do not have an account.

---

## 3. Asking the Research Librarian

### 3.1 Starting a conversation

1. Click **New Chat** in the left sidebar.
2. Make sure the model shown at the top is set to **Alexandria Librarian** (or the model your AI Architect has configured).
3. Type your question in the message box and press **Enter** or click **Send**.

### 3.2 Understanding the response format

Every answer from the Librarian is structured as follows:

**Citation prefixes** — every piece of information is labelled:

| Prefix | Meaning |
|:-------|:--------|
| `[Local Edit]` | From your team's specialist Markdown notes — this is the authoritative source |
| `[Wikipedia]` | From the local Wikipedia mirror |

**If the Librarian cannot find an answer**, it will say:
> *The local archives do not contain information on this topic.*

This means neither the local notes nor Wikipedia contain relevant information. Do not assume the information does not exist — the answer may simply not be in the current ZIM version or local edits.

### 3.3 Example queries

Good queries are specific and factual:

| Query | What you get |
|:------|:------------|
| `"What is the boiling point of tungsten?"` | Wikipedia result with citation |
| `"Summarise JSP 939 modelling policy"` | Local Edit result if your team has written one |
| `"What are the key provisions of the Ottawa Treaty?"` | Wikipedia result |
| `"Compare FIPS 140-2 and FIPS 140-3"` | Wikipedia + any local edits on the topic |

Avoid vague queries like `"Tell me about stuff"` — the Librarian needs a specific topic to search.

---

## 4. Writing Local Edits

Local Edits are Markdown files your team writes to correct, extend, or specialise Wikipedia information. They take priority over Wikipedia in Librarian responses.

### 4.1 File location

Local edits live in:
```
/mnt/pve/alexandria/edits/
```

If you do not have direct filesystem access, ask your AI Architect to add your file.

### 4.2 File format

```markdown
# Title of Your Edit

Brief description of what this edit covers.

## Key Facts

- Fact one
- Fact two

## Notes

Any additional context, corrections, or specialist detail.
```

Rules:
- The **first line must be a `# Heading`** — this becomes the result title in Librarian responses.
- Use standard Markdown formatting.
- Keep each file focused on **one topic** for best retrieval accuracy.
- Filename: `your-topic-name.md` (lowercase, hyphens, no spaces).

### 4.3 Getting your edit into the Librarian

After saving a new or updated `.md` file, ask your AI Architect to run the ingest command. Your edit will be searchable within a few minutes.

---

## 5. Tips for Best Results

- **Be specific.** "Describe the Krebs cycle" works better than "explain chemistry".
- **Ask follow-up questions.** The conversation history is maintained — you can ask the Librarian to expand on a result.
- **Check the source prefix.** If a result is marked `[Wikipedia]` and you have more accurate specialist knowledge, consider writing a Local Edit to override it.
- **Use cross-references.** The Librarian's system prompt asks it to suggest related topics — follow these to explore connected subjects.

---

## 6. Known Limitations

| Limitation | Detail |
|:-----------|:-------|
| Knowledge currency | The Wikipedia ZIM is updated weekly (Sunday). Very recent events may not be indexed. |
| Language | English Wikipedia only. |
| No real-time web search | Alexandria is offline-first by design. It does not search the internet. |
| ZIM coverage | Some niche topics may have sparse Wikipedia coverage. Use Local Edits to supplement. |
| Image and media | The Librarian returns text only. Full article media is available via the Kiwix reader. |

---

## 7. Getting Help

| Issue | Who to contact |
|:------|:--------------|
| Cannot log in | SysAdmin |
| Librarian gives wrong answer | AI Architect (consider writing a Local Edit) |
| Missing topic in Wikipedia | AI Architect or Researcher (write a Local Edit) |
| System slow or unavailable | SysAdmin |
