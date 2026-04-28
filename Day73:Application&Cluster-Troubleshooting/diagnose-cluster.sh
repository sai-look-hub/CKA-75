#!/usr/bin/env bash
# =============================================================================
# diagnose-cluster.sh — Day 73: Full Kubernetes Cluster Health Check
# Usage: ./scripts/diagnose-cluster.sh [namespace]
# =============================================================================

set -euo pipefail

NS="${1:-default}"
RED='\033[0;31m'
YLW='\033[1;33m'
GRN='\033[0;32m'
BLU='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GRN}[✔]${NC} $*"; }
warn() { echo -e "${YLW}[!]${NC} $*"; }
fail() { echo -e "${RED}[✘]${NC} $*"; }
info() { echo -e "${BLU}[→]${NC} $*"; }

banner() {
  echo ""
  echo -e "${BLU}══════════════════════════════════════════${NC}"
  echo -e "${BLU}  $*${NC}"
  echo -e "${BLU}══════════════════════════════════════════${NC}"
}

# ── 1. CLUSTER CONNECTIVITY ───────────────────────────────────────────────────
banner "CLUSTER CONNECTIVITY"
if kubectl cluster-info &>/dev/null; then
  ok "kubectl can reach the API server"
  kubectl cluster-info | head -3
else
  fail "Cannot connect to Kubernetes API server"
  exit 1
fi

# ── 2. NODE STATUS ────────────────────────────────────────────────────────────
banner "NODE STATUS"
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
TOTAL=$(kubectl get nodes --no-headers | wc -l)

if [ "$NOT_READY" -eq 0 ]; then
  ok "All $TOTAL nodes are Ready"
else
  fail "$NOT_READY / $TOTAL nodes are NOT Ready"
  kubectl get nodes | grep -v " Ready"
fi

# Check for node pressure conditions
echo ""
info "Checking node conditions..."
while IFS= read -r node; do
  MEM=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}')
  DISK=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}')
  PID=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="PIDPressure")].status}')

  [ "$MEM" = "True" ]  && fail "Node $node: MemoryPressure=True"
  [ "$DISK" = "True" ] && fail "Node $node: DiskPressure=True"
  [ "$PID" = "True" ]  && fail "Node $node: PIDPressure=True"
  [ "$MEM" = "False" ] && [ "$DISK" = "False" ] && [ "$PID" = "False" ] \
    && ok "Node $node: no pressure conditions"
done < <(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)

# ── 3. CONTROL PLANE COMPONENTS ───────────────────────────────────────────────
banner "CONTROL PLANE PODS (kube-system)"
UNHEALTHY_CP=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
if [ "$UNHEALTHY_CP" -eq 0 ]; then
  ok "All kube-system pods are Running"
else
  warn "$UNHEALTHY_CP kube-system pods are not Running:"
  kubectl get pods -n kube-system | grep -v "Running\|Completed\|NAME"
fi

# ── 4. POD HEALTH IN TARGET NAMESPACE ─────────────────────────────────────────
banner "POD HEALTH IN NAMESPACE: $NS"
FAILING=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | \
  grep -v "Running\|Completed\|Succeeded" | wc -l || echo 0)
TOTAL_PODS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | wc -l || echo 0)

if [ "$FAILING" -eq 0 ]; then
  ok "All $TOTAL_PODS pods are healthy in namespace $NS"
else
  warn "$FAILING / $TOTAL_PODS pods have issues in namespace $NS:"
  kubectl get pods -n "$NS" | grep -v "Running\|Completed\|Succeeded\|NAME" || true
fi

# ── 5. RECENT EVENTS ─────────────────────────────────────────────────────────
banner "RECENT WARNING EVENTS ($NS)"
WARN_EVENTS=$(kubectl get events -n "$NS" --field-selector type=Warning \
  --sort-by='.lastTimestamp' 2>/dev/null | tail -10)
if [ -z "$WARN_EVENTS" ]; then
  ok "No warning events in namespace $NS"
else
  warn "Warning events found:"
  echo "$WARN_EVENTS"
fi

# ── 6. RESOURCE QUOTAS ───────────────────────────────────────────────────────
banner "RESOURCE QUOTAS ($NS)"
RQ=$(kubectl get resourcequota -n "$NS" --no-headers 2>/dev/null | wc -l)
if [ "$RQ" -gt 0 ]; then
  warn "ResourceQuotas exist — check limits:"
  kubectl describe resourcequota -n "$NS"
else
  info "No ResourceQuotas in namespace $NS"
fi

# ── 7. EMPTY ENDPOINTS ───────────────────────────────────────────────────────
banner "SERVICE ENDPOINT CHECK ($NS)"
while IFS= read -r svc; do
  EP=$(kubectl get endpoints "$svc" -n "$NS" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
  if [ -z "$EP" ]; then
    fail "Service $svc has NO endpoints (selector mismatch?)"
  else
    ok "Service $svc has endpoints"
  fi
done < <(kubectl get svc -n "$NS" --no-headers -o custom-columns=NAME:.metadata.name | grep -v kubernetes)

# ── 8. PVC STATUS ─────────────────────────────────────────────────────────────
banner "PERSISTENT VOLUME CLAIMS ($NS)"
UNBOUND=$(kubectl get pvc -n "$NS" --no-headers 2>/dev/null | grep -v Bound | wc -l)
if [ "$UNBOUND" -eq 0 ]; then
  ok "All PVCs are Bound in namespace $NS"
else
  fail "$UNBOUND PVC(s) are not Bound:"
  kubectl get pvc -n "$NS" | grep -v Bound || true
fi

# ── 9. CERTIFICATE EXPIRY (control plane only) ────────────────────────────────
banner "CERTIFICATE EXPIRY CHECK"
if command -v kubeadm &>/dev/null; then
  kubeadm certs check-expiration 2>/dev/null | grep -v "^$" || \
    warn "kubeadm available but cannot check certs (not control plane?)"
else
  info "kubeadm not found — skipping cert check (not a kubeadm cluster or not on control plane)"
fi

# ── SUMMARY ──────────────────────────────────────────────────────────────────
banner "DIAGNOSTIC SUMMARY"
echo ""
echo "  Namespace checked : $NS"
echo "  Timestamp         : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""
echo "  Run 'kubectl get events -n $NS --sort-by=.lastTimestamp' for full events"
echo "  Run './scripts/pod-health-check.sh $NS' for per-pod analysis"
echo ""
