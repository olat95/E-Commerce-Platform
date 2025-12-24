# scripts/cleanup-registry.sh
#!/bin/bash
# Purpose: Clean up old tags from registry (manual process for Docker Hub free)
# Usage: ./scripts/cleanup-registry.sh

echo "Registry Cleanup Guide"
echo "====================="
echo ""
echo "For Docker Hub (free tier):"
echo "1. Go to https://hub.docker.com/"
echo "2. Navigate to repository"
echo "3. Click 'Tags' tab"
echo "4. Select old tags"
echo "5. Click 'Delete'"
echo ""
echo "Tags to keep:"
echo "  - production"
echo "  - staging"
echo "  - Latest 5 semantic versions"
echo ""
echo "Tags to delete:"
echo "  - Old development builds"
echo "  - Superseded patch versions"
echo "  - Untagged images"