# Container Registry - Docker Hub

## Registry Information

**Registry:** Docker Hub  
**Namespace:** yourusername  
**URL:** https://hub.docker.com/r/yourusername

## Repositories

All 8 microservices are published:

1. auth-service
2. user-service
3. billing-service	
4. payment-service
5. notification-service
6. analytics-service
7. admin-service
8. frontend

## Image Naming Convention
docker.io/yourusername/<service>:<tag>
Examples
1. olat95/auth-service:v1.0.0-a3f9c82
2. olat95/auth-service:v1.0.0
3. olat95/auth-service:production
4. olat95/auth-service:latest

## Pulling Images
```bash
# Pull specific version
docker pull yourusername/auth-service:v1.0.0

# Pull production version
docker pull yourusername/auth-service:production

# Pull latest
docker pull yourusername/auth-service:latest
```

## Pushing New Versions
```bash
# 1. Build and tag locally
./scripts/build-optimized.sh
./scripts/tag-images.sh 1.0.1 production

# 2. Push to registry
./scripts/push-to-registry.sh dockerhub yourusername

# 3. Verify on Docker Hub
https://hub.docker.com/r/yourusername
```

## Automated Push (CI/CD)

In CI/CD pipelines, use:
```yaml
- name: Push to Docker Hub
  run: |
    echo ${{ secrets.DOCKER_HUB_TOKEN }} | docker login -u ${{ secrets.DOCKER_HUB_USERNAME }} --password-stdin
    ./scripts/push-to-registry.sh dockerhub ${{ secrets.DOCKER_HUB_USERNAME }}
```

## Access Control

- **Public:** All images are public (free tier)
- **Private:** Upgrade to Pro for private repositories
- **Team Access:** Available in Team/Business tiers

## Retention Policy

Current strategy:
- Keep all semantic versions (v1.0.0, v1.0.1, etc.)
- Keep all environment tags (production, staging)
- Keep latest tag
- Manual cleanup of old development builds

## Security

- ✅ Access token authentication (not password)
- ✅ Token rotated every 90 days
- ✅ 2FA enabled on account
- ✅ All images scanned with Trivy (zero vulnerabilities)

## Monitoring

Track metrics:
- Pull count (usage indicator)
- Push frequency (deployment frequency)
- Image size (optimization tracking)

View at: https://hub.docker.com/r/yourusername

## Troubleshooting

### Can't push
```bash
# Check authentication
docker info | grep Username

# Re-login if needed
docker login
```

### Image not found
```bash
# Verify image exists locally
docker images yourusername/auth-service

# Check tag spelling
docker images | grep auth-service
```

### Push timeout
```bash
# Check internet connection
# Retry push (will resume from where it stopped)
./scripts/push-to-registry.sh dockerhub yourusername
```

---

**Last Updated:** December 3, 2025  
**Maintained by:** DevOps Team
