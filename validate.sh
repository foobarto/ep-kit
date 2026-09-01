#!/usr/bin/env bash
# Repository entry point for the validator bundled with Strata's ep-kit skill.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/skills/ep-kit/validate.sh" "$@"
