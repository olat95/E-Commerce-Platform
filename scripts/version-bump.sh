# ===== VERSION BUMP SCRIPT =====
# scripts/version-bump.sh
#!/bin/bash
# Purpose: Increment version numbers using semantic versioning
# Usage: ./scripts/version-bump.sh [major|minor|patch]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

BUMP_TYPE=${1:-patch}
VERSION_FILE="VERSION"

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo -e "${RED}Error: Invalid bump type. Use: major, minor, or patch${NC}"
    exit 1
fi

# Read current version
if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${RED}Error: VERSION file not found${NC}"
    echo "Creating VERSION file with initial version 1.0.0"
    echo "1.0.0" > "$VERSION_FILE"
    exit 0
fi

CURRENT_VERSION=$(cat "$VERSION_FILE")

# Parse version
if [[ $CURRENT_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
else
    echo -e "${RED}Error: Invalid version format in VERSION file: $CURRENT_VERSION${NC}"
    exit 1
fi

# Calculate new version
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo -e "${BLUE}Version Bump - ${BUMP_TYPE}${NC}"
echo -e "Current version: ${YELLOW}v${CURRENT_VERSION}${NC}"
echo -e "New version: ${GREEN}v${NEW_VERSION}${NC}"
echo ""

# Confirm
read -p "Proceed with version bump? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Version bump cancelled."
    exit 0
fi

# Update VERSION file
echo "$NEW_VERSION" > "$VERSION_FILE"
echo -e "${GREEN}✓ VERSION file updated${NC}"

# Update CHANGELOG.md
if [ -f "CHANGELOG.md" ]; then
    # Prepare changelog entry
    DATE=$(date +%Y-%m-%d)
    TEMP_FILE=$(mktemp)
    
    # Add new version header
    {
        echo "# Changelog"
        echo ""
        echo "## [${NEW_VERSION}] - ${DATE}"
        echo ""
        echo "### Added"
        echo "- "
        echo ""
        echo "### Changed"
        echo "- "
        echo ""
        echo "### Fixed"
        echo "- "
        echo ""
        tail -n +2 CHANGELOG.md
    } > "$TEMP_FILE"
    
    mv "$TEMP_FILE" CHANGELOG.md
    echo -e "${GREEN}✓ CHANGELOG.md updated${NC}"
    echo -e "${YELLOW}⚠ Please edit CHANGELOG.md to add release notes${NC}"
else
    # Create CHANGELOG.md
    cat > CHANGELOG.md << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [${NEW_VERSION}] - $(date +%Y-%m-%d)

### Added
- Initial release

### Changed
- 

### Fixed
- 
EOF
    echo -e "${GREEN}✓ CHANGELOG.md created${NC}"
fi

echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Edit CHANGELOG.md to document changes"
echo "  2. Build images: ./scripts/build-optimized.sh"
echo "  3. Tag images: ./scripts/tag-images.sh ${NEW_VERSION}"
echo "  4. Commit: git add VERSION CHANGELOG.md && git commit -m 'Bump version to v${NEW_VERSION}'"
echo "  5. Git tag: git tag -a v${NEW_VERSION} -m 'Release v${NEW_VERSION}'"
echo ""