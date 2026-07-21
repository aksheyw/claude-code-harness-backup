---
created: 2026-01-01
updated: 2026-01-01
source: the template this wiki was started from
tags: [meta, schema]
aliases: []
status: stable
confidence: high
---

# Wiki schema

The rules this wiki follows. A project wiki is a folder of notes that survives
between sessions, so that knowledge which took effort to work out does not have
to be worked out again.

## 1. What goes in, and what does not

**The bar: capture only what is non-obvious and durable.** If a future reader
could re-derive it from the code or the commit history, leave it out.

A wiki full of restated code is worse than no wiki. It costs attention on every
lookup and it rots silently, because nobody notices when a restatement drifts
out of step with the thing it restates.

Worth writing down: a bug whose root cause was surprising, why an approach was
rejected, a constraint imposed from outside, a trap in a third-party tool.

## 2. Folders and file names

Topic pages are `lowercase-kebab-case.md` inside a folder named for their kind,
with a prefix that repeats the kind so the filename is readable on its own.

| Folder | Holds | Prefix |
|---|---|---|
| `decisions/` | A choice made, and what was rejected | `d-` |
| `gotchas/` | A trap and how to avoid it | `gotcha-` |
| `architecture/` | How a part of the system fits together | none |

## 3. The meta pages

Prefixed with an underscore so they sort to the top.

| File | Purpose |
|---|---|
| `_index.md` | The navigator. What exists and where |
| `_hot.md` | Current focus. Kept small and rewritten often, not appended to |
| `_log.md` | One line per session |
| `_findings.md` | Open problems, each with a severity and a status |
| `_schema.md` | This file |

## 4. Frontmatter

Seven fields, on every page.

| Field | Values |
|---|---|
| `created` | `YYYY-MM-DD` |
| `updated` | `YYYY-MM-DD`, bumped on every meaningful edit |
| `source` | Where this came from: a file path, a session, or a URL |
| `tags` | `category/subcategory`, lowercase |
| `aliases` | Other names for this topic. `[]` if none, because empty is honest |
| `status` | `stable`, `evolving`, `uncertain`, or `deprecated` |
| `confidence` | `high`, `medium`, or `low` |

**`source` and `confidence` are the two that carry the weight.** Together they
let a later reader tell a verified fact from somebody's confident guess, which
is otherwise impossible once both are sitting in the same tidy paragraph.

Expect more fields to appear as a wiki grows past roughly twenty pages. That is
normal, not drift. Add them here when they do, so the vocabulary stays shared.

## 5. Page rules

- Under about 150 lines. Longer than that, split it.
- Every factual claim carries an inline citation.
- At least two links to other pages, or tag it as a leaf on purpose.
- Use `[[wiki-links]]` only for pages inside this wiki. Anything outside gets a
  normal markdown link.
