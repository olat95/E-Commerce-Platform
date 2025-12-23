# Versioning Strategy

## Current Version
v1.0.0

## Tagging Format

### Primary Tag (Immutable)
```
<service>:v<MAJOR>.<MINOR>.<PATCH>-<git-sha>
Example: auth-service:v1.0.0-a3f9c82
```

**Purpose:** Exact version identification with traceability to source code

### Version Tag (Immutable)
```
<service>:v<MAJOR>.<MINOR>.<PATCH>
Example: auth-service:v1.0.0
```

**Purpose:** Human-readable version reference

### Environment Tag (Mutable)
```
<service>:<environment>
Example: auth-service:production
```

**Purpose:** Current deployment identifier

### Latest Tag (Mutable)
```
<service>:latest
Example: auth-service:latest
```

**Purpose:** Development convenience (NOT used in production)

---

## Semantic Versioning Rules

### MAJOR (x.0.0)
Increment when making incompatible API changes:
- Breaking changes to endpoints
- Removed features
- Changed authentication method
- Database schema breaking changes

**Example:** v1.0.0 → v2.0.0

### MINOR (1.x.0)
Increment when adding functionality in a backwards-compatible manner:
- New endpoints
- New features
- Enhanced functionality
- Performance improvements

**Example:** v1.0.0 → v1.1.0

### PATCH (1.0.x)
Increment when making backwards-compatible bug fixes:
- Bug fixes
- Security patches
- Documentation updates
- Minor improvements

**Example:** v1.0.0 → v1.0.1

---

## Version Bump Process

### 1. Decide Version Type
```bash
# For patch (bug fix)
./scripts/version-bump.sh patch

# For minor (new feature)
./scripts/version-bump.sh minor

# For major (breaking change)
./scripts/version-bump.sh major
```

### 2. Update CHANGELOG.md
Edit CHANGELOG.md to document changes

### 3. Build Images
```bash
./scripts/build-optimized.sh
```

### 4. Security Scan
```bash
./scripts/scan-images.sh
```

### 5. Tag Images
```bash
VERSION=$(cat VERSION)
./scripts/tag-images.sh $VERSION production
```

### 6. Commit and Tag
```bash
git add VERSION CHANGELOG.md
git commit -m "Bump version to v${VERSION}"
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin main --tags
```

### 7. Push to Registry
```bash
./scripts/push-to-registry.sh v${VERSION}
```

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| v1.0.0 | 2025-12-03 | Initial production release |

---

## Emergency Rollback

If issues arise in production:
```bash
# Find previous version
git tag -l

# Retag for production
./scripts/retag-for-environment.sh v1.0.0-a3f9c82 production

# Deploy previous version
kubectl set image deployment/auth auth=auth-service:production
```

---

## Tag Management

### View All Tags
```bash
./scripts/list-tags.sh
```

### View Specific Service
```bash
docker images auth-service
```

### Remove Old Tags (Cleanup)
```bash
# Remove specific tag
docker rmi auth-service:old-tag

# Prune unused images
docker image prune -a
```

---

## Best Practices

✅ **DO:**
- Always use version tags in production
- Include git SHA for traceability
- Update CHANGELOG with every version
- Test before tagging
- Keep tags immutable (except environment tags)

❌ **DON'T:**
- Use `latest` in production
- Reuse version numbers
- Skip CHANGELOG updates
- Tag without testing
- Delete version tags

---

## CI/CD Integration

Tagging will be automated in Phase 2B-2D:
```yaml
# GitHub Actions example
on:
  push:
    tags:
      - 'v*'

jobs:
  tag-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Extract version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV
      
      - name: Tag images
        run: ./scripts/tag-images.sh $VERSION production
      
      - name: Push to registry
        run: ./scripts/push-to-registry.sh v$VERSION
```

---

**Last Updated:** December 3, 2025  
**Maintained by:** DevOps Team
