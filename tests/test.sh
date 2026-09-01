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
bash -n "$ROOT/validate.sh" "$ROOT/install.sh" "$0"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$ROOT/validate.sh" "$ROOT/install.sh" "$0"
fi
expect_failure "$ROOT/validate.sh" --config >/dev/null 2>&1
expect_failure "$ROOT/validate.sh" "$ROOT/examples" "$ROOT/examples" >/dev/null 2>&1

echo "JSON output"
"$ROOT/validate.sh" --json "$ROOT/examples" >"$TEST_TMP/examples.json"
python3 -m json.tool "$TEST_TMP/examples.json" >/dev/null
python3 - "$TEST_TMP/examples.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["summary"] == {"files_checked": 3, "errors": 0, "warnings": 0}
assert result["diagnostics"] == []
PY

echo "canonical labels, reciprocal relationships, and catalogue"
make_valid_catalogue "$TEST_TMP/valid"
sed -i 's/^ep: 1$/ep: 0001/' "$TEST_TMP/valid/0001-foundation.md"
"$ROOT/validate.sh" --no-autoconfig "$TEST_TMP/valid" >/dev/null

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

echo "JSON escapes unusual but discoverable filenames"
mkdir -p "$TEST_TMP/json-filename"
write_process_ep "$TEST_TMP/json-filename/0001-odd\"name.md" 1 Oddname
expect_failure "$ROOT/validate.sh" --no-autoconfig --json "$TEST_TMP/json-filename" >"$TEST_TMP/json-filename.json"
python3 -m json.tool "$TEST_TMP/json-filename.json" >/dev/null
grep -q 'filename must be NNNN-lower-kebab-title.md' "$TEST_TMP/json-filename.json"

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
    "$ROOT/install.sh" --skill-dir .agents/skills >/dev/null
)
[[ -x "$TEST_TMP/install/scripts/validate-eps.sh" ]] || fail "vendored validator missing"
[[ -f "$TEST_TMP/install/.agents/skills/ep-kit/SKILL.md" ]] || fail "creation skill missing"
[[ -f "$TEST_TMP/install/.agents/skills/ep-kit-validate/SKILL.md" ]] || fail "validation skill missing"
grep -qx 'validator=scripts/validate-eps.sh' "$TEST_TMP/install/.ep-kit"
grep -qx 'kit_version=1.1.0' "$TEST_TMP/install/.ep-kit"
expect_failure "$ROOT/install.sh" --dry-run docs/eps second-target >/dev/null 2>&1
mkdir -p "$TEST_TMP/missing-option"
(
    cd "$TEST_TMP/missing-option"
    expect_failure "$ROOT/install.sh" --skill-dir --dry-run >/dev/null 2>&1
    [[ ! -e docs && ! -e scripts ]]
)
expect_failure "$ROOT/install.sh" --dry-run --validator-path /tmp/outside-validator >/dev/null 2>&1

echo "tool upgrades preserve project templates and unrelated config"
printf '%s\n' '# stale validator' >"$TEST_TMP/install/scripts/validate-eps.sh"
printf '%s\n' '# stale skill' >"$TEST_TMP/install/.agents/skills/ep-kit/SKILL.md"
printf '%s\n' 'project-owned template' >"$TEST_TMP/install/docs/eps/0000-template.md"
sed -i 's#^validator=.*#validator=/tmp/removed-ep-kit/validate.sh#; s/^kit_version=.*/kit_version=1.0.0/' "$TEST_TMP/install/.ep-kit"
printf '%s\n' 'custom_key=preserve-me' >>"$TEST_TMP/install/.ep-kit"
(
    cd "$TEST_TMP/install"
    "$ROOT/install.sh" --upgrade-tools --skill-dir .agents/skills >/dev/null
)
cmp -s "$ROOT/validate.sh" "$TEST_TMP/install/scripts/validate-eps.sh"
cmp -s "$ROOT/SKILL.md" "$TEST_TMP/install/.agents/skills/ep-kit/SKILL.md"
grep -qx 'validator=scripts/validate-eps.sh' "$TEST_TMP/install/.ep-kit"
grep -qx 'kit_version=1.1.0' "$TEST_TMP/install/.ep-kit"
grep -qx 'custom_key=preserve-me' "$TEST_TMP/install/.ep-kit"
grep -qx 'project-owned template' "$TEST_TMP/install/docs/eps/0000-template.md"

echo "PASS"
