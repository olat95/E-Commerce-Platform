# ===== ADMIN SERVICE - OPTIMIZED =====
# services/admin-service/Dockerfile

FROM node:18-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev && \
  npm cache clean --force

FROM node:18-alpine AS production
LABEL maintainer="devops@example.com"
LABEL version="1.0.0"
LABEL description="Admin Service - Microservices Platform"

RUN apk add --no-cache dumb-init
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY --chown=node:node . .
USER node
EXPOSE 8007

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8007/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]