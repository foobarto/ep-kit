---
design: 3
title: Example — Custom Prefix Configuration
author: EP Kit Team <team@ep-kit.example>
status: Draft
type: Informational
created: 2026-04-17
history:
  - date: 2026-04-17
    status: Draft
---

## Problem

The EP Kit supports configurable frontmatter field names via the `prefix` key in `.ep-kit`, but the default examples all use `ep:`. Users need a concrete example showing how to use a custom prefix like `design:` or `adr:` to match their existing conventions.

## Goals

- Demonstrate a working EP with `design:` as the frontmatter field name
- Show how `.ep-kit` config maps `prefix=design` to validate correctly
- Provide a template for teams migrating from ADR systems

## Non-goals

- Changing the default prefix (remains `ep`)
- Modifying validator behavior

## Design

This EP uses `design: 3` in frontmatter instead of `ep: 3`. When validated with:

```bash
./validate.sh --config .ep-kit-custom examples/
```

Where `.ep-kit-custom` contains:

```
prefix=design
```

The validator correctly identifies the EP number, validates filename consistency, and checks all required sections.

### D1. Custom prefix support confirmed

**Decided:** Validator accepts any prefix string via config.

**Alternatives:** Hardcode multiple known prefixes (ep, adr, design, rfc).

**Why:** Config-driven approach is infinitely extensible and keeps the validator generic.

## Open questions

- Should we ship a `.ep-kit-custom` example file alongside this EP?
