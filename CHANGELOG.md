# Changelog

All notable changes to the EP Kit itself.

## [0.2.0] — 2026-04-17

### Added

- **`.github/workflows/validate.yml`** — GitHub Actions CI workflow for EP validation on PRs and pushes
- **`MIGRATION.md`** — Migration guide for ADR, GEP, RFC, and wiki-based decision records
- **`examples/0003-example-custom-prefix.md`** — Example demonstrating custom prefix configuration
- **`--no-autoconfig` flag** — `validate.sh` option to disable `.ep-kit` auto-discovery

### Changed

- CI workflow now falls back to `examples/` directory when `docs/eps/` doesn't exist
- Removed Glorbo/GEP-specific references from `validate.sh`, `SKILL.md`, and `install.sh`

## [0.1.0] — 2026-04-17

Initial release.

### Added

- **SKILL.md** — AI skill for the 6-phase Q&A EP creation workflow
- **templates/0000-template.md** — Skeleton for new EPs with frontmatter, sections, and decision log
- **templates/0001-ep-purpose-and-guidelines.md** — Process document defining the EP lifecycle, conventions, and rules
- **templates/README.md** — Index template for project EP directories
- **install.sh** — One-command installer that scaffolds `docs/eps/` and optionally copies the skill
- **CHECKLIST.md** — PR review checklist for EP quality gate
- **examples/0001-example-informational.md** — Example Informational EP showing "what good looks like"
- **examples/0002-example-standards.md** — Example Standards EP with full decision log
