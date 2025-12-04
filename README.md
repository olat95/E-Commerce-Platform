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
```bash
# Start all services
docker-compose up --build

# Test the services
curl http://localhost:8001/health  # Auth Service
curl http://localhost:8002/health  # User Service
# ... test other services
```

### Register a User
```bash
curl -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "role": "user"
  }'
```

## 📦 Project Structure

```
microservices-k8s-project/
├── services/           # All microservices
├── kubernetes/         # K8s manifests
├── helm/              # Helm charts
├── scripts/           # Automation scripts
├── docs/              # Documentation
└── docker-compose.yml # Local development
```

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
