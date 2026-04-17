#!/usr/bin/env bash
# EP Validator — deterministic checks for Enhancement Proposal files.
#
# Usage:
#   ./validate.sh                  # validate all EPs in docs/eps/
#   ./validate.sh docs/geps/       # custom directory
#   ./validate.sh docs/geps/0003-foo.md  # single file
#   ./validate.sh --config .ep-kit docs/geps/  # with config file
#   ./validate.sh --json docs/geps/  # JSON output for CI
#
# Config file (optional):
#   If a config file exists (default: .ep-kit in project root), it can
#   override defaults. Supported keys:
#     prefix=gep          # frontmatter field name (default: ep)
#     dir=docs/geps       # default directory to validate
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

# JSON output accumulator
JSON_OUTPUT=""

# Defaults — overridable via config file
PREFIX="ep"
SKIP_SECTIONS=false

# Parse config file
# Usage: load_config ".ep-kit"
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and blank lines
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            case "$key" in
                prefix) PREFIX="$value" ;;
                dir) ;; # handled by arg parsing
                skip_sections)
                    if [[ "$value" == "1" || "$value" == "true" ]]; then
                        SKIP_SECTIONS=true
                    fi
                    ;;
            esac
        done < "$config_file"
    fi
}

emit_json() {
    if $JSON_MODE; then
        JSON_OUTPUT="${JSON_OUTPUT}${1}"$'\n'
    fi
}

error() {
    local msg="$1"
    if $JSON_MODE; then
        emit_json "{\"level\":\"error\",\"message\":\"$(echo "$msg" | sed 's/"/\\"/g')\"}"
    else
        echo -e "  ${RED}ERROR${NC}: $msg"
    fi
    ERRORS=$((ERRORS + 1))
}

warn() {
    local msg="$1"
    if $JSON_MODE; then
        emit_json "{\"level\":\"warn\",\"message\":\"$(echo "$msg" | sed 's/"/\\"/g')\"}"
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
    echo "$fm" | awk -v f="$field" '
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
    '
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

# Get the EP number from frontmatter using configured prefix
get_ep_num() {
    get_field "$PREFIX" "$1"
}

# Extract history entries as "date status" pairs
get_history_entries() {
    local fm="$1"
    echo "$fm" | awk '
        /^---$/ { if (n==1) exit; n++; next }
        n==1 && /^  - date:/ {
            date = $3
            getline
            if ($0 ~ /status:/) {
                sub(/.*status:[ ]*/, "")
                print date, $0
            }
        }
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

    if $JSON_MODE; then
        emit_json "{\"file\":\"$bname\",\"checks\":["
    fi

    # Check frontmatter exists
    if ! head -1 "$file" | grep -q '^---$'; then
        error "$bname: missing YAML frontmatter (must start with ---)"
        if $JSON_MODE; then emit_json "]}"; fi
        return
    fi

    # Check frontmatter closes
    local fm_end
    fm_end=$(awk '/^---$/ { n++; if (n==2) { print NR; exit } }' "$file")
    if [[ -z "$fm_end" ]]; then
        error "$bname: frontmatter never closed (missing second ---)"
        if $JSON_MODE; then emit_json "]}"; fi
        return
    fi

    # Extract frontmatter for checks
    local fm
    fm=$(sed -n "1,${fm_end}p" "$file")

    # Check required fields
    local ep_num title author status type created
    ep_num=$(get_field "$PREFIX" "$fm")
    title=$(get_field "title" "$fm")
    author=$(get_field "author" "$fm")
    status=$(get_field "status" "$fm")
    type=$(get_field "type" "$fm")
    created=$(get_field "created" "$fm")

    if [[ -z "$ep_num" ]]; then
        error "$bname: missing '$PREFIX' field"
    fi

    if [[ -z "$title" ]]; then
        error "$bname: missing 'title' field"
    elif [[ ${#title} -gt 60 ]]; then
        warn "$bname: title is ${#title} chars (recommended: ≤60)"
    fi

    if [[ -z "$author" ]]; then
        error "$bname: missing 'author' field"
    elif ! echo "$author" | grep -q '<.*@.*>'; then
        warn "$bname: author should be 'Name <email>' format"
    fi

    if [[ -z "$status" ]]; then
        error "$bname: missing 'status' field"
    else
        case "$status" in
            Placeholder|Draft|Accepted|Implemented|Superseded|Withdrawn|Rejected) ;;
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
    elif ! echo "$created" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        error "$bname: 'created' must be YYYY-MM-DD format, got '$created'"
    fi

    # Check history field exists
    if ! echo "$fm" | grep -q '^history:'; then
        error "$bname: missing 'history' field"
    else
        # Verify last history entry status matches top-level status
        local last_status
        last_status=$(get_history_entries "$fm" | tail -1 | awk '{print $2}')
        if [[ -n "$last_status" && -n "$status" && "$last_status" != "$status" ]]; then
            error "$bname: top-level status '$status' doesn't match last history entry '$last_status'"
        fi
    fi

    # Check filename matches EP number
    if [[ -n "$ep_num" ]]; then
        local filename_num
        filename_num=$(echo "$bname" | grep -oE '^[0-9]+' | sed 's/^0*//' || echo "")
        if [[ -z "$filename_num" ]]; then
            warn "$bname: filename doesn't start with a number"
        elif [[ "$filename_num" != "$ep_num" ]]; then
            error "$bname: filename number ($filename_num) doesn't match $PREFIX field ($ep_num)"
        fi
    fi

    # Section checks (skippable via config for retrofit projects)
    if ! $SKIP_SECTIONS; then
        local content
        content=$(sed -n "$((fm_end + 1)),\$p" "$file")

        for section in "Problem" "Goals" "Non-goals" "Design" "Decision log"; do
            if ! echo "$content" | grep -q "^## $section"; then
                error "$bname: missing '## $section' section"
            fi
        done

        # Type-specific section checks
        if [[ "$type" == "Standards" ]]; then
            for section in "Migration" "Failure modes" "Test strategy"; do
                if ! echo "$content" | grep -q "^## $section"; then
                    warn "$bname: Standards EP missing '## $section' section"
                fi
            done
        fi

        # Check for Open questions section (recommended for all types)
        if ! echo "$content" | grep -q "^## Open questions"; then
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
            if echo "$line" | grep -qE '^### D[0-9]+\.'; then
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
                echo "$line" | grep -q '\*\*Decided:' && has_decided=true
                echo "$line" | grep -q '\*\*Alternatives:' && has_alternatives=true
                echo "$line" | grep -q '\*\*Why:' && has_why=true
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
    placeholder_count=$(grep -ciE '\b(TODO|FIXME|TBD|XXX|PLACEHOLDER)\b' "$file" 2>/dev/null || true)
    placeholder_count="${placeholder_count:-0}"
    placeholder_count=$(echo "$placeholder_count" | tr -d '[:space:]')
    if [[ "$placeholder_count" -gt 0 ]] 2>/dev/null; then
        warn "$bname: $placeholder_count unresolved placeholder(s) found (TODO/FIXME/TBD/XXX/PLACEHOLDER)"
    fi

    # Check bidirectional link consistency (requires → extended-by)
    local requires_refs
    requires_refs=$(get_list "requires" "$fm")
    if [[ -n "$requires_refs" ]]; then
        local ep_dir
        ep_dir=$(dirname "$file")
        for ref in $requires_refs; do
            local ref_file
            ref_file=$(printf "%s/%04d-*.md" "$ep_dir" "$ref")
            if ! ls $ref_file >/dev/null 2>&1; then
                error "$bname: requires [$ref] but no matching EP file found"
            else
                local ref_actual
                ref_actual=$(ls $ref_file | head -1)
                local ref_fm_end
                ref_fm_end=$(awk '/^---$/ { n++; if (n==2) { print NR; exit } }' "$ref_actual")
                local ref_fm
                ref_fm=$(sed -n "1,${ref_fm_end}p" "$ref_actual")
                local extended_by
                extended_by=$(get_list "extended-by" "$ref_fm")
                local this_num
                this_num=$(get_field "$PREFIX" "$fm")
                if [[ -n "$this_num" && -n "$extended_by" ]]; then
                    if ! echo " $extended_by " | grep -q " $this_num "; then
                        warn "$bname: requires [$ref] but $(basename "$ref_actual") doesn't have extended-by: [$this_num]"
                    fi
                fi
            fi
        done
    fi

    # Check supersedes references
    local supersedes_refs
    supersedes_refs=$(get_list "supersedes" "$fm")
    if [[ -n "$supersedes_refs" ]]; then
        local ep_dir
        ep_dir=$(dirname "$file")
        for ref in $supersedes_refs; do
            local ref_file
            ref_file=$(printf "%s/%04d-*.md" "$ep_dir" "$ref")
            if ! ls $ref_file >/dev/null 2>&1; then
                error "$bname: supersedes [$ref] but no matching EP file found"
            else
                local ref_actual
                ref_actual=$(ls $ref_file | head -1)
                local ref_status
                ref_status=$(awk '/^---$/ { if (n==1) exit; n++; next } n==1 && /^status:/ { sub(/status:[ ]*/, ""); print; exit }' "$ref_actual")
                if [[ "$ref_status" != "Superseded" ]]; then
                    warn "$bname: supersedes [$ref] but $(basename "$ref_actual") status is '$ref_status' (expected 'Superseded')"
                fi
            fi
        done
    fi

    # Check see-also references exist
    local see_also_refs
    see_also_refs=$(get_list "see-also" "$fm")
    if [[ -n "$see_also_refs" ]]; then
        local ep_dir
        ep_dir=$(dirname "$file")
        for ref in $see_also_refs; do
            local ref_file
            ref_file=$(printf "%s/%04d-*.md" "$ep_dir" "$ref")
            if ! ls $ref_file >/dev/null 2>&1; then
                warn "$bname: see-also [$ref] but no matching EP file found"
            fi
        done
    fi

    if $JSON_MODE; then
        emit_json "]}"
    fi

    FILES_CHECKED=$((FILES_CHECKED + 1))
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

        if [[ -n "${seen_numbers[$ep_num]:-}" ]]; then
            error "$bname: duplicate $PREFIX number $ep_num (also in $(basename "${seen_numbers[$ep_num]}"))"
        else
            seen_numbers[$ep_num]="$file"
        fi
    done < <(find "$ep_dir" -name '[0-9][0-9][0-9][0-9]-*.md' -type f | sort)
}

# Main
main() {
    local target=""
    local config_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
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
                target="$1"
                shift
                ;;
        esac
    done

    # Resolve target directory first, then load config from it
    local ep_dir=""

    if [[ -n "$target" && -f "$target" ]]; then
        ep_dir=$(dirname "$target")
    elif [[ -n "$target" && -d "$target" ]]; then
        ep_dir="$target"
    elif [[ -d "docs/eps" ]]; then
        ep_dir="docs/eps"
    else
        echo "Usage: $0 [directory | file]" >&2
        echo "  Default: docs/eps/" >&2
        exit 1
    fi

    # Load config (try explicit, then project root relative to target, then CWD)
    # Skip auto-discovery if --no-autoconfig is set
    if [[ -n "$config_file" ]]; then
        load_config "$config_file"
    elif ! $NO_AUTOCONFIG; then
        if [[ -f "$ep_dir/../../.ep-kit" ]]; then
            load_config "$ep_dir/../../.ep-kit"
        elif [[ -f "$ep_dir/../.ep-kit" ]]; then
            load_config "$ep_dir/../.ep-kit"
        elif [[ -f ".ep-kit" ]]; then
            load_config ".ep-kit"
        fi
    fi

    if $JSON_MODE; then
        emit_json "{\"prefix\":\"$PREFIX\",\"files\":["
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

        # Skip template file
        if [[ -f "$ep_dir/0000-template.md" ]]; then
            if ! $JSON_MODE; then
                echo "Skipping 0000-template.md (template file)"
            fi
        fi

        local files
        files=$(find "$ep_dir" -name '[0-9][0-9][0-9][0-9]-*.md' -type f | sort)
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
    fi

    if $JSON_MODE; then
        emit_json "],"
        emit_json "\"summary\":{\"files_checked\":$FILES_CHECKED,\"errors\":$ERRORS,\"warnings\":$WARNINGS}}"
        echo "$JSON_OUTPUT"
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
