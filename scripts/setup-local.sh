#!/bin/bash
# scripts/setup-project.sh - Initialize the entire project structure

set -e

echo "🚀 Setting up Microservices K8s Project..."

# Create main directory structure
mkdir -p microservices-k8s-project/{services,kubernetes,helm,scripts,docs}
cd microservices-k8s-project

# Create service directories
SERVICES=("auth-service" "user-service" "billing-service" "payment-service" "notification-service" "analytics-service" "admin-service" "frontend")

for service in "${SERVICES[@]}"; do
  echo "📁 Creating $service..."
  mkdir -p services/$service/src
  
  # Create package.json for each service
  cat > services/$service/package.json <<EOF
{
  "name": "$service",
  "version": "1.0.0",
  "description": "$service for microservices platform",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.2",
    "winston": "^3.11.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0"
  }
}
EOF

  # Add service-specific dependencies
  if [[ "$service" == "auth-service" ]]; then
    npm install --prefix services/$service pg bcryptjs jsonwebtoken
  elif [[ "$service" == "user-service" ]] || [[ "$service" == "billing-service" ]] || [[ "$service" == "payment-service" ]] || [[ "$service" == "analytics-service" ]]; then
    npm install --prefix services/$service pg
  fi

  # Create Dockerfile
  cat > services/$service/Dockerfile <<EOF
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 8001
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD wget --quiet --tries=1 --spider http://localhost:8001/health || exit 1
USER node
CMD ["node", "src/server.js"]
EOF

  # Create .dockerignore
  cat > services/$service/.dockerignore <<EOF
node_modules
npm-debug.log
.env
.git
.gitignore
README.md
.DS_Store
*.md
EOF

done

# Create root .gitignore
cat > .gitignore <<EOF
# Dependencies
node_modules/
package-lock.json

# Environment variables
.env
.env.local
.env.*.local

# Logs
logs/
*.log
npm-debug.log*

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Build outputs
dist/
build/
*.tgz

# Kubernetes secrets
kubernetes/secrets/*.yaml
!kubernetes/secrets/.gitkeep

# Helm
helm/*/charts/
*.tgz
EOF

# Create README.md
cat > README.md <<EOF
# Microservices on Kubernetes - Production-Ready Platform

## 🏗️ Architecture

This project demonstrates a complete microservices architecture deployed on Kubernetes (EKS/AKS) with 8 independent services:

1. **Auth Service** - JWT-based authentication
2. **User Service** - User profile management
3. **Billing Service** - Invoice management
4. **Payment Service** - Payment processing
5. **Notification Service** - Email/SMS notifications
6. **Analytics Service** - Event tracking
7. **Admin Service** - Admin dashboard backend
8. **Frontend** - React-based UI

## 🚀 Quick Start (Local Development)

### Prerequisites
- Docker & Docker Compose
- Node.js 18+
- PostgreSQL (or use Docker containers)

### Run Locally
\`\`\`bash
# Start all services
docker-compose up --build

# Test the services
curl http://localhost:8001/health  # Auth Service
curl http://localhost:8002/health  # User Service
# ... test other services
\`\`\`

### Register a User
\`\`\`bash
curl -X POST http://localhost:8001/api/auth/register \\
  -H "Content-Type: application/json" \\
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "role": "user"
  }'
\`\`\`

## 📦 Project Structure

\`\`\`
microservices-k8s-project/
├── services/           # All microservices
├── kubernetes/         # K8s manifests
├── helm/              # Helm charts
├── scripts/           # Automation scripts
├── docs/              # Documentation
└── docker-compose.yml # Local development
\`\`\`

## 🔧 Technology Stack

- **Backend**: Node.js + Express
- **Database**: PostgreSQL
- **Authentication**: JWT
- **Container**: Docker
- **Orchestration**: Kubernetes (EKS/AKS)
- **Package Manager**: Helm
- **Monitoring**: Prometheus + Grafana
- **Service Mesh**: Linkerd (optional)

## 📚 Next Steps

1. Test all services locally with Docker Compose
2. Set up AWS EKS or Azure AKS cluster
3. Create Helm charts for deployment
4. Configure HPA, Ingress, and Secrets
5. Set up Prometheus & Grafana monitoring
6. Implement service mesh (Linkerd/Istio)

## 📝 License

MIT
EOF

echo "✅ Project structure created successfully!"
echo ""
echo "📁 Directory: $(pwd)"
echo ""
echo "Next steps:"
echo "1. cd microservices-k8s-project"
echo "2. Copy the service code into services/*/src/server.js"
echo "3. Run: docker-compose up --build"
echo "4. Test the APIs!"