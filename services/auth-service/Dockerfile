# ===== AUTH SERVICE - OPTIMIZED =====
# services/auth-service/Dockerfile
# Multi-stage build for production-optimized image
# Base image size: node:18 (980MB) → node:18-alpine (180MB)
# Expected final size: <150MB

# Stage 1: Dependencies
FROM node:18-alpine AS dependencies
WORKDIR /app

# Copy only package files for better caching
COPY package*.json ./

# Install only production dependencies
# --omit=dev excludes devDependencies
# clean cache to reduce image size
RUN npm install --omit=dev && \
  npm cache clean --force

# Stage 2: Production
FROM node:18-alpine AS production

# Add metadata labels
LABEL maintainer="JP"
LABEL version="1.0.0"
LABEL description="Auth Service - Microservices Platform"

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory with proper permissions
WORKDIR /app

# Copy dependencies from previous stage
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application code
COPY --chown=node:node . .

# Use non-root user for security
USER node

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "src/server.js"]