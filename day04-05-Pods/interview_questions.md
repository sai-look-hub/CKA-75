## 🎓 Interview Questions

### Q1: What is a Pod?
**Answer:** The smallest deployable unit in Kubernetes. A pod encapsulates one or more containers, storage resources, network IP, and configuration about how to run the containers.

### Q2: Why would you use multiple containers in one pod?
**Answer:** When containers are tightly coupled and need to share resources:
- Sidecar pattern (logging, monitoring)
- Ambassador pattern (proxy)
- Adapter pattern (normalize output)
- They share network (localhost), storage (volumes), and lifecycle

### Q3: What's the difference between liveness and readiness probes?
**Answer:**
- **Liveness**: Checks if container is alive. If fails → restart
- **Readiness**: Checks if container can serve traffic. If fails → remove from service endpoints

### Q4: What are init containers?
**Answer:** Special containers that run before app containers. They run to completion sequentially. Used for setup tasks like waiting for dependencies, configuration generation, or database migrations.

### Q5: Can pods have multiple containers with same image?
**Answer:** Yes! You can have multiple containers with the same image doing different things (different commands/args).

---
