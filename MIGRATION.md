# Migration Guide

How to migrate from existing decision-tracking systems to Strata.

## From ADR (Architecture Decision Records)

ADRs typically use a simpler format: a title, status, context, and decision. EPs are richer but backward-compatible.

### Step 1: Map ADR fields to EP frontmatter

| ADR Field | EP Field | Notes |
|-----------|----------|-------|
| Number | `ep: N` | Use the same number or renumber sequentially |
| Title | `title:` | Direct mapping |
| Status | `status:` + `history:` | Map ADR statuses: Proposed→Draft, Accepted→Accepted, Deprecated→Superseded, Superseded→Superseded |
| Date | `created:` | Use original ADR date |
| Author | `author:` | Add email if available |

### Step 2: Add required EP sections

ADRs typically have "Context" and "Decision". Map these:

- **Context** → **Problem** section (rename heading)
- **Decision** → **Design** section (rename heading, move decision to Decision log)
- Add **Goals**, **Non-goals**, and **Decision log** sections

### Step 3: Use the validator in skip mode

Run the validator with `--skip-sections` during the transition to avoid blocking on missing sections:

```bash
scripts/validate-eps.sh --skip-sections docs/eps/
```

Then progressively fill in missing sections.

### Example: ADR → EP

**Before (ADR):**
```markdown
# 42. Use PostgreSQL for event store

## Status
Accepted

## Context
We need durable event storage...

## Decision
We will use PostgreSQL with the outbox pattern...
```

**After (EP):**
```markdown
---
ep: 42
title: Use PostgreSQL for event store
author: Jane Doe <jane@example.com>
status: Accepted
type: Standards
created: 2025-06-15
history:
  - date: 2025-06-15
    status: Accepted
---

## Problem
We need durable event storage with ordering guarantees...

## Goals
- Durable event persistence
- At-least-once delivery via outbox pattern

## Non-goals
- Replacing the primary OLTP database

## Design
We will use PostgreSQL with the outbox pattern. See Decision log for alternatives evaluated.

### D1. PostgreSQL selected for event store
**Decided:** PostgreSQL with outbox table.
**Alternatives:** Kafka, SQLite, MongoDB.
**Why:** Team already operates PostgreSQL; outbox pattern is well-understood; avoids operational complexity of Kafka.

## Decision log
See D1 above.

## Migration
Incremental rollout: new services use outbox, existing services migrate during next release cycle.

## Failure modes
- Outbox table grows without cleanup → implement periodic archiver
- Duplicate events on replay → consumers must be idempotent

## Test strategy
- Integration tests for outbox publish flow
- Chaos tests for consumer idempotency

## Open questions
- Should we use Debezium or custom polling?
```

## From GEP (Glorbo Enhancement Proposals)

GEPs are the direct ancestor of EPs. Migration is mostly mechanical.

### Step 1: Change field name

Replace `gep:` with `ep:` in all frontmatter. Or set `prefix=gep` in `.ep-kit` to avoid changes.

### Step 2: Update status values

GEP and EP statuses are identical. No changes needed.

### Step 3: Add type field

GEPs don't have a `type:` field. Add one:
- Design/architecture proposals → `type: Standards`
- Informational/context documents → `type: Informational`
- Process changes → `type: Process`

### Step 4: Run validator

```bash
scripts/validate-eps.sh docs/eps/
```

Fix any errors (usually missing `type:` or section mismatches).

## From RFCs (Request for Comments)

RFCs vary widely in format. The key mappings:

| RFC Element | EP Equivalent |
|-------------|---------------|
| RFC number | `ep: N` |
| Title | `title:` |
| Author(s) | `author:` |
| Status (Draft/Active/Standards Track) | `status:` + `type:` |
| Abstract | **Problem** section |
| Motivation | **Goals** section |
| Specification | **Design** section |
| Security Considerations | **Failure modes** section |

### Custom prefix for RFCs

If you want to keep `rfc:` as the field name:

```bash
echo "prefix=rfc" > .ep-kit
```

Then rename your RFC files to match the `NNNN-*.md` naming convention.

## From Google Docs / Wiki Pages

### Step 1: Export to Markdown

Export each document as Markdown. Most tools support this:
- Google Docs: File → Download → Markdown (via add-on)
- Confluence: Use the Markdown export plugin
- Notion: Export → Markdown & CSV

### Step 2: Create EP files

For each significant decision document:
1. Create `NNNN-slug.md` in `docs/eps/`
2. Add frontmatter with required fields
3. Reorganize content into EP sections

### Step 3: Set up validation

```bash
# Install Strata (the installer needs its sibling templates and validator)
git clone --depth 1 https://github.com/foobarto/strata.git .tmp/strata
.tmp/strata/install.sh

# Validate
scripts/validate-eps.sh docs/eps/
```

## Bulk Migration Script

For large migrations, use this pattern:

```bash
#!/usr/bin/env bash
# migrate-adrs.sh — convert ADR directory to EP format

ADR_DIR="${1:-docs/adr}"
EP_DIR="${2:-docs/eps}"
COUNTER=1

mkdir -p "$EP_DIR"

for adr in "$ADR_DIR"/*.md; do
  # Extract title from first heading
  title=$(grep -m1 '^# ' "$adr" | sed 's/^# [0-9]*\. //')
  
  # Extract status
  status=$(grep -A1 '## Status' "$adr" | tail -1 | tr -d '[:space:]')
  case "$status" in
    Proposed) status="Draft" ;;
    Deprecated) status="Superseded" ;;
  esac
  
  # Write EP file
  printf -v filename "%s/%04d-%s.md" "$EP_DIR" "$COUNTER" "$(echo "$title" | tr '[:upper:] ' '[:lower:]_' | tr -cd '[:alnum:]_-')"
  
  cat > "$filename" <<EOF
---
ep: $COUNTER
title: $title
author: TBD
status: ${status:-Draft}
type: Standards
created: $(date +%Y-%m-%d)
history:
  - date: $(date +%Y-%m-%d)
    status: ${status:-Draft}
---

## Problem
$(sed -n '/## Context/,/## Decision/p' "$adr" | head -n -1)

## Goals
TBD

## Non-goals
TBD

## Design
$(sed -n '/## Decision/,$p' "$adr")

## Decision log
### D1. Imported from ADR
**Decided:** See design section.
**Alternatives:** Not recorded in original ADR.
**Why:** Not recorded in original ADR.

## Migration
TBD

## Failure modes
TBD

## Test strategy
TBD

## Open questions
TBD
EOF
  
  COUNTER=$((COUNTER + 1))
done

echo "Migrated $((COUNTER - 1)) ADRs to $EP_DIR/"
echo "Run: scripts/validate-eps.sh --skip-sections $EP_DIR/"
```

## Post-Migration Checklist

- [ ] All EP files have valid frontmatter
- [ ] `scripts/validate-eps.sh` passes (or `--skip-sections` is used during transition)
- [ ] Strong bidirectional links (`extends` ↔ `extended-by`, `supersedes` ↔ `superseded-by`) are consistent
- [ ] Decision logs have at least one entry per EP
- [ ] Superseded EPs have correct status
- [ ] Team is trained on EP creation workflow
- [ ] CI is configured to run `validate.sh` on PRs
