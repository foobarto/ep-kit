---
ep: 2
title: Example — Standards EP (Proposed Change)
author: EP Kit <ep-kit@example.com>
status: Draft
type: Standards
created: 2026-04-17
history:
  - date: 2026-04-17
    status: Draft
    note: Initial draft — example Standards EP.
---

# EP-0002: Example — Standards EP (Proposed Change)

<!--
  This is an EXAMPLE Standards EP. It demonstrates the format,
  decision log depth, and section structure for an EP that proposes
  a real change. Delete this comment before using as a template.
-->

## Problem

The project currently stores all logs in a single rotating file at
`~/.config/project/app.log`. As the project has grown to support
multiple plugins and background workers, this single log file has
become a bottleneck:

- Debugging requires grepping through megabytes of mixed-plugin output.
- Log rotation is manual and error-prone.
- There's no structured way to query events ("show me all errors from
  plugin X in the last hour").

## Goals

- Structured logging with per-plugin separation.
- Automatic log rotation with configurable retention.
- Machine-readable log format (JSON) for downstream tooling.

## Non-goals

- This EP does not introduce a log aggregation service or dashboard.
- This EP does not change the application's error handling semantics.
- This EP does not add log shipping to external services (Datadog,
  Splunk, etc.).

## Design

### Log directory layout

Logs move from a single file to a directory structure:

```
~/.config/project/logs/
├── app/
│   └── YYYY-MM-DD.jsonl
├── plugins/
│   ├── plugin-a/
│   │   └── YYYY-MM-DD.jsonl
│   └── plugin-b/
│       └── YYYY-MM-DD.jsonl
└── audit/
    └── YYYY-MM-DD.jsonl
```

Each day gets a separate file. Files are JSON Lines format with a
consistent schema:

```json
{"ts": "2026-04-17T10:30:00Z", "level": "error", "plugin": "auth", "msg": "token expired", "trace_id": "abc123"}
```

### Rotation and retention

- Files older than 30 days are compressed to `.jsonl.gz`.
- Compressed files older than 90 days are deleted.
- A background job runs daily at midnight to handle rotation.
- Retention periods are configurable via `config.toml`.

### API contract

The logging module exposes:

```
log(level, message, context?) → void
```

Where `context` is an optional map of key-value pairs merged into the
JSON output. The `plugin` field is set automatically based on the
caller's module.

## Migration / rollout

1. **Phase 1 (v1.2):** Write to both old and new formats. Old log file
   continues to receive entries for backward compatibility.
2. **Phase 2 (v1.3):** Default to new format. Old file receives only
   fatal-level entries. Emit a deprecation notice on startup.
3. **Phase 3 (v2.0):** Remove old format entirely. Provide a migration
   script that converts existing `app.log` entries to the new directory
   structure.

Rollback: if the new format causes issues, a config flag
`logging.legacy_mode=true` reverts to single-file output.

## Failure modes

- **Disk full:** Log directory grows unbounded if rotation fails.
  Mitigation: the rotation job checks disk space before writing and
  falls back to dropping DEBUG-level entries if space is below 100MB.
- **Corrupt JSON:** A malformed log entry breaks line-by-line parsing.
  Mitigation: each entry is validated before write; invalid entries are
  written to a separate `malformed.jsonl` for later inspection.
- **Concurrent writes:** Multiple processes writing to the same daily
  file could interleave writes. Mitigation: file locking via `flock`
  on the daily file descriptor.

## Test strategy

- **Unit tests:** Log formatter produces valid JSON for all level types.
  Context merging works correctly.
- **Integration tests:** Rotation job correctly compresses and deletes
  old files. Config overrides apply.
- **End-to-end:** Run the application for 24 hours with test traffic,
  verify log directory structure matches spec, verify no entries are
  lost during rotation boundary.

## Open questions

- Should audit logs have a longer default retention (180 days vs 90)?
  This has compliance implications and needs legal input.
- Should we support syslog output as an alternative destination?

## Decision log

### D1. JSON Lines over structured binary format

- **Decided:** JSON Lines (`.jsonl`) for log entries.
- **Alternatives:** Protocol Buffers, MessagePack, plain text.
- **Why:** JSONL is human-readable (debuggable with `cat` and `jq`),
  line-oriented (supports streaming and partial reads), and has
  universal tooling support. Protobuf/MessagePack would be more compact
  but require a decoder for every inspection, which slows down
  debugging — the most common log operation.

### D2. Daily file rotation over size-based rotation

- **Decided:** One file per day, not size-based rotation (e.g., 10MB
  chunks).
- **Alternatives:** Size-based rotation (like logrotate), hourly files.
- **Why:** Daily files align with how humans investigate incidents
  ("what happened yesterday?"). Size-based rotation makes time-range
  queries awkward (need to scan multiple files to find a time window).
  Hourly files would create too many small files for low-traffic
  deployments. The daily boundary is a proven convention.

### D3. Directory-per-plugin over tagged single file

- **Decided:** Separate directory per plugin, not a single file with
  plugin tags.
- **Alternatives:** Single JSONL file with `plugin` field on each
  entry.
- **Why:** Directory separation enables filesystem-level access control
  (plugin A can't read plugin B's logs) and simplifies log shipping
  configs (watch a directory, not grep a file). A single file would
  require every log reader to filter by plugin, which is error-prone.

### D4. flock over SQLite for log storage

- **Decided:** File-based logs with `flock` for concurrency, not
  SQLite.
- **Alternatives:** SQLite (like our config store), Redis.
- **Why:** Logs are append-only and never updated — SQLite's
  transaction overhead is wasted. File-based logs are easier to tail,
  grep, and ship. `flock` is sufficient for the write concurrency we
  expect (a handful of plugins). Redis would add an external dependency
  for a problem that files solve adequately.

## Related

- EP-0001 — SQLite decision record (the config store that inspired this)
- [JSON Lines format](https://jsonlines.org/)
- Project issue #87 — log aggregation feature request
