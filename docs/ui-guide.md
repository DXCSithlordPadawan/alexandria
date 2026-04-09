# Project Alexandria — User Interface Guide
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Overview

The Alexandria user interface is **Open WebUI**, a web-based chat application that connects to the Ollama LLM backend and exposes the Alexandria Librarian as a built-in tool. Access is via browser at `https://alexandria.internal`.

---

## 2. Interface Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ☰  Alexandria        [Model: Alexandria Librarian ▼]   👤  │  ← Top bar
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│  Sidebar     │           Chat area                         │
│              │                                              │
│  + New Chat  │   You: What is the boiling point of         │
│              │         tungsten?                            │
│  Recent:     │                                              │
│  > Tungsten  │   Librarian: [Wikipedia] **Tungsten**        │
│  > JSP 939   │   The boiling point of tungsten is          │
│              │   5,555 °C (10,031 °F)...                   │
│              │                                              │
│              │                                              │
│              ├──────────────────────────────────────────────│
│              │  [ Ask the Librarian...              ] Send  │  ← Input
└──────────────┴──────────────────────────────────────────────┘
```

---

## 3. Key UI Elements

### 3.1 Model Selector (top bar)

Displays the currently active model. For Alexandria, this should always be set to the **Alexandria Librarian** configuration (the model + system prompt + Librarian tool). Click to switch models if you have been given access to others.

### 3.2 New Chat button (sidebar)

Creates a fresh conversation. The Librarian has no memory between sessions — each New Chat starts with a clean context.

### 3.3 Chat History (sidebar)

Lists your recent conversations. Click any to resume it. Conversations are stored locally in the Open WebUI database.

### 3.4 Message Input (bottom)

Type your query here. Supports multi-line input (Shift+Enter for new line). Press Enter or click **Send** to submit.

### 3.5 Response area

Responses render as Markdown — headings, bullet points, bold text, and code blocks are formatted automatically.

---

## 4. Model and Tool Configuration (AI Architect / Admin)

### 4.1 Registering the Librarian Tool

1. Log in as Admin.
2. Navigate to **Settings → Tools**.
3. Click **+ Add Tool**.
4. Upload or paste the content of `librarian_tool.py`.
5. Set the tool name to `Alexandria Librarian Search`.
6. Save.

### 4.2 Creating the Librarian Model Profile

1. Navigate to **Settings → Models → + Create Model**.
2. Set the base model to your Ollama model (e.g. `llama3.2`).
3. Paste the system prompt from PRD Section 7 into the **System Prompt** field:

```
# Role
You are the Alexandria Research Librarian. Your goal is to provide objective,
fact-based information derived solely from the local Wikipedia mirror.

# Constraints
1. Source Primacy: Prioritize information found in the local Wikipedia
   (Kiwix) and Local Edits.
2. Citation: Prefix information with [Wikipedia] or [Local Edit].
3. Hallucination Guard: If the local data does not contain the answer,
   state: "The local archives do not contain information on this topic."
4. Conflict Resolution: If a Local Edit contradicts Wikipedia, the
   Local Edit is the single source of truth.

# Structure
- Summary: 2-3 sentence overview.
- Key Facts: Bulleted list of data points.
- Cross-References: Suggest 3 related local topics.
```

4. Under **Tools**, enable **Alexandria Librarian Search**.
5. Save and set as the default model for Researcher accounts.

### 4.3 User Management

Navigate to **Settings → Users**:

| Action | How |
|:-------|:----|
| Approve a new user | Change status from `Pending` to `User` |
| Promote to Admin | Change role from `User` to `Admin` |
| Disable a user | Set status to `Disabled` |

---

## 5. Keyboard Shortcuts

| Shortcut | Action |
|:---------|:-------|
| `Enter` | Send message |
| `Shift + Enter` | New line in message |
| `Ctrl + /` | Open keyboard shortcuts help (if enabled) |

---

## 6. Accessibility

Open WebUI supports standard browser accessibility features. Use your browser's built-in zoom (`Ctrl +` / `Ctrl -`) to adjust text size. The interface is keyboard-navigable for users who cannot use a mouse.

---

## 7. Troubleshooting UI Issues

| Symptom | Likely cause | Action |
|:--------|:-------------|:-------|
| Page does not load | Service down | SysAdmin checks `podman ps` |
| Model not responding | Ollama not healthy | SysAdmin checks `podman logs alexandria-ollama` |
| Tool not appearing | Tool not registered | AI Architect re-registers librarian_tool.py |
| Results show no citations | System prompt not applied | AI Architect verifies model profile has system prompt |
| Slow responses | LLM inference load | SysAdmin checks `cpus` limit on ollama container |
