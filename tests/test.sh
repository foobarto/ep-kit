#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/ep-kit-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

expect_failure() {
    if "$@"; then
        fail "command unexpectedly succeeded: $*"
    fi
}

write_process_ep() {
    local path="$1"
    local number="$2"
    local title="$3"
    local relationship="${4:-}"
    cat >"$path" <<EOF
---
ep: $number
title: $title
author: Example Author <author@example.com>
status: Accepted
type: Process
created: 2026-01-01
$relationship
history:
  - date: 2026-01-01
    status: Accepted
    note: Initial accepted process.
---

# EP-$number: $title

## Decision log

### D1. Record the process

- **Decided:** Record this process.
- **Alternatives:** Leave it undocumented.
- **Why:** Contributors need one durable rule.
EOF
}

make_valid_catalogue() {
    local dir="$1"
    mkdir -p "$dir"
    write_process_ep "$dir/0001-foundation.md" 1 Foundation 'extended-by: ["EP-0002"]'
    write_process_ep "$dir/0002-extension.md" 2 Extension 'extends: ["EP-0001"]'
    cat >"$dir/README.md" <<'EOF'
# Enhancement Proposals

## Index

| #    | Title | Type | Status |
|------|-------|------|--------|
| 0001 | [Foundation](./0001-foundation.md) | Process | Accepted |
| 0002 | [Extension](./0002-extension.md) | Process | Accepted |

## Status legend
EOF
}

echo "syntax and static checks"
bash -n "$ROOT/validate.sh" "$ROOT/skills/ep-kit/validate.sh" "$ROOT/install.sh" "$0"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$ROOT/validate.sh" "$ROOT/skills/ep-kit/validate.sh" "$ROOT/install.sh" "$0"
fi
expect_failure "$ROOT/validate.sh" --config >/dev/null 2>&1
expect_failure "$ROOT/validate.sh" "$ROOT/examples" "$ROOT/examples" >/dev/null 2>&1

echo "governance skill and behavioral eval contracts"
GOVERN_SKILL="$ROOT/skills/ep-kit-governance/SKILL.md"
grep -q '^name: ep-kit-governance$' "$GOVERN_SKILL"
grep -q '^description: Use before planning, implementing, resuming, or completing project changes in a repository containing \.ep-kit\.' "$GOVERN_SKILL"
for class in Spike Bounded Architectural; do
    grep -q "\\*\\*$class\\*\\*" "$GOVERN_SKILL" || fail "governance skill missing $class classification"
done
grep -q '`EP-NNNN D<N>`' "$GOVERN_SKILL" || fail "governance skill missing canonical decision citation"
grep -q '^## Decisions discovered during implementation$' "$ROOT/templates/0001-ep-purpose-and-guidelines.md" || fail "EP-1 missing implementation decision boundary"
grep -q '`EP-NNNN D<N>`' "$ROOT/templates/0001-ep-purpose-and-guidelines.md" || fail "EP-1 missing canonical decision citation"
if grep -qi 'cairn' "$ROOT/install.sh" "$ROOT/skills/ep-kit-governance/SKILL.md" "$ROOT/skills/ep-kit/SKILL.md" "$ROOT/skills/ep-kit-validate/SKILL.md"; then
    fail "Cairn promotion leaked into installer or core skills"
fi
grep -q '^## Optional companion: Cairn$' "$ROOT/README.md" || fail "README missing optional Cairn boundary"
for skill_name in ep-kit-governance ep-kit ep-kit-validate; do
    grep -qx "name: $skill_name" "$ROOT/skills/$skill_name/SKILL.md" || fail "skill name does not match directory: $skill_name"
done
for case_file in "$ROOT"/evals/[0-9][0-9]-*.md; do
    grep -qE '^## Prompt( [0-9]+)?$' "$case_file" || fail "eval case missing prompt: $case_file"
    grep -q '^## Expected$' "$case_file" || fail "eval case missing expected behavior: $case_file"
    grep -q '^## Fail conditions$' "$case_file" || fail "eval case missing fail conditions: $case_file"
done
[[ $(find "$ROOT/evals" -maxdepth 1 -name '[0-9][0-9]-*.md' -type f | wc -l) -ge 7 ]] || fail "behavioral eval suite is incomplete"

echo "plugin and marketplace contracts"
for manifest in \
    "$ROOT/.codex-plugin/plugin.json" \
    "$ROOT/.agents/plugins/marketplace.json" \
    "$ROOT/.claude-plugin/plugin.json" \
    "$ROOT/.claude-plugin/marketplace.json"; do
    python3 -m json.tool "$manifest" >/dev/null || fail "invalid JSON manifest: $manifest"
done
python3 - "$ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
codex = json.loads((root / ".codex-plugin/plugin.json").read_text())
codex_market = json.loads((root / ".agents/plugins/marketplace.json").read_text())
claude = json.loads((root / ".claude-plugin/plugin.json").read_text())
claude_market = json.loads((root / ".claude-plugin/marketplace.json").read_text())
assert codex["name"] == "strata" and codex["skills"] == "./skills/"
assert codex["homepage"] == codex["repository"] == "https://github.com/foobarto/strata"
assert codex_market["name"] == "strata"
assert codex_market["plugins"][0]["name"] == "strata"
assert codex_market["plugins"][0]["source"] == {"source": "url", "url": "./"}
assert claude["name"] == "strata"
assert claude["homepage"] == claude["repository"] == "https://github.com/foobarto/strata"
assert claude_market["name"] == "strata"
assert claude_market["plugins"][0]["name"] == "strata"
assert claude_market["plugins"][0]["source"] == "./"
assert codex["version"] == claude["version"] == claude_market["version"] == "1.3.0"
PY
if grep -Rqs --exclude-dir=.git --exclude-dir=.tmp \
    --exclude=CHANGELOG.md --exclude=test.sh \
    'github.com/foobarto/ep-kit' "$ROOT"; then
    fail "canonical project metadata still references the pre-Strata repository URL"
fi
grep -qx 'name: ep-kit-reviewer' "$ROOT/agents/ep-kit-reviewer.md"
grep -qx 'tools: Read, Glob, Grep' "$ROOT/agents/ep-kit-reviewer.md"

echo "JSON output"
"$ROOT/validate.sh" --json "$ROOT/examples" >"$TEST_TMP/examples.json"
python3 -m json.tool "$TEST_TMP/examples.json" >/dev/null
python3 - "$TEST_TMP/examples.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["summary"] == {"files_checked": 3, "errors": 0, "warnings": 0}
assert result["diagnostics"] == []
assert "proposals" not in result
assert "catalogue_version" not in result
PY

echo "empty catalogue failures remain machine-readable"
mkdir -p "$TEST_TMP/empty-catalogue"
expect_failure "$ROOT/validate.sh" --no-autoconfig --catalogue-json "$TEST_TMP/empty-catalogue" >"$TEST_TMP/empty-catalogue.json"
python3 - "$TEST_TMP/empty-catalogue.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["summary"] == {"files_checked": 0, "errors": 1, "warnings": 0}
assert result["proposals"] == []
assert result["diagnostics"][0]["message"].startswith("No EP files found in ")
PY

echo "canonical labels, reciprocal relationships, and catalogue"
make_valid_catalogue "$TEST_TMP/valid"
sed -i 's/^ep: 1$/ep: 0001/' "$TEST_TMP/valid/0001-foundation.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/valid" >/dev/null

echo "catalogue JSON exposes stable proposal metadata"
"$ROOT/validate.sh" --no-autoconfig --catalogue-json "$TEST_TMP/valid" >"$TEST_TMP/catalogue.json"
python3 - "$TEST_TMP/catalogue.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["catalogue_version"] == 1
assert result["summary"] == {"files_checked": 2, "errors": 0, "warnings": 0}
assert [item["id"] for item in result["proposals"]] == ["EP-0001", "EP-0002"]
foundation, extension = result["proposals"]
assert foundation["number"] == 1
assert foundation["path"] == "0001-foundation.md"
assert foundation["title"] == "Foundation"
assert foundation["type"] == "Process"
assert foundation["status"] == "Accepted"
assert foundation["extended-by"] == ["EP-0002"]
assert extension["extends"] == ["EP-0001"]
assert extension["requires"] == []
assert extension["supersedes"] == []
assert extension["superseded-by"] == []
assert extension["implemented-in"] is None
PY

echo "relationship wildcards never expand against ambient filenames"
make_valid_catalogue "$TEST_TMP/catalogue-wildcard"
sed -i '/^extended-by:/a see-also: [EP-000?]' "$TEST_TMP/catalogue-wildcard/0001-foundation.md"
mkdir -p "$TEST_TMP/catalogue-ambient"
touch "$TEST_TMP/catalogue-ambient/EP-0002"
(
    cd "$TEST_TMP/catalogue-ambient"
    expect_failure "$ROOT/validate.sh" --no-autoconfig --catalogue-json "$TEST_TMP/catalogue-wildcard" >"$TEST_TMP/catalogue-wildcard.json"
)
python3 - "$TEST_TMP/catalogue-wildcard.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["summary"]["errors"] >= 1
assert result["proposals"][0]["see-also"] == []
assert any("invalid see-also reference 'EP-000?'" in item["message"] for item in result["files"][0]["checks"])
PY

echo "Decision Log identifiers are unique citation targets"
make_valid_catalogue "$TEST_TMP/duplicate-decision-id"
cat >>"$TEST_TMP/duplicate-decision-id/0001-foundation.md" <<'EOF'

### D1. Duplicate identifier

- **Decided:** Reuse D1.
- **Alternatives:** Use D2.
- **Why:** Exercise the stable-citation validator.
EOF
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/duplicate-decision-id" >"$TEST_TMP/duplicate-decision-id.out"
grep -q 'duplicate Decision Log identifier D1' "$TEST_TMP/duplicate-decision-id.out"
sed -i 's/^### D1\. Duplicate identifier$/### D01. Padded duplicate identifier/' "$TEST_TMP/duplicate-decision-id/0001-foundation.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/duplicate-decision-id" >"$TEST_TMP/padded-decision-id.out"
grep -q 'non-canonical Decision Log identifier D01' "$TEST_TMP/padded-decision-id.out"
grep -q 'duplicate Decision Log identifier D01' "$TEST_TMP/padded-decision-id.out"
sed -i 's/^### D01\. Padded duplicate identifier$/### D0. Zero identifier/' "$TEST_TMP/duplicate-decision-id/0001-foundation.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/duplicate-decision-id" >"$TEST_TMP/zero-decision-id.out"
grep -q 'non-canonical Decision Log identifier D0' "$TEST_TMP/zero-decision-id.out"

echo "catalogue IDs remain EP namespaced with a custom frontmatter key"
make_valid_catalogue "$TEST_TMP/catalogue-custom-prefix"
sed -i 's/^ep:/design:/' "$TEST_TMP/catalogue-custom-prefix"/[0-9][0-9][0-9][0-9]-*.md
sed -i 's/"EP-0001"/"EP-1"/' "$TEST_TMP/catalogue-custom-prefix/0002-extension.md"
sed -i 's/"EP-0002"/"EP-2"/' "$TEST_TMP/catalogue-custom-prefix/0001-foundation.md"
cat >"$TEST_TMP/catalogue-custom-prefix/.ep-kit" <<'EOF'
dir=.
prefix=design
EOF
"$ROOT/validate.sh" --config "$TEST_TMP/catalogue-custom-prefix/.ep-kit" --catalogue-json "$TEST_TMP/catalogue-custom-prefix" >"$TEST_TMP/catalogue-custom-prefix.json"
python3 - "$TEST_TMP/catalogue-custom-prefix.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["prefix"] == "design"
assert [item["id"] for item in result["proposals"]] == ["EP-0001", "EP-0002"]
PY

echo "catalogue exposes implemented-in when present"
mkdir -p "$TEST_TMP/catalogue-implemented"
sed 's/status: Draft/status: Implemented/g; /^history:/i implemented-in: v1.2.3' "$ROOT/examples/0002-example-standards.md" >"$TEST_TMP/catalogue-implemented/0002-example-standards.md"
"$ROOT/validate.sh" --no-autoconfig --catalogue-json "$TEST_TMP/catalogue-implemented/0002-example-standards.md" >"$TEST_TMP/catalogue-implemented.json"
python3 - "$TEST_TMP/catalogue-implemented.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["proposals"][0]["implemented-in"] == "v1.2.3"
PY

echo "large documents do not false-fail section checks under pipefail"
make_valid_catalogue "$TEST_TMP/large"
awk 'BEGIN { for (i = 0; i < 5000; i++) print "Additional process rationale line " i "." }' >>"$TEST_TMP/large/0001-foundation.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/large" >/dev/null

echo "quoted scalar fields normalize for catalogue comparison"
make_valid_catalogue "$TEST_TMP/quoted-title"
sed -i 's/^title: Foundation$/title: "Adopt \\"strict\\" mode"/' "$TEST_TMP/quoted-title/0001-foundation.md"
sed -i 's/^status: Accepted$/status: "Accepted" # current/' "$TEST_TMP/quoted-title/0001-foundation.md"
sed -i 's/^  - date: 2026-01-01$/  - date: "2026-01-01"/; s/^    status: Accepted$/    status: "Accepted"/' "$TEST_TMP/quoted-title/0001-foundation.md"
sed -i 's/\[Foundation\]/[Adopt "strict" mode]/' "$TEST_TMP/quoted-title/README.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/quoted-title" >/dev/null

echo "supported frontmatter subset rejects YAML-ambiguous scalars"
mkdir -p "$TEST_TMP/frontmatter-subset"
cp "$ROOT/examples/0002-example-standards.md" "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
sed -i 's/^title: Example — Standards EP (Proposed Change)$/title: Add: structured logging/' "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/frontmatter-subset/0002-example-standards.md" >"$TEST_TMP/frontmatter-subset-invalid.out"
grep -q "unquoted scalar contains ': '" "$TEST_TMP/frontmatter-subset-invalid.out"
sed -i 's/^title: Add: structured logging$/title: "Add: structured logging"/' "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/frontmatter-subset/0002-example-standards.md" >/dev/null
sed -i 's/^title: "Add: structured logging"$/title: "Add: structured logging/' "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/frontmatter-subset/0002-example-standards.md" >"$TEST_TMP/frontmatter-subset-unterminated.out"
grep -q 'unterminated double-quoted scalar' "$TEST_TMP/frontmatter-subset-unterminated.out"
sed -i 's/^title: "Add: structured logging$/title: Example — Standards EP (Proposed Change)/' "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
sed -i '/^type: Standards$/a bare-garbage' "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/frontmatter-subset/0002-example-standards.md" >"$TEST_TMP/frontmatter-subset-garbage.out"
grep -q "unsupported frontmatter syntax 'bare-garbage'" "$TEST_TMP/frontmatter-subset-garbage.out"
cp "$ROOT/examples/0002-example-standards.md" "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
sed -i 's/^title: .*/title: [Not, a, scalar]/' "$TEST_TMP/frontmatter-subset/0002-example-standards.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/frontmatter-subset/0002-example-standards.md" >"$TEST_TMP/frontmatter-subset-flow-sequence.out"
grep -q 'flow sequences are only supported for EP relationship fields' "$TEST_TMP/frontmatter-subset-flow-sequence.out"

echo "inline comments and single-quoted hashes remain valid YAML scalars"
make_valid_catalogue "$TEST_TMP/frontmatter-comments"
sed -i "s/^title: Foundation$/title: 'C# integration'/; s/^status: Accepted$/status: Accepted # lifecycle: active/" "$TEST_TMP/frontmatter-comments/0001-foundation.md"
sed -i "s/\[Foundation\]/[C# integration]/" "$TEST_TMP/frontmatter-comments/README.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/frontmatter-comments" >/dev/null

echo "proposal discovery excludes symlinks"
mkdir -p "$TEST_TMP/symlink-only"
ln -s "$ROOT/examples/0002-example-standards.md" "$TEST_TMP/symlink-only/0002-example-standards.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/symlink-only" >"$TEST_TMP/symlink-only.out" 2>&1
grep -q 'No EP files found' "$TEST_TMP/symlink-only.out"
expect_failure "$ROOT/validate.sh" --no-autoconfig --catalogue-json "$TEST_TMP/symlink-only/0002-example-standards.md" >"$TEST_TMP/symlink-target.out" 2>&1
grep -q 'Symlink proposal targets are unsupported' "$TEST_TMP/symlink-target.out"

echo "runtime scripts avoid GNU-only and Bash 4-only constructs"
if grep -Eq 'local -A|declare -A|-maxdepth|chmod --reference' "$ROOT/validate.sh" "$ROOT/skills/ep-kit/validate.sh" "$ROOT/install.sh"; then
    fail "runtime scripts contain a known macOS-incompatible construct"
fi

echo "JSON escapes unusual but discoverable filenames"
mkdir -p "$TEST_TMP/json-filename"
write_process_ep "$TEST_TMP/json-filename/0001-odd\"name.md" 1 Oddname
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/json-filename" >"$TEST_TMP/json-filename.json"
python3 -m json.tool "$TEST_TMP/json-filename.json" >/dev/null
grep -q 'filename must be NNNN-lower-kebab-title.md' "$TEST_TMP/json-filename.json"

echo "line-breaking filenames fail cleanly before path enumeration"
mkdir -p "$TEST_TMP/json-newline-filename"
cp "$ROOT/examples/0002-example-standards.md" "$TEST_TMP/json-newline-filename/"$'0002-bad\nname.md'
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/json-newline-filename" >"$TEST_TMP/json-newline-filename.json" 2>"$TEST_TMP/json-newline-filename.stderr"
[[ ! -s "$TEST_TMP/json-newline-filename.stderr" ]] || fail "line-breaking filename leaked tool errors to stderr"
python3 - "$TEST_TMP/json-newline-filename.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["summary"] == {"files_checked": 0, "errors": 1, "warnings": 0}
assert result["diagnostics"][0]["message"] == "proposal filename contains a line break, which is unsupported"
PY

echo "JSON escapes control characters in diagnostics"
mkdir -p "$TEST_TMP/json-control"
control_file=$'0001-form\fname.md'
write_process_ep "$TEST_TMP/json-control/$control_file" 1 Formfeed
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/json-control" >"$TEST_TMP/json-control.json"
python3 -m json.tool "$TEST_TMP/json-control.json" >/dev/null

echo "config dir resolves relative to the config file"
mkdir -p "$TEST_TMP/config-project/nested/work"
make_valid_catalogue "$TEST_TMP/config-project/decisions"
cat >"$TEST_TMP/config-project/.ep-kit" <<'EOF'
dir=decisions
prefix=ep
EOF
(
    cd "$TEST_TMP/config-project/nested/work"
    "$ROOT/validate.sh" >/dev/null
)

echo "target project config takes precedence over caller config"
mkdir -p "$TEST_TMP/config-caller/empty"
cat >"$TEST_TMP/config-caller/.ep-kit" <<'EOF'
dir=empty
prefix=rfc
EOF
cat >"$TEST_TMP/config-project/.ep-kit" <<'EOF'
dir=decisions
prefix=ep
EOF
(
    cd "$TEST_TMP/config-caller"
    "$ROOT/validate.sh" "$TEST_TMP/config-project/decisions" >/dev/null
)

echo "Partial status is valid"
make_valid_catalogue "$TEST_TMP/partial"
sed -i 's/status: Accepted/status: Partial/g' "$TEST_TMP/partial/0002-extension.md"
sed -i 's/\[Extension\](\.\/0002-extension\.md) | Process | Accepted |/[Extension](.\/0002-extension.md) | Process | Partial |/' "$TEST_TMP/partial/README.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/partial" >/dev/null

echo "Implemented Standards EPs require release metadata"
mkdir -p "$TEST_TMP/implemented"
sed 's/status: Draft/status: Implemented/g' "$ROOT/examples/0002-example-standards.md" >"$TEST_TMP/implemented/0002-example-standards.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/implemented" >"$TEST_TMP/implemented.out"
grep -q "missing 'implemented-in'" "$TEST_TMP/implemented.out"

echo "malformed references fail without corrupting JSON"
make_valid_catalogue "$TEST_TMP/malformed"
sed -i 's/extends: \["EP-0001"\]/extends: [not-a-number]/' "$TEST_TMP/malformed/0002-extension.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/malformed" >"$TEST_TMP/malformed.json"
python3 -m json.tool "$TEST_TMP/malformed.json" >/dev/null
grep -q 'invalid extends reference' "$TEST_TMP/malformed.json"
expect_failure "$ROOT/validate.sh" --no-autoconfig --catalogue-json "$TEST_TMP/malformed" >"$TEST_TMP/malformed-catalogue.json"
python3 - "$TEST_TMP/malformed-catalogue.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["catalogue_version"] == 1
assert result["summary"]["errors"] > 0
assert any(
    "invalid extends reference" in item["message"]
    for proposal_file in result["files"]
    for item in proposal_file["checks"]
)
assert len(result["proposals"]) == 2
PY

echo "malformed proposal numbers fail cleanly"
make_valid_catalogue "$TEST_TMP/malformed-number"
sed -i 's/^ep: 2$/ep: not-a-number/' "$TEST_TMP/malformed-number/0002-extension.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/malformed-number" >"$TEST_TMP/malformed-number.json"
python3 -m json.tool "$TEST_TMP/malformed-number.json" >/dev/null
grep -q "must be a positive integer" "$TEST_TMP/malformed-number.json"

echo "malformed history entries are reported"
make_valid_catalogue "$TEST_TMP/history"
sed -i 's/^  - date: 2026-01-01$/  - note: Missing date/' "$TEST_TMP/history/0002-extension.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/history" >"$TEST_TMP/history.json"
python3 -m json.tool "$TEST_TMP/history.json" >/dev/null
grep -q 'history\[1\] missing date' "$TEST_TMP/history.json"

echo "missing reciprocal metadata fails"
make_valid_catalogue "$TEST_TMP/reciprocal"
sed -i '/^extended-by:/d' "$TEST_TMP/reciprocal/0001-foundation.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/reciprocal" >"$TEST_TMP/reciprocal.out"
grep -q 'lacks reciprocal extended-by' "$TEST_TMP/reciprocal.out"

echo "legacy scalar superseded-by remains compatible"
make_valid_catalogue "$TEST_TMP/scalar-superseded"
sed -i 's/^extended-by: \["EP-0002"\]$/superseded-by: 2/; s/status: Accepted/status: Superseded/g' "$TEST_TMP/scalar-superseded/0001-foundation.md"
sed -i '/^    status: Superseded$/a\    superseded-by: 2' "$TEST_TMP/scalar-superseded/0001-foundation.md"
sed -i 's/^extends: \["EP-0001"\]$/supersedes: [1]/' "$TEST_TMP/scalar-superseded/0002-extension.md"
sed -i 's/\[Foundation\](\.\/0001-foundation\.md) | Process | Accepted |/[Foundation](.\/0001-foundation.md) | Process | Superseded |/' "$TEST_TMP/scalar-superseded/README.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/scalar-superseded" >"$TEST_TMP/scalar-superseded.out"
grep -q 'scalar superseded-by is legacy v1 syntax' "$TEST_TMP/scalar-superseded.out"

echo "Superseded history mirrors top-level metadata"
make_valid_catalogue "$TEST_TMP/history-superseded"
sed -i 's/^extended-by: \["EP-0002"\]$/superseded-by: [2]/; s/status: Accepted/status: Superseded/g' "$TEST_TMP/history-superseded/0001-foundation.md"
sed -i 's/^extends: \["EP-0001"\]$/supersedes: [1]/' "$TEST_TMP/history-superseded/0002-extension.md"
sed -i 's/\[Foundation\](\.\/0001-foundation\.md) | Process | Accepted |/[Foundation](.\/0001-foundation.md) | Process | Superseded |/' "$TEST_TMP/history-superseded/README.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/history-superseded" >"$TEST_TMP/history-superseded.out"
grep -q 'status Superseded is missing superseded-by' "$TEST_TMP/history-superseded.out"

echo "stale catalogue rows fail"
make_valid_catalogue "$TEST_TMP/index"
sed -i 's/| Process | Accepted |/| Process | Draft |/' "$TEST_TMP/index/README.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/index" >"$TEST_TMP/index.out"
grep -q 'missing or stale index row' "$TEST_TMP/index.out"

echo "extra stale catalogue rows fail even when the correct row exists"
make_valid_catalogue "$TEST_TMP/extra-index"
sed -i '/| 0001 |/a | 0001 | [Old Foundation](./0001-foundation.md) | Process | Draft |' "$TEST_TMP/extra-index/README.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/extra-index" >"$TEST_TMP/extra-index.out"
grep -q 'more than one index row claims 0001' "$TEST_TMP/extra-index.out"

echo "duplicate-number diagnostics remain valid JSON"
make_valid_catalogue "$TEST_TMP/duplicate"
sed -i 's/^ep: 2$/ep: 0001/' "$TEST_TMP/duplicate/0002-extension.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/duplicate" >"$TEST_TMP/duplicate.json"
python3 -m json.tool "$TEST_TMP/duplicate.json" >/dev/null
python3 - "$TEST_TMP/duplicate.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert any("duplicate ep number" in item["message"] for item in result["diagnostics"])
PY

echo "early frontmatter failures still count attempted files"
mkdir -p "$TEST_TMP/early-failure"
printf '%s\n' '---' 'ep: 1' >"$TEST_TMP/early-failure/0001-unclosed.md"
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/early-failure" >"$TEST_TMP/early-failure.json"
python3 - "$TEST_TMP/early-failure.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["summary"]["files_checked"] == 1
PY

echo "installer creates durable project-relative tooling and discoverable skills"
mkdir -p "$TEST_TMP/install"
(
    cd "$TEST_TMP/install"
    "$ROOT/install.sh" >/dev/null
)
[[ -x "$TEST_TMP/install/scripts/validate-eps.sh" ]] || fail "vendored validator missing"
[[ -f "$TEST_TMP/install/.agents/skills/ep-kit-governance/SKILL.md" ]] || fail "governance skill missing"
[[ -f "$TEST_TMP/install/.agents/skills/ep-kit/SKILL.md" ]] || fail "creation skill missing"
[[ -f "$TEST_TMP/install/.agents/skills/ep-kit-validate/SKILL.md" ]] || fail "validation skill missing"
grep -qx 'validator=scripts/validate-eps.sh' "$TEST_TMP/install/.ep-kit"
grep -qx 'kit_version=1.3.0' "$TEST_TMP/install/.ep-kit"
grep -q '^# Strata configuration' "$TEST_TMP/install/.ep-kit"
expect_failure "$ROOT/install.sh" --dry-run docs/eps second-target >/dev/null 2>&1
mkdir -p "$TEST_TMP/missing-option"
(
    cd "$TEST_TMP/missing-option"
    expect_failure "$ROOT/install.sh" --skill-dir --dry-run >/dev/null 2>&1
    [[ ! -e docs && ! -e scripts ]]
)
expect_failure "$ROOT/install.sh" --dry-run --validator-path /tmp/outside-validator >/dev/null 2>&1
mkdir -p "$TEST_TMP/no-skills"
(
    cd "$TEST_TMP/no-skills"
    "$ROOT/install.sh" --no-skills >/dev/null
    [[ ! -e .agents ]] || fail "--no-skills created a skills directory"
)

echo "tool upgrades preserve project templates and unrelated config"
printf '%s\n' '# stale validator' >"$TEST_TMP/install/scripts/validate-eps.sh"
printf '%s\n' '# stale governance skill' >"$TEST_TMP/install/.agents/skills/ep-kit-governance/SKILL.md"
printf '%s\n' '# stale skill' >"$TEST_TMP/install/.agents/skills/ep-kit/SKILL.md"
printf '%s\n' 'project-owned template' >"$TEST_TMP/install/docs/eps/0000-template.md"
sed -i 's#^validator=.*#validator=/tmp/removed-ep-kit/validate.sh#; s/^kit_version=.*/kit_version=1.0.0/' "$TEST_TMP/install/.ep-kit"
printf '%s\n' 'custom_key=preserve-me' >>"$TEST_TMP/install/.ep-kit"
(
    cd "$TEST_TMP/install"
    "$ROOT/install.sh" --upgrade-tools >/dev/null
)
cmp -s "$ROOT/skills/ep-kit/validate.sh" "$TEST_TMP/install/scripts/validate-eps.sh"
cmp -s "$ROOT/skills/ep-kit-governance/SKILL.md" "$TEST_TMP/install/.agents/skills/ep-kit-governance/SKILL.md"
cmp -s "$ROOT/skills/ep-kit/SKILL.md" "$TEST_TMP/install/.agents/skills/ep-kit/SKILL.md"
cmp -s "$ROOT/skills/ep-kit-validate/SKILL.md" "$TEST_TMP/install/.agents/skills/ep-kit-validate/SKILL.md"
cmp -s "$ROOT/skills/ep-kit-validate/CHECKLIST.md" "$TEST_TMP/install/.agents/skills/ep-kit-validate/CHECKLIST.md"
grep -qx 'validator=scripts/validate-eps.sh' "$TEST_TMP/install/.ep-kit"
grep -qx 'kit_version=1.3.0' "$TEST_TMP/install/.ep-kit"
grep -qx 'custom_key=preserve-me' "$TEST_TMP/install/.ep-kit"
grep -qx 'project-owned template' "$TEST_TMP/install/docs/eps/0000-template.md"

echo "PASS"
