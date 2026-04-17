#!/usr/bin/env bash
# EP Kit installer — scaffolds docs/eps/ in your project with templates.
#
# Usage:
#   ./install.sh                  # uses default docs/eps/ directory
#   ./install.sh docs/rfcs/       # custom directory
#   ./install.sh --skill-dir .claude/skills/  # also copy SKILL.md
#
# Options:
#   --skill-dir <path>   Copy SKILL.md to this directory (optional)
#   --dry-run            Print what would be done without doing it
#   --help               Show this help

set -euo pipefail

# Defaults
EPS_DIR="docs/eps"
SKILL_DIR=""
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
        --skill-dir)
            SKILL_DIR="$2"
            shift 2
            ;;
        --skill-dir=*)
            SKILL_DIR="${1#--skill-dir=}"
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            # First positional arg is the EP directory
            if [[ "$EPS_DIR" == "docs/eps" ]]; then
                EPS_DIR="$1"
            else
                echo "Error: multiple positional arguments. Use --skill-dir for the skill target." >&2
                exit 1
            fi
            shift
            ;;
    esac
done

run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

echo "EP Kit installer"
echo "================"
echo ""
echo "EP directory:  $EPS_DIR"
if [[ -n "$SKILL_DIR" ]]; then
    echo "Skill directory: $SKILL_DIR"
fi
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

# Copy skills if requested
if [[ -n "$SKILL_DIR" ]]; then
    if [[ ! -d "$SKILL_DIR" ]]; then
        echo "Creating $SKILL_DIR/"
        run mkdir -p "$SKILL_DIR"
    fi

    # Main creation skill
    if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
        echo "$SKILL_DIR/SKILL.md already exists — skipping"
    else
        echo "Copying SKILL.md → $SKILL_DIR/SKILL.md"
        run cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
    fi

    # Validation review skill
    if [[ -f "$SKILL_DIR/SKILL-VALIDATE.md" ]]; then
        echo "$SKILL_DIR/SKILL-VALIDATE.md already exists — skipping"
    else
        echo "Copying SKILL-VALIDATE.md → $SKILL_DIR/SKILL-VALIDATE.md"
        run cp "$SCRIPT_DIR/SKILL-VALIDATE.md" "$SKILL_DIR/SKILL-VALIDATE.md"
    fi

    # Review checklist
    if [[ -f "$SKILL_DIR/CHECKLIST.md" ]]; then
        echo "$SKILL_DIR/CHECKLIST.md already exists — skipping"
    else
        echo "Copying CHECKLIST.md → $SKILL_DIR/CHECKLIST.md"
        run cp "$SCRIPT_DIR/CHECKLIST.md" "$SKILL_DIR/CHECKLIST.md"
    fi
fi

# Create .ep-kit config if it doesn't exist
CONFIG_FILE=".ep-kit"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "$CONFIG_FILE already exists — skipping creation"
else
    echo "Creating $CONFIG_FILE"
    if $DRY_RUN; then
        echo "[dry-run] write $CONFIG_FILE"
    else
        cat > "$CONFIG_FILE" <<EOF
# EP Kit configuration
# See ep-kit/README.md for available keys

dir=$EPS_DIR
prefix=ep
validator=$SCRIPT_DIR/validate.sh
kit_version=0.1.0
EOF
    fi
fi

echo ""
echo "Done. Next steps:"
echo "  1. Edit $EPS_DIR/0001-ep-purpose-and-guidelines.md with your project name"
echo "  2. Edit $CONFIG_FILE if you need a custom prefix (e.g. prefix=rfc)"
echo "  3. Open a PR with the new EP directory"
if [[ -n "$SKILL_DIR" ]]; then
    echo "  4. Tell your AI assistant: 'new EP for X'"
fi
