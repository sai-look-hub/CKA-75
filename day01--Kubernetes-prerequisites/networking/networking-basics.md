## Networking Fundamentals

### 1. IP Addressing

**IPv4 Address Structure**
- 32-bit address divided into 4 octets (e.g., 192.168.1.10)
- Classes: A, B, C, D, E
- Private IP ranges:
  - Class A: 10.0.0.0 to 10.255.255.255
  - Class B: 172.16.0.0 to 172.31.255.255
  - Class C: 192.168.0.0 to 192.168.255.255

**CIDR Notation**
```
192.168.1.0/24
- /24 means first 24 bits are network portion
- Last 8 bits are for hosts (256 addresses)
- Usable hosts: 254 (excluding network and broadcast)
```

**Subnetting Example**
```
Network: 10.0.0.0/16
Subnet 1: 10.0.1.0/24 (256 IPs)
Subnet 2: 10.0.2.0/24 (256 IPs)
```

### 2. DNS (Domain Name System)

**DNS Resolution Process**
1. Client queries local DNS cache
2. Queries recursive DNS server
3. Root server → TLD server → Authoritative server
4. Returns IP address

**DNS Record Types**
- **A Record**: Maps domain to IPv4 address
- **AAAA Record**: Maps domain to IPv6 address
- **CNAME**: Canonical name (alias)
- **MX**: Mail exchange server
- **TXT**: Text records (verification, SPF)
- **SRV**: Service records

**Kubernetes DNS**
```bash
# Service DNS format
<service-name>.<namespace>.svc.cluster.local

# Example
mysql.database.svc.cluster.local
```

### 3. Ports and Protocols

**Common Ports**
```
HTTP:     80
HTTPS:    443
SSH:      22
FTP:      21
DNS:      53
SMTP:     25
MySQL:    3306
PostgreSQL: 5432
MongoDB:  27017
Redis:    6379

Kubernetes Specific:
API Server:    6443
etcd:          2379-2380
Kubelet:       10250
NodePort:      30000-32767
```

**TCP vs UDP**
- **TCP**: Connection-oriented, reliable, ordered delivery (HTTP, SSH)
- **UDP**: Connectionless, faster, no guaranteed delivery (DNS, streaming)

### 4. Network Layers (OSI Model)

```
Layer 7: Application  (HTTP, FTP, DNS)
Layer 6: Presentation (SSL/TLS, encryption)
Layer 5: Session      (session management)
Layer 4: Transport    (TCP, UDP)
Layer 3: Network      (IP, routing)
Layer 2: Data Link    (MAC addresses, switches)
Layer 1: Physical     (cables, signals)
```

### 5. Load Balancing

**Types of Load Balancers**
- **Layer 4 (Transport)**: Routes based on IP/Port
- **Layer 7 (Application)**: Routes based on content (HTTP headers, URLs)

**Load Balancing Algorithms**
- Round Robin
- Least Connections
- IP Hash
- Weighted Round Robin

**Example: Kubernetes Service**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

### 6. Network Address Translation (NAT)

**NAT Types**
- **SNAT**: Source NAT (outbound traffic)
- **DNAT**: Destination NAT (inbound traffic, port forwarding)
- **PAT**: Port Address Translation (multiple internal IPs to one external)

### 7. Firewalls and Security Groups

**Firewall Rules**
```bash
# Allow incoming HTTP
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow incoming HTTPS
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Block specific IP
iptables -A INPUT -s 192.168.1.100 -j DROP
```

### 8. Proxy Servers

**Forward Proxy**: Client → Proxy → Internet
**Reverse Proxy**: Internet → Proxy → Backend Servers

**Nginx Reverse Proxy Example**
```nginx
upstream backend {
    server backend1.example.com;
    server backend2.example.com;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

### 9. Network Troubleshooting Commands

```bash
# Check connectivity
ping google.com

# Trace route
traceroute google.com

# DNS lookup
nslookup google.com
dig google.com

# Network statistics
netstat -tuln

# Active connections
ss -tuln

# Check open ports
nc -zv hostname 80

# Network interfaces
ip addr show
ifconfig

# Routing table
ip route show
route -n

# Test HTTP endpoint
curl -v http://example.com

# Monitor network traffic
tcpdump -i eth0 port 80
```

### 10. Kubernetes Networking Concepts

**CNI (Container Network Interface)**
- Flannel
- Calico
- Weave Net
- Cilium

**Network Policies Example**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Service Types**
- **ClusterIP**: Internal cluster communication
- **NodePort**: Exposes on each node's IP
- **LoadBalancer**: Cloud provider load balancer
- **ExternalName**: Maps to external DNS

---
