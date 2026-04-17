---
ep: 1
title: Example — Informational EP (Decision Record)
author: EP Kit <ep-kit@example.com>
status: Accepted
type: Informational
created: 2026-04-17
history:
  - date: 2026-04-17
    status: Draft
    note: Initial draft — example Informational EP.
  - date: 2026-04-18
    status: Accepted
    note: Accepted as the canonical example for the EP Kit.
---

# EP-1: Example — Informational EP (Decision Record)

<!--
  This is an EXAMPLE Informational EP. It demonstrates the format,
  tone, and structure for an EP that documents an existing decision
  rather than proposing a new one. Delete this comment before using
  as a real template.
-->

## Problem

When this project started, we needed to pick a database for storing
user configuration. The decision was made quickly during a team call
and the rationale was never written down. Six months later, a new
contributor asked why we chose SQLite over PostgreSQL and nobody could
answer. The original decision-maker had left the project.

This EP captures that decision record so the rationale survives.

## Goals

- Document why SQLite was chosen for user configuration storage.
- Capture the alternatives that were considered and why they lost.
- Provide a reference for future contributors who question this choice.

## Non-goals

- This EP does not propose changing the database choice.
- This EP does not cover the primary application database (that's a
  separate decision).
- This EP does not prescribe SQLite configuration or schema design.

## Design

User configuration is stored in a single SQLite database file at
`~/.config/project/config.db`. The database is created on first run
and migrated via a simple version table. It stores:

- User preferences (key-value pairs)
- Plugin configuration (JSON blobs)
- Feature flags (boolean toggles)

The database is accessed by a single process at a time (the CLI), so
concurrency concerns are minimal. WAL mode is enabled for crash safety.

## Decision log

### D1. SQLite over PostgreSQL

- **Decided:** SQLite for user configuration storage.
- **Alternatives:** PostgreSQL, JSON files, TOML files.
- **Why:** SQLite gives us schema evolution and ACID guarantees without
  requiring a separate server process. JSON/TOML files would work for
  simple configs but break down when we need relational queries (e.g.,
  "which plugins are enabled for feature X?"). PostgreSQL is overkill
  for a single-user config store and adds deployment complexity.

### D2. Single database file, not one per plugin

- **Decided:** One shared database for all configuration.
- **Alternatives:** Separate database file per plugin.
- **Why:** A single file simplifies backup, migration, and debugging.
  Per-plugin files would make cross-plugin queries awkward and backup
  scripts more complex. The risk of file corruption affecting all
  plugins is mitigated by SQLite's atomic writes.

### D3. WAL mode for crash safety

- **Decided:** Enable WAL (Write-Ahead Logging) journal mode.
- **Alternatives:** Default DELETE journal mode, OFF journal mode.
- **Why:** WAL mode gives us crash-safe writes with minimal performance
  overhead. DELETE mode is slower for our write patterns. OFF mode
  risks corruption on power loss. The trade-off is a `-wal` sidecar
  file that must be cleaned up, but SQLite handles this automatically.

## Open questions

None — this EP documents decisions that are already implemented and
stable.

## Related

- Project issue #42 — original database selection discussion
- SQLite documentation: [WAL Mode](https://www.sqlite.org/wal.html)
