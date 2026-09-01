#!/usr/bin/env bash
# Strata installer — scaffolds docs/eps/ in your project with templates.
#
# Usage:
#   ./install.sh                  # uses docs/eps/ and .agents/skills/ defaults
#   ./install.sh docs/rfcs/       # custom directory
#   ./install.sh --skill-dir .claude/skills/  # custom skills root
#
# Options:
#   --skill-dir <path>       Install discoverable skills below this root
#   --no-skills              Do not install project-local agent skills
#   --validator-path <path>  Vendored validator path (default: scripts/validate-eps.sh)
#   --upgrade-tools          Refresh managed validator/skill files and config keys
#   --dry-run                Print what would be done without doing it
#   --help                   Show this help

set -euo pipefail

# Defaults
EPS_DIR="docs/eps"
EPS_DIR_SET=false
SKILL_DIR=".agents/skills"
INSTALL_SKILLS=true
VALIDATOR_PATH="scripts/validate-eps.sh"
DRY_RUN=false
UPDATE_TOOLS=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SOURCE_DIR="$SCRIPT_DIR/skills"
SOURCE_VALIDATOR="$SKILLS_SOURCE_DIR/ep-kit/validate.sh"
KIT_VERSION="1.3.0"

usage() {
    sed -n '2,/^$/s/^# \?//p' "$0"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --upgrade-tools)
            UPDATE_TOOLS=true
            shift
            ;;
        --no-skills)
            INSTALL_SKILLS=false
            shift
            ;;
        --skill-dir)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "Error: --skill-dir requires a path" >&2
                exit 1
            fi
            SKILL_DIR="$2"
            shift 2
            ;;
        --skill-dir=*)
            SKILL_DIR="${1#--skill-dir=}"
            if [[ -z "$SKILL_DIR" ]]; then
                echo "Error: --skill-dir requires a path" >&2
                exit 1
            fi
            shift
            ;;
        --validator-path)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "Error: --validator-path requires a path" >&2
                exit 1
            fi
            VALIDATOR_PATH="$2"
            shift 2
            ;;
        --validator-path=*)
            VALIDATOR_PATH="${1#--validator-path=}"
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            # First positional arg is the EP directory
            if ! $EPS_DIR_SET; then
                EPS_DIR="$1"
                EPS_DIR_SET=true
            else
                echo "Error: multiple positional arguments. Use --skill-dir for the skill target." >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$VALIDATOR_PATH" ]]; then
    echo "Error: --validator-path must not be empty" >&2
    exit 1
fi
if [[ "$VALIDATOR_PATH" = /* || "$VALIDATOR_PATH" == ".." || "$VALIDATOR_PATH" == ../* || "$VALIDATOR_PATH" == */../* || "$VALIDATOR_PATH" == */.. ]]; then
    echo "Error: --validator-path must stay relative to the target project" >&2
    exit 1
fi

run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

echo "Strata installer"
echo "================"
echo ""
echo "EP directory:  $EPS_DIR"
if $INSTALL_SKILLS; then
    echo "Skills root:    $SKILL_DIR"
else
    echo "Skills:         disabled"
fi
echo "Validator:      $VALIDATOR_PATH"
if $DRY_RUN; then
    echo "Mode:          dry-run"
fi
echo ""

# Create EP directory
if [[ ! -d "$EPS_DIR" ]]; then
    echo "Creating $EPS_DIR/"
    run mkdir -p "$EPS_DIR"
else
    echo "$EPS_DIR/ already exists — skipping creation"
fi

# Copy templates
for f in 0000-template.md 0001-ep-purpose-and-guidelines.md README.md; do
    if [[ -f "$EPS_DIR/$f" ]]; then
        echo "$EPS_DIR/$f already exists — skipping"
    else
        echo "Copying templates/$f → $EPS_DIR/$f"
        run cp "$SCRIPT_DIR/templates/$f" "$EPS_DIR/$f"
    fi
done

# Vendor the validator into the target project. A relative, project-owned path
# remains usable after the checkout or temporary directory containing this
# installer is removed.
VALIDATOR_DIR=$(dirname "$VALIDATOR_PATH")
if [[ ! -d "$VALIDATOR_DIR" ]]; then
    echo "Creating $VALIDATOR_DIR/"
    run mkdir -p "$VALIDATOR_DIR"
fi
if [[ -f "$VALIDATOR_PATH" ]] && ! $UPDATE_TOOLS; then
    echo "$VALIDATOR_PATH already exists — skipping"
else
    if [[ -e "$VALIDATOR_PATH" && "$SOURCE_VALIDATOR" -ef "$VALIDATOR_PATH" ]]; then
        echo "$VALIDATOR_PATH is the source validator — keeping it"
    else
        echo "Copying validate.sh → $VALIDATOR_PATH"
        run cp "$SOURCE_VALIDATOR" "$VALIDATOR_PATH"
    fi
fi
run chmod +x "$VALIDATOR_PATH"

# Copy skills if requested
if $INSTALL_SKILLS; then
    if [[ ! -d "$SKILL_DIR" ]]; then
        echo "Creating $SKILL_DIR/"
        run mkdir -p "$SKILL_DIR"
    fi

    GOVERN_SKILL_DIR="$SKILL_DIR/ep-kit-governance"
    CREATE_SKILL_DIR="$SKILL_DIR/ep-kit"
    VALIDATE_SKILL_DIR="$SKILL_DIR/ep-kit-validate"
    for skill_path in "$GOVERN_SKILL_DIR" "$CREATE_SKILL_DIR" "$VALIDATE_SKILL_DIR"; do
        if [[ ! -d "$skill_path" ]]; then
            echo "Creating $skill_path/"
            run mkdir -p "$skill_path"
        fi
    done

    # Project-level activation and lifecycle routing skill.
    if [[ -f "$GOVERN_SKILL_DIR/SKILL.md" ]] && ! $UPDATE_TOOLS; then
        echo "$GOVERN_SKILL_DIR/SKILL.md already exists — skipping"
    else
        echo "Copying ep-kit-governance skill → $GOVERN_SKILL_DIR/SKILL.md"
        run cp "$SKILLS_SOURCE_DIR/ep-kit-governance/SKILL.md" "$GOVERN_SKILL_DIR/SKILL.md"
    fi

    # Main creation skill and its deterministic validator helper.
    if [[ -f "$CREATE_SKILL_DIR/SKILL.md" ]] && ! $UPDATE_TOOLS; then
        echo "$CREATE_SKILL_DIR/SKILL.md already exists — skipping"
    else
        echo "Copying ep-kit skill → $CREATE_SKILL_DIR/SKILL.md"
        run cp "$SKILLS_SOURCE_DIR/ep-kit/SKILL.md" "$CREATE_SKILL_DIR/SKILL.md"
    fi
    if [[ -f "$CREATE_SKILL_DIR/validate.sh" ]] && ! $UPDATE_TOOLS; then
        echo "$CREATE_SKILL_DIR/validate.sh already exists — skipping"
    else
        echo "Copying validate.sh → $CREATE_SKILL_DIR/validate.sh"
        run cp "$SOURCE_VALIDATOR" "$CREATE_SKILL_DIR/validate.sh"
    fi
    run chmod +x "$CREATE_SKILL_DIR/validate.sh"

    # Validation review skill
    if [[ -f "$VALIDATE_SKILL_DIR/SKILL.md" ]] && ! $UPDATE_TOOLS; then
        echo "$VALIDATE_SKILL_DIR/SKILL.md already exists — skipping"
    else
        echo "Copying ep-kit-validate skill → $VALIDATE_SKILL_DIR/SKILL.md"
        run cp "$SKILLS_SOURCE_DIR/ep-kit-validate/SKILL.md" "$VALIDATE_SKILL_DIR/SKILL.md"
    fi

    # Review checklist
    if [[ -f "$VALIDATE_SKILL_DIR/CHECKLIST.md" ]] && ! $UPDATE_TOOLS; then
        echo "$VALIDATE_SKILL_DIR/CHECKLIST.md already exists — skipping"
    else
        echo "Copying review checklist → $VALIDATE_SKILL_DIR/CHECKLIST.md"
        run cp "$SKILLS_SOURCE_DIR/ep-kit-validate/CHECKLIST.md" "$VALIDATE_SKILL_DIR/CHECKLIST.md"
    fi
fi

# Create .ep-kit config if it doesn't exist
CONFIG_FILE=".ep-kit"
if [[ -f "$CONFIG_FILE" ]]; then
    if $UPDATE_TOOLS; then
        echo "Updating managed tool keys in $CONFIG_FILE"
        if $DRY_RUN; then
            echo "[dry-run] set validator=$VALIDATOR_PATH and kit_version=$KIT_VERSION in $CONFIG_FILE"
        else
            update_config_key() {
                local file="$1" key="$2" value="$3" temp mode
                temp=$(mktemp "${file}.tmp.XXXXXX")
                awk -v key="$key" -v value="$value" '
                    $0 ~ "^[[:space:]]*" key "=" {
                        if (!found) print key "=" value
                        found = 1
                        next
                    }
                    { print }
                    END { if (!found) print key "=" value }
                ' "$file" > "$temp"
                if mode=$(stat -c '%a' "$file" 2>/dev/null); then
                    chmod "$mode" "$temp"
                elif mode=$(stat -f '%Lp' "$file" 2>/dev/null); then
                    chmod "$mode" "$temp"
                fi
                mv "$temp" "$file"
            }
            update_config_key "$CONFIG_FILE" validator "$VALIDATOR_PATH"
            update_config_key "$CONFIG_FILE" kit_version "$KIT_VERSION"
        fi
    else
        echo "$CONFIG_FILE already exists — skipping creation"
    fi
else
    echo "Creating $CONFIG_FILE"
    if $DRY_RUN; then
        echo "[dry-run] write $CONFIG_FILE"
    else
        cat > "$CONFIG_FILE" <<EOF
# Strata configuration (legacy filename retained for compatibility)
# See the Strata README for available keys

dir=$EPS_DIR
prefix=ep
validator=$VALIDATOR_PATH
kit_version=$KIT_VERSION
EOF
    fi
fi

echo ""
echo "Done. Next steps:"
echo "  1. Edit $EPS_DIR/0001-ep-purpose-and-guidelines.md with your project name"
echo "  2. Edit $CONFIG_FILE if you need a custom prefix (e.g. prefix=rfc)"
echo "  3. Open a PR with the new EP directory"
if $INSTALL_SKILLS; then
    echo "  4. Tell your AI assistant: 'new EP for X'"
fi
