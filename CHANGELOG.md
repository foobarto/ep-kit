# Changelog

All notable changes to the EP Kit itself.

## [1.1.0] — 2026-09-01

### Added

- `Partial` lifecycle status for proposals with shipped slices and open goals.
- Explicit `extends` / `extended-by` reciprocity, separate from `requires`.
- README index validation against proposal number, title, link, type, and status.
- Support for both numeric references and quoted canonical labels such as
  `"EP-0001"`.
- Regression coverage for JSON output, malformed references, reciprocal links,
  catalogue drift, duplicate numbers, and installer layout.

### Changed

- The installer now vendors the validator at a project-relative path instead
  of recording the installer's absolute path.
- `install.sh --upgrade-tools` refreshes managed validators and skills plus the
  two managed config keys without overwriting project EP templates.
- `--skill-dir` now creates discoverable `ep-kit/` and `ep-kit-validate/`
  skill folders.
- Implemented Standards EPs must name their first shipped release with
  `implemented-in`.
- Process EPs may use process-specific structure rather than the Standards and
  Informational section set.
- Decision-log scanning no longer starts three subprocesses per input line,
  keeping large catalogues practical to validate.

### Fixed

- Removed duplicated unreachable shell text that made `bash -n validate.sh`
  fail in the v1.0.0 release.
- `--json` now emits valid JSON for multiple files and global diagnostics.
- `requires` no longer incorrectly implies an `extended-by` backlink.
- The valid `Placeholder` lifecycle name no longer triggers unresolved-marker
  warnings; legacy `requires` / `extended-by` pairs pass with a migration
  warning.
- Removed the unsupported `version` key from skill frontmatter.
- Zero-padded frontmatter numbers now compare correctly with zero-padded
  filenames.
- Malformed proposal numbers now produce validation errors without aborting
  the validation run.
- History entries now require their own valid date and lifecycle status.
- The validator now honors `dir=` relative to a discovered `.ep-kit` file,
  including when invoked from a nested project directory without a target.
- Quoted scalar frontmatter is normalized for index checks, duplicate index
  rows are rejected, and early parse failures count as checked files.
- Filenames now enforce the documented lowercase kebab-case convention.
- Quoted scalar values with inline comments are normalized, supersession
  history must mirror top-level metadata, and JSON diagnostics escape control
  characters.
- Legacy scalar `superseded-by` remains accepted with a migration warning.
- Installer argument parsing now rejects a second positional target even when
  the first is the default path.
- Missing installer option values and validator paths outside the target
  project are rejected before writes begin.
- Migration guidance now installs the complete kit rather than piping the
  standalone installer without its required sibling files.
- Quoted history scalars and escaped quotes in scalar frontmatter are
  normalized consistently; the index template now documents required history.
- Large EP bodies no longer produce false missing-section errors from
  `grep -q`/`pipefail` SIGPIPE interactions.

## [1.0.0] — 2026-04-30

First stable release. The schema, skill workflow, and validator
contract are now considered stable; future breaking changes will be
gated behind a major version bump.

### Added

- **Duplicate-number detection** — `validate.sh` now flags two EPs
  claiming the same number when run in directory mode, before any
  per-file validation runs.
- **JSON output for directory mode** — `validate.sh --json` now emits
  a single well-formed document covering every EP scanned plus a
  summary block (`files_checked`, `errors`, `warnings`).

### Changed

- **Stable file enumeration** — directory mode now collects EP files
  via a sorted `find` that explicitly skips `0000-template.md`,
  removing shell-glob edge cases on case-insensitive filesystems.
- **Template `created:` field** — `templates/0000-template.md` now
  ships with a real ISO date placeholder so a fresh copy passes the
  validator without manual frontmatter surgery.

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
