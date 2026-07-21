# secrets.template.md

**This file lists which credentials a rebuilt machine needs, and where to get each one. It contains no values.**

Commit this file. The values live in your password manager, because a list of values would die with the laptop it was written on, which defeats the point.

An ignore rule of `secrets*` would normally exclude this file, so negate it back in with `!secrets.template.md` placed after that rule.

---

## 1. Locally-registered tool servers

These are the ones configured on your machine. Most tool servers are not: they are connected at the account level and come back on login, so they belong in section 2 rather than here.

| Server | Environment variable | Where to get it |
|---|---|---|
| `<server-name>` | `<VAR_NAME>` | `<provider>` dashboard, under API tokens |

Verify this list rather than trusting it. Run `claude mcp list` and compare. A list like this drifts as servers are added and removed, and a stale entry sends the next person hunting for a credential that nothing uses any more.

## 2. Account-level connectors

These are **not** local configuration. They live in your Claude account and return automatically when you log in on the new machine. Nothing to re-enter.

List them here anyway, by name, so that a rebuild can confirm each one came back rather than discovering a gap months later.

- `<connector-name>`

## 3. Per-project secrets

One row per variable that a project needs and that is not in its committed `.env.example`.

| Project | Variable | Where to get it |
|---|---|---|
| `<project>` | `<VAR_NAME>` | `<origin system>` |

## 4. SSH keys

| Key | Location | Notes |
|---|---|---|
| `<name>` | `~/.ssh/<name>` | Restore from the password manager. Then `chmod 700 ~/.ssh` and `chmod 600` the key itself. The directory needs execute permission or nothing inside it is readable |

## 5. Rotation status

The section people skip and later regret.

Scrubbing a credential out of a repository does not make it dead. It is still live in whatever system issued it. Record here which ones are exposed but not yet rotated, and what breaks if you rotate them.

| Credential | Exposed where | Rotated? | What breaks if rotated |
|---|---|---|---|
| `<name>` | `<repo or file>` | No | `<the systems that depend on it>` |

A shared credential used by several live integrations has to be migrated one integration at a time before it can be rotated, or they all break at once. Write that dependency down here while you still remember it.
