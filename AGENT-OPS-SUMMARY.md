# Reach the Streets — Agent-Ops Base & Schema Summary

**Prepared by:** Brick (Operations Ally)
**Date:** 2026-10-12
**Audience:** Reach the Streets team

---

## 1. What this is

This is the foundation layer that lets Brick — the Reach the Streets operations Ally — run the business day to day. It gives Brick a place to track clients, tasks, billing, and its own work, with everything auditable and recoverable.

## 2. The base (accounts & access)

| Layer | What was built |
|---|---|
| **GitHub** | Own account `BrickTheAlly`, repo `reach-the-streets` (remote `https://github.com/BrickTheAlly/reach-the-streets.git`), and a PAT for programmatic git + API access — verified 2026-10-31 via `git ls-remote` returning `HEAD 01a961b`; remote wired and pushed 2026-10-31 |
| **Supabase** | Own project `reachthestreets-operations` + secret/publishable API keys (stored locked-down, verified working) |
| **Identity** | SOUL.md, IDENTITY.md, USER.md, AGENTS.md, KNOWLEDGE.md wired into the database |

## 3. The database schema — two layers

### 3a. Business tables (client-facing work)
`clients`, `tasks`, `billing`, `activity_log`, `deliverables`, `blockers` — the operational record of serving inmates.

### 3b. Agent-ops tables (new — Brick's own record-keeping)

| Table | Purpose | Why it exists |
|---|---|---|
| `agent_tasks` | Brick's internal to-do queue | Keeps Brick's own work (setup, maintenance, follow-ups) separate from client work, so client records stay clean |
| `agent_decisions` | Grants, denials, one-time permissions | A queryable mirror of PERMISSIONS.md — "what am I allowed to do" becomes a database lookup, not a file hunt |
| `agent_notes` | Durable knowledge / working notes | Long-term working recall beyond short-term context |
| `agent_milestones` | Playbook / phase progress | Tracks which milestone is done, in-progress, or blocked across any playbook |
| `origin_files` | Brick's identity files | Wires "who I am" into the DB so the DB is self-describing and survives file loss |
| `daily_log` | DB-backed daily activity record | Enables "wake up, see what's on, remember what we did recently, keep going" |

### 3c. The reasoning behind the design

The core idea is that **Brick should wake up and know exactly what's on — without re-reading files or re-asking anyone.** The database is the single source of truth for:

- what's pending → `agent_tasks`
- what's allowed → `agent_decisions`
- what's known → `agent_notes`
- what's done → `agent_milestones`
- who Brick is → `origin_files`
- what happened recently → `daily_log`

Every table has Row Level Security enabled, so nothing leaks outside Brick's own access. The schema is version-controlled as migrations (`0001_operations_schema.sql`, `0002_agent_ops.sql`) in the GitHub repo.

## 4. Current status

- [x] GitHub account + repo + PAT — remote wired + one push proven 2026-10-31 (HEAD `01a961b` on `origin/main`)
- [x] Supabase project + business schema + agent-ops schema + API keys
- [x] Origin files wired, Phase 1 milestones seeded
- [ ] Nightly backups (in progress)
- [ ] Encrypted vault for secrets (in progress)
- [ ] Email access (Zoho — pending setup)
