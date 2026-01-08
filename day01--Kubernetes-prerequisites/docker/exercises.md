# 🐳 Docker & Containerization

## Why Docker Matters for Kubernetes

**Kubernetes orchestrates containers.** If you don't understand containers, you can't effectively use Kubernetes. Docker is the most popular container runtime, and understanding it deeply will make Kubernetes concepts much clearer.

**Think of it this way:**
- Docker = Learning to drive a car
- Kubernetes = Learning to manage a fleet of cars

---

## 📚 Container Concepts

### What is a Container?

A container is a lightweight, standalone package that includes:
- Your application code
- Runtime environment
- System tools
- Libraries
- Dependencies

**Containers vs VMs:**
```
Virtual Machines:              Containers:
┌─────────────────┐           ┌─────────────────┐
│   Application   │           │   Application   │
│   ───────────   │           │   ───────────   │
│     Runtime     │           │     Runtime     │
│   ───────────   │           │   ───────────   │
│  Guest OS (GB)  │           │  (Shared Kernel)│
│   ───────────   │           └─────────────────┘
│   Hypervisor    │           ┌─────────────────┐
│   ───────────   │           │  Container Eng. │
│    Host OS      │           │   ───────────   │
│   ───────────   │           │    Host OS      │
│   Hardware      │           │   ───────────   │
└─────────────────┘           │   Hardware      │
                              └─────────────────┘
```

**Key Differences:**
- Containers share the host OS kernel (lighter, faster)
- VMs include full OS (heavier, slower)
- Containers start in seconds, VMs in minutes
- Containers use less resources

---

## 🚀 Essential Docker Commands

### Installation Check

```bash
# Check if Docker is installed
docker --version

# Check Docker info
docker info

# Test Docker installation
docker run hello-world
```

---

### Working with Images

```bash
# Search for images
docker search nginx

# Pull an image
docker pull nginx
docker pull nginx:1.21  # Specific version

# List downloaded images
docker images
docker image ls

# Remove an image
docker rmi nginx
docker rmi nginx:1.21

# View image history (layers)
docker history nginx

# Inspect image
docker inspect nginx

# Tag an image
docker tag nginx:latest myapp:v1

# Remove unused images
docker image prune
docker image prune -a  # Remove all unused images
```

---

### Running Containers

```bash
# Run a container (basic)
docker run nginx

# Run in detached mode (background)
docker run -d nginx

# Run with a name
docker run -d --name my-nginx nginx

# Run with port mapping
docker run -d -p 8080:80 --name web nginx
# Host port:Container port

# Run with environment variables
docker run -d -e "ENV=production" -e "DEBUG=false" nginx

# Run with volume mount
docker run -d -v /host/path:/container/path nginx
docker run -d -v my-volume:/data nginx

# Run with resource limits
docker run -d --memory="512m" --cpus="1.0" nginx

# Run with automatic restart
docker run -d --restart=always nginx
# Options: no, on-failure, always, unless-stopped

# Run interactively
docker run -it ubuntu /bin/bash
# -i = interactive, -t = TTY

# Run and remove after exit
docker run --rm ubuntu echo "Hello"
```

---

### Managing Containers

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Stop a container
docker stop my-nginx
docker stop CONTAINER_ID

# Start a stopped container
docker start my-nginx

# Restart a container
docker restart my-nginx

# Pause a container
docker pause my-nginx
docker unpause my-nginx

# Remove a container
docker rm my-nginx

# Force remove running container
docker rm -f my-nginx

# Remove all stopped containers
docker container prune

# Stop all running containers
docker stop $(docker ps -q)

# Remove all containers
docker rm -f $(docker ps -aq)
```

---

### Container Logs and Inspection

```bash
# View container logs
docker logs my-nginx

# Follow logs (real-time)
docker logs -f my-nginx

# Show last 100 lines
docker logs --tail 100 my-nginx

# Show logs with timestamps
docker logs -t my-nginx

# Inspect container details
docker inspect my-nginx

# View container processes
docker top my-nginx

# View container stats (CPU, memory, etc.)
docker stats
docker stats my-nginx

# View port mappings
docker port my-nginx
```

---

### Executing Commands in Containers

```bash
# Execute command in running container
docker exec my-nginx ls /etc

# Interactive shell
docker exec -it my-nginx /bin/bash
docker exec -it my-nginx sh  # If bash not available

# Run as specific user
docker exec -u root -it my-nginx bash

# Execute with environment variable
docker exec -e "VAR=value" my-nginx env
```

---

### Copying Files

```bash
# Copy from container to host
docker cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf

# Copy from host to container
docker cp ./config.yaml my-nginx:/etc/app/config.yaml
```

---

## 📝 Writing Dockerfiles

### Dockerfile Basics

```dockerfile
# Simple Node.js application
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Define startup command
CMD ["node", "index.js"]
```

### Dockerfile Best Practices

```dockerfile
# Multi-stage build (reduces image size)
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:18-alpine
WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

### Common Dockerfile Instructions

```dockerfile
# FROM - Base image
FROM ubuntu:22.04
FROM node:18-alpine
FROM python:3.11-slim

# WORKDIR - Set working directory
WORKDIR /app

# COPY - Copy files from host to container
COPY file.txt /app/
COPY . /app

# ADD - Copy and extract (avoid unless needed)
ADD archive.tar.gz /app/

# RUN - Execute commands during build
RUN apt-get update && apt-get install -y nginx
RUN npm install
RUN pip install -r requirements.txt

# ENV - Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# EXPOSE - Document which port container listens on
EXPOSE 8080

# CMD - Default command (can be overridden)
CMD ["nginx", "-g", "daemon off;"]
CMD ["node", "server.js"]

# ENTRYPOINT - Command that always runs
ENTRYPOINT ["python", "app.py"]

# VOLUME - Create mount point
VOLUME /data

# ARG - Build-time variables
ARG VERSION=1.0
RUN echo "Building version ${VERSION}"

# LABEL - Add metadata
LABEL maintainer="your-email@example.com"
LABEL version="1.0"
```

---

### Building Images

```bash
# Build from Dockerfile
docker build -t myapp:v1 .

# Build with specific Dockerfile
docker build -f Dockerfile.prod -t myapp:prod .

# Build with build arguments
docker build --build-arg VERSION=2.0 -t myapp:v2 .

# Build without cache
docker build --no-cache -t myapp:v1 .

# Build and tag multiple names
docker build -t myapp:v1 -t myapp:latest .
```

---

## 🌐 Docker Networking

```bash
# List networks
docker network ls

# Create a network
docker network create my-network

# Inspect network
docker network inspect my-network

# Run container on specific network
docker run -d --name web --network my-network nginx

# Connect running container to network
docker network connect my-network my-container

# Disconnect from network
docker network disconnect my-network my-container

# Remove network
docker network rm my-network

# Default network types:
# - bridge: Default, isolated network
# - host: Use host network directly
# - none: No networking
```

### Network Example

```bash
# Create network
docker network create app-network

# Run database
docker run -d \
  --name db \
  --network app-network \
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Run application (can reach db by name "db")
docker run -d \
  --name app \
  --network app-network \
  -p 8080:8080 \
  -e DATABASE_URL=postgresql://db:5432/mydb \
  myapp:v1
```

---

## 💾 Docker Volumes

### Volume Types

```bash
# Named volumes (managed by Docker)
docker volume create my-data
docker run -d -v my-data:/data nginx

# Bind mounts (host directory)
docker run -d -v /host/path:/container/path nginx
docker run -d -v $(pwd):/app nginx  # Current directory

# Anonymous volumes
docker run -d -v /data nginx
```

### Volume Commands

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect my-data

# Remove volume
docker volume rm my-data

# Remove all unused volumes
docker volume prune

# Create volume
docker volume create --name my-data
```

### Volume Example

```bash
# Create volume
docker volume create postgres-data

# Run PostgreSQL with persistent data
docker run -d \
  --name postgres \
  -v postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Data persists even if container is removed
docker rm -f postgres
docker run -d \
  --name postgres-new \
  -v postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:15
# Data is still there!
```

---

## 🔄 Docker Compose (Bonus)

Managing multiple containers easily:

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - api

  api:
    build: ./api
    environment:
      - DATABASE_URL=postgresql://db:5432/mydb
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=secret
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Remove volumes too
docker-compose down -v
```

---

## 🎯 Practice Exercises

### Exercise 1: Run Your First Container

```bash
# Pull and run nginx
docker run -d -p 8080:80 --name my-web nginx

# Check it's running
docker ps

# View logs
docker logs my-web

# Test in browser
curl http://localhost:8080

# Stop and remove
docker stop my-web
docker rm my-web
```

### Exercise 2: Build Custom Image

```dockerfile
# Create Dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```bash
# Create index.html
echo "<h1>Hello from Docker!</h1>" > index.html

# Build image
docker build -t my-nginx:v1 .

# Run container
docker run -d -p 8080:80 my-nginx:v1

# Test
curl http://localhost:8080
```

### Exercise 3: Multi-Container Application

```bash
# Create network
docker network create app-net

# Run Redis
docker run -d --name redis --network app-net redis:7-alpine

# Run application that uses Redis
docker run -d \
  --name app \
  --network app-net \
  -p 5000:5000 \
  -e REDIS_HOST=redis \
  your-app:v1
```

---

## 🧹 Docker Cleanup

```bash
# Remove all stopped containers
docker container prune

# Remove all unused images
docker image prune -a

# Remove all unused volumes
docker volume prune

# Remove all unused networks
docker network prune

# Clean everything (CAREFUL!)
docker system prune -a --volumes

# Check disk usage
docker system df
```

---

## ✅ Checklist

- [ ] Understand containers vs VMs
- [ ] Can pull and run images
- [ ] Know basic Docker commands
- [ ] Can write simple Dockerfiles
- [ ] Understand multi-stage builds
- [ ] Know Docker networking basics
- [ ] Understand Docker volumes
- [ ] Can build custom images
- [ ] Practiced all commands above

---

**Previous:** [← Linux Fundamentals](./01-linux-fundamentals.md)  
**Next:** [Networking Basics →](./03-networking-basics.md)

---

*Progress: 2/6 Prerequisites Complete* 🎯