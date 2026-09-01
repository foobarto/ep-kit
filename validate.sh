#!/usr/bin/env bash
# EP Validator — deterministic checks for Enhancement Proposal files.
#
# Usage:
#   ./validate.sh                  # validate all EPs in docs/eps/
#   ./validate.sh docs/eps/0003-foo.md  # single file
#   ./validate.sh --config .ep-kit docs/eps/  # with config file
#   ./validate.sh --json docs/eps/  # JSON output for CI
#
# Config file (optional):
#   If a config file exists (default: .ep-kit in project root), it can
#   override defaults. Supported keys:
#     prefix=ep           # frontmatter field name (default: ep)
#     dir=docs/eps        # default directory to validate
#     skip_sections=1     # skip required section checks (for retrofits)
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#
# Requires: grep, sed, awk. No external dependencies.

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0
FILES_CHECKED=0
JSON_MODE=false
NO_AUTOCONFIG=false
JSON_FILE_OPEN=false
JSON_FILE_COUNT=0
JSON_CHECK_COUNT=0
JSON_GLOBAL_COUNT=0

# JSON output accumulator
JSON_OUTPUT=""
JSON_GLOBAL_OUTPUT=""

# Defaults — overridable via config file
PREFIX="ep"
SKIP_SECTIONS=false
CONFIG_EP_DIR=""
LOADED_CONFIG=""

# Parse config file
# Usage: load_config ".ep-kit"
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        local config_base
        config_base=$(cd "$(dirname "$config_file")" && pwd)
        LOADED_CONFIG="$config_file"
        while IFS='=' read -r key value; do
            # Skip comments and blank lines
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            case "$key" in
                prefix) PREFIX="$value" ;;
                dir)
                    if [[ "$value" = /* ]]; then
                        CONFIG_EP_DIR="$value"
                    else
                        CONFIG_EP_DIR="$config_base/$value"
                    fi
                    ;;
                skip_sections)
                    if [[ "$value" == "1" || "$value" == "true" ]]; then
                        SKIP_SECTIONS=true
                    fi
                    ;;
            esac
        done < "$config_file"
    fi
}

find_config_up() {
    local start="$1"
    local current i
    if [[ -f "$start" ]]; then
        start=$(dirname "$start")
    fi
    current=$(cd "$start" 2>/dev/null && pwd) || return 1
    for ((i = 0; i <= 5; i++)); do
        if [[ -f "$current/.ep-kit" ]]; then
            printf '%s\n' "$current/.ep-kit"
            return 0
        fi
        [[ "$current" == "/" ]] && break
        current=$(dirname "$current")
    done
    return 1
}

emit_json() {
    if $JSON_MODE; then
        JSON_OUTPUT="${JSON_OUTPUT}${1}"$'\n'
    fi
}

json_escape() {
    local value="$1"
    local i char replacement
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    for ((i = 1; i < 32; i++)); do
        printf -v char "\\$(printf '%03o' "$i")"
        printf -v replacement '\\u%04x' "$i"
        value=${value//$char/$replacement}
    done
    printf '%s' "$value"
}

normalize_scalar() {
    local value="$1" rest core
    if [[ "$value" == \"* ]]; then
        rest="${value#\"}"
        if [[ "$rest" == *\"* ]]; then
            core="${value%\"*}"
            core="${core#\"}"
            core="${core//\\\"/\"}"
            core="${core//\\\\/\\}"
            value="$core"
        fi
    elif [[ "$value" == \'* ]]; then
        rest="${value#\'}"
        if [[ "$rest" == *\'* ]]; then
            core="${value%\'*}"
            core="${core#\'}"
            core="${core//\'\'/\'}"
            value="$core"
        fi
    fi
    printf '%s\n' "$value"
}

emit_json_diagnostic() {
    local level="$1"
    local msg="$2"
    local entry
    entry="{\"level\":\"$level\",\"message\":\"$(json_escape "$msg")\"}"

    if $JSON_FILE_OPEN; then
        if [[ $JSON_CHECK_COUNT -gt 0 ]]; then
            emit_json ","
        fi
        emit_json "$entry"
        JSON_CHECK_COUNT=$((JSON_CHECK_COUNT + 1))
    else
        if [[ $JSON_GLOBAL_COUNT -gt 0 ]]; then
            JSON_GLOBAL_OUTPUT="${JSON_GLOBAL_OUTPUT},"$'\n'
        fi
        JSON_GLOBAL_OUTPUT="${JSON_GLOBAL_OUTPUT}${entry}"$'\n'
        JSON_GLOBAL_COUNT=$((JSON_GLOBAL_COUNT + 1))
    fi
}

error() {
    local msg="$1"
    if $JSON_MODE; then
        emit_json_diagnostic "error" "$msg"
    else
        echo -e "  ${RED}ERROR${NC}: $msg"
    fi
    ERRORS=$((ERRORS + 1))
}

warn() {
    local msg="$1"
    if $JSON_MODE; then
        emit_json_diagnostic "warn" "$msg"
    else
        echo -e "  ${YELLOW}WARN${NC}: $msg"
    fi
    WARNINGS=$((WARNINGS + 1))
}

ok() {
    if ! $JSON_MODE; then
        echo -e "  ${GREEN}OK${NC}: $1"
    fi
}

# Extract a YAML frontmatter field value (simple single-line values)
# Usage: get_field "title" < file
get_field() {
    local field="$1"
    local fm="$2"
    local value
    value=$(echo "$fm" | awk -v f="$field" '
        /^---$/ { if (n==1) exit; n++; next }
        n==1 && $0 ~ "^"f":" {
            sub("^"f":[ ]*", "")
            # Strip inline comments: # not inside quotes
            # Simple heuristic: if no quote before #, strip
            if (index($0, "\"") == 0) {
                sub(/#.*$/, "")
            }
            gsub(/ +$/, "")
            print
            exit
        }
    ')
    value=$(normalize_scalar "$value")
    printf '%s\n' "$value"
}

# Extract a YAML list field as space-separated values.
# Handles both inline [1, 2, 3] and multi-line:
#   requires:
#     - 1
#     - 2
# Usage: get_list "requires" <file>
get_list() {
    local field="$1"
    local fm="$2"
    # First try inline format: field: [1, 2]
    local inline
    inline=$(echo "$fm" | awk -v f="$field" '
        /^---$/ { if (n==1) exit; n++; next }
        n==1 && $0 ~ "^"f": \\[" {
            sub("^"f":[ ]*\\[", "")
            sub("\\].*$", "")
            gsub(/[ ,]+/, " ")
            gsub(/^ +| +$/, "")
            print
            exit
        }
    ')
    if [[ -n "$inline" ]]; then
        echo "$inline"
        return
    fi
    # Try multi-line format:
    # field:
    #   - 1
    #   - 2
    echo "$fm" | awk -v f="$field" '
        /^---$/ { if (n==1) exit; n++; next }
        n==1 && $0 ~ "^"f":$" {
            collecting = 1
            next
        }
        collecting && /^[[:space:]]*-[[:space:]]/ {
            sub(/^[[:space:]]*-[[:space:]]*/, "")
            gsub(/[[:space:]]/, "")
            if (val != "") val = val " "
            val = val $0
        }
        collecting && /^[[:space:]]*[^[:space:]-]/ {
            # Non-list line means we are done
            exit
        }
        END { if (val != "") print val }
    '
}

get_relationship_refs() {
    local field="$1"
    local fm="$2"
    local refs scalar
    refs=$(get_list "$field" "$fm")
    if [[ -n "$refs" ]]; then
        printf '%s\n' "$refs"
        return
    fi
    if [[ "$field" == "superseded-by" ]]; then
        scalar=$(get_field "$field" "$fm")
        if [[ -n "$scalar" && "$scalar" != "[]" ]]; then
            printf '%s\n' "$scalar"
        fi
    fi
}

# Normalize a relationship reference to its integer EP number. Accept both
# the v1 numeric form (`1`) and canonical labels used by larger catalogues
# (`"EP-0001"`, `"RFC-0001"`).
normalize_ref() {
    local value="$1"
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    if [[ "$value" =~ ^[[:alpha:]][[:alnum:]_-]*-([0-9]+)$ ]]; then
        value="${BASH_REMATCH[1]}"
    fi
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    value=$(printf '%s' "$value" | sed 's/^0*//')
    printf '%s\n' "${value:-0}"
}

list_contains_ref() {
    local values="$1"
    local expected="$2"
    local value normalized
    for value in $values; do
        normalized=$(normalize_ref "$value") || continue
        if [[ "$normalized" == "$expected" ]]; then
            return 0
        fi
    done
    return 1
}

find_ep_file() {
    local ep_dir="$1"
    local ep_num="$2"
    local pattern
    printf -v pattern '%04d-*.md' "$ep_num"
    find "$ep_dir" -maxdepth 1 -type f -name "$pattern" -print -quit
}

# Get the EP number from frontmatter using configured prefix
get_ep_num() {
    get_field "$PREFIX" "$1"
}

# Extract history entries as `index|date|status|superseded-by` records, preserving missing
# values so malformed entries can be reported instead of silently skipped.
get_history_records() {
    local fm="$1"
    echo "$fm" | awk '
        function emit() {
            if (active) print entry_index "|" date "|" status "|" superseded_by
            active = 0
            date = ""
            status = ""
            superseded_by = ""
        }
        /^---$/ { if (n==1) exit; n++; next }
        n==1 && /^history:[[:space:]]*$/ { history = 1; next }
        history && /^[^[:space:]]/ { emit(); exit }
        history && /^  -[[:space:]]/ {
            emit()
            active = 1
            entry_index++
            line = $0
            if (line ~ /^  - date:/) {
                sub(/^  - date:[[:space:]]*/, "", line)
                sub(/[[:space:]]+#.*$/, "", line)
                date = line
            } else if (line ~ /^  - status:/) {
                sub(/^  - status:[[:space:]]*/, "", line)
                sub(/[[:space:]]+#.*$/, "", line)
                status = line
            }
            next
        }
        history && /^    date:/ {
            line = $0
            sub(/^    date:[[:space:]]*/, "", line)
            sub(/[[:space:]]+#.*$/, "", line)
            date = line
            next
        }
        history && /^    status:/ {
            line = $0
            sub(/^    status:[[:space:]]*/, "", line)
            sub(/[[:space:]]+#.*$/, "", line)
            status = line
            next
        }
        history && /^    superseded-by:/ {
            line = $0
            sub(/^    superseded-by:[[:space:]]*/, "", line)
            sub(/[[:space:]]+#.*$/, "", line)
            superseded_by = line
            next
        }
        END { emit() }
    '
}

# Count decision log entries (### DX. pattern with required dot separator)
count_decisions() {
    local count
    count=$(grep -cE '^### D[0-9]+\.' "$1" 2>/dev/null || true)
    echo "${count:-0}"
}

# Validate a single EP file
validate_ep() {
    local file="$1"
    local bname
    bname=$(basename "$file")
    FILES_CHECKED=$((FILES_CHECKED + 1))

    if $JSON_MODE; then
        if [[ $JSON_FILE_COUNT -gt 0 ]]; then
            emit_json ","
        fi
        emit_json "{\"file\":\"$(json_escape "$bname")\",\"checks\":["
        JSON_FILE_OPEN=true
        JSON_CHECK_COUNT=0
        JSON_FILE_COUNT=$((JSON_FILE_COUNT + 1))
    fi

    # Check frontmatter exists
    if ! head -1 "$file" | grep -q '^---$'; then
        error "$bname: missing YAML frontmatter (must start with ---)"
        if $JSON_MODE; then emit_json "]}"; JSON_FILE_OPEN=false; fi
        return
    fi

    # Check frontmatter closes
    local fm_end
    fm_end=$(awk '/^---$/ { n++; if (n==2) { print NR; exit } }' "$file")
    if [[ -z "$fm_end" ]]; then
        error "$bname: frontmatter never closed (missing second ---)"
        if $JSON_MODE; then emit_json "]}"; JSON_FILE_OPEN=false; fi
        return
    fi

    # Extract frontmatter for checks
    local fm
    fm=$(sed -n "1,${fm_end}p" "$file")

    # Check required fields
    local ep_num ep_num_normalized title author status type created
    ep_num=$(get_field "$PREFIX" "$fm")
    title=$(get_field "title" "$fm")
    author=$(get_field "author" "$fm")
    status=$(get_field "status" "$fm")
    type=$(get_field "type" "$fm")
    created=$(get_field "created" "$fm")
    ep_num_normalized=$(normalize_ref "$ep_num" 2>/dev/null || true)

    if [[ -z "$ep_num" ]]; then
        error "$bname: missing '$PREFIX' field"
    elif [[ -z "$ep_num_normalized" || "$ep_num_normalized" == "0" ]]; then
        error "$bname: '$PREFIX' must be a positive integer or canonical label, got '$ep_num'"
    fi

    if [[ -z "$title" ]]; then
        error "$bname: missing 'title' field"
    elif [[ ${#title} -gt 60 ]]; then
        warn "$bname: title is ${#title} chars (recommended: ≤60)"
    fi

    if [[ -z "$author" ]]; then
        error "$bname: missing 'author' field"
    elif ! grep -q '<.*@.*>' <<< "$author"; then
        warn "$bname: author should be 'Name <email>' format"
    fi

    if [[ -z "$status" ]]; then
        error "$bname: missing 'status' field"
    else
        case "$status" in
            Placeholder|Draft|Accepted|Partial|Implemented|Superseded|Withdrawn|Rejected) ;;
            *) error "$bname: invalid status '$status'" ;;
        esac
    fi

    if [[ -z "$type" ]]; then
        error "$bname: missing 'type' field"
    else
        case "$type" in
            Standards|Informational|Process) ;;
            *) error "$bname: invalid type '$type'" ;;
        esac
    fi

    if [[ -z "$created" ]]; then
        error "$bname: missing 'created' field"
    elif ! grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' <<< "$created"; then
        error "$bname: 'created' must be YYYY-MM-DD format, got '$created'"
    fi

    if [[ "$type" == "Standards" && "$status" == "Implemented" ]]; then
        local implemented_in
        implemented_in=$(get_field "implemented-in" "$fm")
        if [[ -z "$implemented_in" ]]; then
            error "$bname: Implemented Standards EP is missing 'implemented-in'"
        fi
    fi

    # Check history field exists
    if ! grep -q '^history:' <<< "$fm"; then
        error "$bname: missing 'history' field"
    else
        local history_records history_index history_date history_status history_superseded_by
        local last_status="" top_superseded_refs history_superseded_ref
        history_records=$(get_history_records "$fm")
        if [[ -z "$history_records" ]]; then
            error "$bname: history must contain at least one entry"
        fi
        top_superseded_refs=$(get_relationship_refs "superseded-by" "$fm")
        while IFS='|' read -r history_index history_date history_status history_superseded_by; do
            [[ -z "$history_index" ]] && continue
            history_date=$(normalize_scalar "$history_date")
            history_status=$(normalize_scalar "$history_status")
            if [[ -z "$history_date" ]]; then
                error "$bname: history[$history_index] missing date"
            elif ! [[ "$history_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                error "$bname: history[$history_index] date must be YYYY-MM-DD, got '$history_date'"
            fi
            if [[ -z "$history_status" ]]; then
                error "$bname: history[$history_index] missing status"
            else
                case "$history_status" in
                    Placeholder|Draft|Accepted|Partial|Implemented|Superseded|Withdrawn|Rejected) ;;
                    *) error "$bname: history[$history_index] has invalid status '$history_status'" ;;
                esac
            fi
            if [[ "$history_status" == "Superseded" ]]; then
                if [[ -z "$history_superseded_by" ]]; then
                    error "$bname: history[$history_index] status Superseded is missing superseded-by"
                else
                    history_superseded_by=$(printf '%s' "$history_superseded_by" | sed 's/^\[//; s/\]$//')
                    history_superseded_ref=$(normalize_ref "$history_superseded_by" 2>/dev/null || true)
                    if [[ -z "$history_superseded_ref" ]] || ! list_contains_ref "$top_superseded_refs" "$history_superseded_ref"; then
                        error "$bname: history[$history_index] superseded-by does not match top-level superseded-by"
                    fi
                fi
            fi
            last_status="$history_status"
        done <<< "$history_records"
        if [[ -n "$last_status" && -n "$status" && "$last_status" != "$status" ]]; then
            error "$bname: top-level status '$status' doesn't match last history entry '$last_status'"
        fi
    fi

    # Check filename matches EP number
    if [[ ! "$bname" =~ ^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]]; then
        error "$bname: filename must be NNNN-lower-kebab-title.md"
    fi
    if [[ -n "$ep_num" ]]; then
        local filename_num normalized_ep_num
        filename_num=$(echo "$bname" | grep -oE '^[0-9]+' | sed 's/^0*//' || echo "")
        normalized_ep_num=$(normalize_ref "$ep_num" 2>/dev/null || true)
        if [[ -z "$filename_num" ]]; then
            warn "$bname: filename doesn't start with a number"
        elif [[ -n "$normalized_ep_num" && "$filename_num" != "$normalized_ep_num" ]]; then
            error "$bname: filename number ($filename_num) doesn't match $PREFIX field ($ep_num)"
        fi
    fi

    # Section checks (skippable via config for retrofit projects)
    if ! $SKIP_SECTIONS; then
        local content
        content=$(sed -n "$((fm_end + 1)),\$p" "$file")

        if [[ "$type" != "Process" ]]; then
            for section in "Problem" "Goals" "Non-goals" "Design"; do
                if ! grep -q "^## $section" <<< "$content"; then
                    error "$bname: missing '## $section' section"
                fi
            done
        fi
        if ! grep -q '^## Decision log' <<< "$content"; then
            error "$bname: missing '## Decision log' section"
        fi

        # Type-specific section checks
        if [[ "$type" == "Standards" ]]; then
            for section in "Migration" "Failure modes" "Test strategy"; do
                if ! grep -q "^## $section" <<< "$content"; then
                    warn "$bname: Standards EP missing '## $section' section"
                fi
            done
        fi

        # Check for Open questions section (recommended for all types)
        if [[ "$type" != "Process" ]] && ! grep -q "^## Open questions" <<< "$content"; then
            warn "$bname: missing '## Open questions' section (recommended)"
        fi
    fi

    # Decision log checks
    local decision_count
    decision_count=$(count_decisions "$file")
    decision_count="${decision_count:-0}"
    decision_count=$(echo "$decision_count" | tr -d '[:space:]')

    if [[ "$decision_count" -eq 0 ]] 2>/dev/null; then
        error "$bname: no decision log entries found (need at least one)"
    else
        case "$status" in
            Draft)
                if [[ "$type" == "Standards" && "$decision_count" -lt 3 ]]; then
                    error "$bname: Standards Draft needs ≥3 decision log entries, found $decision_count"
                fi
                ;;
            Placeholder)
                if [[ "$decision_count" -lt 1 ]]; then
                    error "$bname: Placeholder needs ≥1 decision log entry, found $decision_count"
                fi
                ;;
        esac

        # Check decision log format (Decided/Alternatives/Why)
        # Regex requires dot separator to avoid matching date-like headings
        local in_decision=false
        local has_decided=false has_alternatives=false has_why=false
        local current_decision=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^###[[:space:]]D[0-9]+\. ]]; then
                # Check previous decision if any
                if $in_decision; then
                    if ! $has_decided; then
                        error "$bname: $current_decision missing '**Decided:'"
                    fi
                    if ! $has_alternatives; then
                        warn "$bname: $current_decision missing '**Alternatives:'"
                    fi
                    if ! $has_why; then
                        error "$bname: $current_decision missing '**Why:'"
                    fi
                fi
                in_decision=true
                has_decided=false
                has_alternatives=false
                has_why=false
                current_decision="$line"
            elif $in_decision; then
                [[ "$line" == *'**Decided:'* ]] && has_decided=true
                [[ "$line" == *'**Alternatives:'* ]] && has_alternatives=true
                [[ "$line" == *'**Why:'* ]] && has_why=true
            fi
        done < "$file"
        # Check last decision
        if $in_decision; then
            if ! $has_decided; then
                error "$bname: $current_decision missing '**Decided:'"
            fi
            if ! $has_alternatives; then
                warn "$bname: $current_decision missing '**Alternatives:'"
            fi
            if ! $has_why; then
                error "$bname: $current_decision missing '**Why:'"
            fi
        fi
    fi

    # Check for unresolved placeholders
    local placeholder_count
    placeholder_count=$(grep -ciE '\b(TODO|FIXME|TBD|XXX)\b' "$file" 2>/dev/null || true)
    placeholder_count="${placeholder_count:-0}"
    placeholder_count=$(echo "$placeholder_count" | tr -d '[:space:]')
    if [[ "$placeholder_count" -gt 0 ]] 2>/dev/null; then
        warn "$bname: $placeholder_count unresolved marker(s) found (TODO/FIXME/TBD/XXX)"
    fi

    # Validate relationship targets and the two strong reciprocal pairs.
    # `requires` is dependency metadata, not an extension relationship.
    local ep_dir this_num field refs ref normalized ref_actual ref_fm_end ref_fm
    local reciprocal reciprocal_refs ref_status
    ep_dir=$(dirname "$file")
    this_num=$(normalize_ref "$ep_num" 2>/dev/null || true)
    for field in requires extends supersedes superseded-by extended-by see-also; do
        if ! grep -q "^${field}:" <<< "$fm"; then
            continue
        fi
        if ! grep -qE "^${field}:[[:space:]]*(\[|$)" <<< "$fm"; then
            if [[ "$field" == "superseded-by" ]]; then
                warn "$bname: scalar superseded-by is legacy v1 syntax; migrate it to a one-item YAML list"
            else
                error "$bname: '$field' must use YAML list syntax, even for one value"
                continue
            fi
        fi
        refs=$(get_relationship_refs "$field" "$fm")
        for ref in $refs; do
            normalized=$(normalize_ref "$ref" 2>/dev/null || true)
            if [[ -z "$normalized" || "$normalized" == "0" ]]; then
                error "$bname: invalid $field reference '$ref'"
                continue
            fi
            if [[ -n "$this_num" && "$normalized" == "$this_num" ]]; then
                error "$bname: $field must not reference the EP itself"
                continue
            fi
            ref_actual=$(find_ep_file "$ep_dir" "$normalized")
            if [[ -z "$ref_actual" ]]; then
                error "$bname: $field references [$ref] but no matching EP file exists"
                continue
            fi

            reciprocal=""
            case "$field" in
                extends) reciprocal="extended-by" ;;
                extended-by) reciprocal="extends" ;;
                supersedes) reciprocal="superseded-by" ;;
                superseded-by) reciprocal="supersedes" ;;
            esac
            if [[ -z "$reciprocal" ]]; then
                continue
            fi

            ref_fm_end=$(awk '/^---$/ { n++; if (n==2) { print NR; exit } }' "$ref_actual")
            ref_fm=$(sed -n "1,${ref_fm_end}p" "$ref_actual")
            reciprocal_refs=$(get_relationship_refs "$reciprocal" "$ref_fm")
            if [[ -z "$this_num" ]] || ! list_contains_ref "$reciprocal_refs" "$this_num"; then
                # v1.0 incorrectly used `requires` as the forward half of an
                # extension pair. Accept that installed representation with a
                # migration warning so a minor update does not break existing
                # catalogues.
                if [[ "$field" == "extended-by" ]] && list_contains_ref "$(get_list "requires" "$ref_fm")" "$this_num"; then
                    warn "$bname: extended-by [$ref] uses legacy reciprocal requires [$ep_num]; migrate it to extends [$ep_num]"
                else
                    error "$bname: $field [$ref] but $(basename "$ref_actual") lacks reciprocal $reciprocal [$ep_num]"
                fi
            fi

            if [[ "$field" == "supersedes" ]]; then
                ref_status=$(get_field "status" "$ref_fm")
                if [[ "$ref_status" != "Superseded" ]]; then
                    error "$bname: supersedes [$ref] but $(basename "$ref_actual") status is '$ref_status' (expected 'Superseded')"
                fi
            fi
        done
    done

    if grep -q '^superseded-by:' <<< "$fm" && [[ "$status" != "Superseded" ]]; then
        error "$bname: has superseded-by but status is '$status' (expected 'Superseded')"
    fi

    if $JSON_MODE; then
        emit_json "]}"
        JSON_FILE_OPEN=false
    fi

}

# Check for duplicate EP numbers across all files
check_duplicate_numbers() {
    local ep_dir="$1"
    local -A seen_numbers

    while IFS= read -r file; do
        local bname
        bname=$(basename "$file")
        local fm_end
        fm_end=$(awk '/^---$/ { n++; if (n==2) { print NR; exit } }' "$file")
        [[ -z "$fm_end" ]] && continue
        local fm
        fm=$(sed -n "1,${fm_end}p" "$file")
        local ep_num
        ep_num=$(get_field "$PREFIX" "$fm")
        [[ -z "$ep_num" ]] && continue
        ep_num=$(normalize_ref "$ep_num" 2>/dev/null || true)
        [[ -z "$ep_num" || "$ep_num" == "0" ]] && continue

        if [[ -n "${seen_numbers[$ep_num]:-}" ]]; then
            error "$bname: duplicate $PREFIX number $ep_num (also in $(basename "${seen_numbers[$ep_num]}"))"
        else
            seen_numbers[$ep_num]="$file"
        fi
    done < <(find "$ep_dir" -name '[0-9][0-9][0-9][0-9]-*.md' -type f | sort)
}

# Keep the human catalogue synchronized with the machine-readable
# frontmatter. This check is enabled whenever the target directory has a
# README.md with the standard `## Index` table.
check_index() {
    local ep_dir="$1"
    local index="$ep_dir/README.md"
    [[ -f "$index" ]] || return
    if ! grep -q '^## Index[[:space:]]*$' "$index"; then
        warn "$(basename "$index"): missing '## Index' section; catalogue consistency was not checked"
        return
    fi

    local file bname fm_end fm ep_num normalized_num title type status expected matches
    while IFS= read -r file; do
        bname=$(basename "$file")
        fm_end=$(awk '/^---$/ { n++; if (n==2) { print NR; exit } }' "$file")
        [[ -z "$fm_end" ]] && continue
        fm=$(sed -n "1,${fm_end}p" "$file")
        ep_num=$(get_field "$PREFIX" "$fm")
        title=$(get_field "title" "$fm")
        type=$(get_field "type" "$fm")
        status=$(get_field "status" "$fm")
        [[ -z "$ep_num" || -z "$title" || -z "$type" || -z "$status" ]] && continue
        normalized_num=$(normalize_ref "$ep_num" 2>/dev/null || true)
        [[ -z "$normalized_num" || "$normalized_num" == "0" ]] && continue
        printf -v ep_num '%04d' "$normalized_num"
        expected="| $ep_num | [$title](./$bname) | $type | $status |"
        matches=$(grep -Fxc -- "$expected" "$index" 2>/dev/null || true)
        if [[ "$matches" -eq 0 ]]; then
            error "$(basename "$index"): missing or stale index row for $bname (expected: $expected)"
        elif [[ "$matches" -gt 1 ]]; then
            error "$(basename "$index"): duplicate index row for $bname"
        fi
    done < <(find "$ep_dir" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.md' -type f ! -name '0000-template.md' | sort)

    local indexed_num indexed_file
    local -A seen_index_numbers=()
    while IFS= read -r indexed_num; do
        indexed_num=$(normalize_ref "$indexed_num")
        if [[ -n "${seen_index_numbers[$indexed_num]:-}" ]]; then
            error "$(basename "$index"): more than one index row claims $(printf '%04d' "$indexed_num")"
        fi
        seen_index_numbers[$indexed_num]=1
        indexed_file=$(find_ep_file "$ep_dir" "$indexed_num")
        if [[ -z "$indexed_file" ]]; then
            error "$(basename "$index"): index row $indexed_num has no matching EP file"
        fi
    done < <(awk -F'|' '
        /^## Index[[:space:]]*$/ { in_index=1; next }
        in_index && /^## / { exit }
        in_index {
            value=$2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^[0-9][0-9][0-9][0-9]$/) print value
        }
    ' "$index")
}

# Main
main() {
    local target=""
    local config_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --config requires a file" >&2
                    exit 1
                fi
                config_file="$2"
                shift 2
                ;;
            --config=*)
                config_file="${1#--config=}"
                shift
                ;;
            --skip-sections)
                SKIP_SECTIONS=true
                shift
                ;;
            --json)
                JSON_MODE=true
                shift
                ;;
            --no-autoconfig)
                NO_AUTOCONFIG=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options] [directory | file]"
                echo ""
                echo "Options:"
                echo "  --config <file>    Load config from file (default: .ep-kit)"
                echo "  --skip-sections    Skip required section checks"
                echo "  --json             Output JSON instead of colored text"
                echo "  --no-autoconfig    Disable auto-discovery of .ep-kit config"
                echo "  --help             Show this help"
                echo ""
                echo "Config file keys:"
                echo "  prefix=<name>      Frontmatter field name (default: ep)"
                echo "  dir=<path>         Default directory to validate"
                echo "  skip_sections=1    Skip required section checks"
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                if [[ -n "$target" ]]; then
                    echo "Error: multiple targets provided" >&2
                    exit 1
                fi
                target="$1"
                shift
                ;;
        esac
    done

    # Load an explicit config, or discover one from CWD, before resolving the
    # default target so `dir=` works without a positional argument.
    local discovered_config=""
    if [[ -n "$config_file" ]]; then
        if [[ ! -f "$config_file" ]]; then
            echo "Config file does not exist: $config_file" >&2
            exit 1
        fi
        load_config "$config_file"
    elif ! $NO_AUTOCONFIG; then
        if [[ -n "$target" ]]; then
            discovered_config=$(find_config_up "$target" || true)
        else
            discovered_config=$(find_config_up "." || true)
        fi
        if [[ -n "$discovered_config" ]]; then
            load_config "$discovered_config"
        fi
    fi

    local ep_dir=""

    if [[ -n "$target" && -f "$target" ]]; then
        ep_dir=$(dirname "$target")
    elif [[ -n "$target" && -d "$target" ]]; then
        ep_dir="$target"
    elif [[ -n "$target" ]]; then
        echo "Target does not exist: $target" >&2
        exit 1
    elif [[ -n "$CONFIG_EP_DIR" && -d "$CONFIG_EP_DIR" ]]; then
        ep_dir="$CONFIG_EP_DIR"
    elif [[ -n "$CONFIG_EP_DIR" ]]; then
        echo "Configured EP directory does not exist: $CONFIG_EP_DIR" >&2
        exit 1
    elif [[ -d "docs/eps" ]]; then
        ep_dir="docs/eps"
    else
        echo "Usage: $0 [directory | file]" >&2
        echo "  Default: docs/eps/" >&2
        exit 1
    fi

    # A positional target may belong to a project other than CWD. If CWD did
    # not provide a config, discover one relative to that target.
    if [[ -z "$LOADED_CONFIG" ]] && ! $NO_AUTOCONFIG; then
        discovered_config=$(find_config_up "$ep_dir" || true)
        if [[ -n "$discovered_config" ]]; then
            load_config "$discovered_config"
        fi
    fi

    if [[ ! "$PREFIX" =~ ^[[:alpha:]_][[:alnum:]_-]*$ ]]; then
        echo "Invalid prefix in EP Kit config: $PREFIX" >&2
        exit 1
    fi

    if $JSON_MODE; then
        emit_json "{\"prefix\":\"$(json_escape "$PREFIX")\",\"files\":["
    fi

    if [[ -n "$target" && -f "$target" ]]; then
        # Single file mode
        if ! $JSON_MODE; then
            echo "Validating: $target"
            echo "Prefix: $PREFIX"
            if $SKIP_SECTIONS; then echo "Sections: skipped"; fi
            echo ""
        fi
        validate_ep "$target"
    else
        if ! $JSON_MODE; then
            echo "Validating EPs in $ep_dir/"
            echo "Prefix: $PREFIX"
            if $SKIP_SECTIONS; then echo "Sections: skipped"; fi
            echo ""
        fi

        # Collect files and skip template
        files=$(find "$ep_dir" -name '[0-9][0-9][0-9][0-9]-*.md' -type f | sort | grep -v '/0000-template.md$' || true)
        if [[ -z "$files" ]]; then
            echo "No EP files found in $ep_dir/" >&2
            exit 1
        fi

        # Check for duplicate EP numbers
        check_duplicate_numbers "$ep_dir"

        while IFS= read -r file; do
            local bname
            bname=$(basename "$file")
            if ! $JSON_MODE; then
                echo "━━━ $bname ━━━"
            fi
            validate_ep "$file"
            if ! $JSON_MODE; then
                echo ""
            fi
        done <<< "$files"

        check_index "$ep_dir"
    fi

    if $JSON_MODE; then
        emit_json "],"
        emit_json "\"diagnostics\":["
        if [[ -n "$JSON_GLOBAL_OUTPUT" ]]; then
            JSON_OUTPUT="${JSON_OUTPUT}${JSON_GLOBAL_OUTPUT}"
        fi
        emit_json "],"
        emit_json "\"summary\":{\"files_checked\":$FILES_CHECKED,\"errors\":$ERRORS,\"warnings\":$WARNINGS}}"
        printf '%s' "$JSON_OUTPUT"
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Checked: $FILES_CHECKED file(s)"
        if [[ $ERRORS -gt 0 ]]; then
            echo -e "${RED}Errors:   $ERRORS${NC}"
        else
            echo -e "${GREEN}Errors:   0${NC}"
        fi
        if [[ $WARNINGS -gt 0 ]]; then
            echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
        else
            echo -e "${GREEN}Warnings: 0${NC}"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
