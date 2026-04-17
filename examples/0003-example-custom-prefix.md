---
ep: 3
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

- Demonstrate how `.ep-kit` config maps `prefix=design` to validate correctly
- Provide a template for teams migrating from ADR systems
- Show the `--config` flag usage for custom config files

## Non-goals

- Changing the default prefix (remains `ep`)
- Modifying validator behavior

## Design

This example demonstrates custom prefix usage via the `--config` flag:

```bash
./validate.sh --config .ep-kit-custom examples/
```

Where `.ep-kit-custom` contains:

```
prefix=design
```

To use a custom prefix, create an EP with the custom field name (e.g., `design: 3`) and pass the config file to the validator. The validator will then correctly identify the EP number, validate filename consistency, and check all required sections.

### D1. Custom prefix support confirmed

**Decided:** Validator accepts any prefix string via config.

**Alternatives:** Hardcode multiple known prefixes (ep, adr, design, rfc).

**Why:** Config-driven approach is infinitely extensible and keeps the validator generic.

## Decision log

See D1 above.

## Migration

Teams with existing ADR/DRF systems can set `prefix=<name>` in `.ep-kit` to avoid renaming all frontmatter fields.

## Failure modes

- Forgetting to pass `--config` causes validation to fail with "missing prefix" errors
- Using wrong prefix in config causes silent mismatches between filename and field

## Test strategy

Run `./validate.sh --config .ep-kit-custom examples/0003-example-custom-prefix.md` to verify.

## Open questions

- Should we auto-detect prefix from first EP file found?
