## Quick Reference Cheat Sheet

### Networking
```bash
# Check connectivity
ping <host>
curl -v http://<url>

# DNS lookup
nslookup <domain>
dig <domain>

# Port scanning
nc -zv <host> <port>

# Network stats
netstat -tuln
ss -tuln
```

### YAML
```yaml
# Basic structure
key: value
list:
  - item1
  - item2
nested:
  key: value
```

### Cloud
```bash
# AWS CLI examples
aws s3 ls
aws ec2 describe-instances
aws eks update-kubeconfig --name cluster-name

# Azure CLI
az login
az aks get-credentials --resource-group myRG --name myAKS

# GCP
gcloud container clusters get-credentials cluster-name
```

### Git
```bash
# Daily commands
git status
git add .
git commit -m "message"
git push
git pull

# Branch operations
git checkout -b feature
git merge feature
git branch -d feature
```

---

## Additional Resources

### Online Tools
- **YAML Validators**: yamllint.com, onlineyamltools.com
- **Network Tools**: ping.eu, mxtoolbox.com
- **Git Learning**: learngitbranching.js.org
- **Cloud Sandboxes**: AWS Free Tier, Azure Free Account, GCP Free Tier

### Documentation
- Kubernetes Networking: kubernetes.io/docs/concepts/cluster-administration/networking/
- YAML Specification: yaml.org
- Git Documentation: git-scm.com/doc
- Cloud Provider Docs: AWS, Azure, GCP documentation sites

### Practice Platforms
- Katacoda (Kubernetes scenarios)
- Play with Kubernetes
- GitHub Learning Lab
- Cloud provider free tiers

---
