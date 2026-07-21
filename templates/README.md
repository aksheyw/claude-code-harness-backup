# Templates

Starting points, meant to be copied and edited. Nothing here is specific to any
one project.

| File | Copy it to | What it does |
|---|---|---|
| `.env.example` | your project root | Records which environment variables exist and where each value comes from. Commit it. Never commit the real `.env` |
| `secrets.template.md` | your project root, or your backup repo | An inventory of every credential a rebuilt machine needs, by name and origin, with no values |
| `CLAUDE.md.template` | `CLAUDE.md` in your project root | Standing context Claude Code reads at the start of every session in that repository |
| `gitignore.baseline` | `.gitignore` in your project root | A safe default, including the negation pattern that stops your assistant's configuration being silently untracked |
| `wiki-schema.md` | `.claude/wiki/_schema.md` | The conventions for a project wiki that compounds across sessions |

The two worth reading rather than just copying are `gitignore.baseline`, because
of the `.claude/` trap it documents, and `secrets.template.md`, because of its
last section on rotation.
