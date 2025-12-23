# ===== GET VERSION SCRIPT =====
# scripts/get-version.sh
#!/bin/bash
# Purpose: Retrieve current version
# Usage: ./scripts/get-version.sh [--full|--major|--minor|--patch]

set -e

VERSION_FILE="VERSION"
FORMAT=${1:-full}

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: VERSION file not found" >&2
    exit 1
fi

VERSION=$(cat "$VERSION_FILE")

if [[ $VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    
    case $FORMAT in
        --full)
            echo "$VERSION"
            ;;
        --major)
            echo "$MAJOR"
            ;;
        --minor)
            echo "$MINOR"
            ;;
        --patch)
            echo "$PATCH"
            ;;
        --with-v)
            echo "v$VERSION"
            ;;
        --with-sha)
            GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            echo "v${VERSION}-${GIT_SHA}"
            ;;
        *)
            echo "$VERSION"
            ;;
    esac
else
    echo "Error: Invalid version format" >&2
    exit 1
fi