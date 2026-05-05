#!/bin/bash
# ============================================================
# cluster-health-report.sh — Full Cluster Health Overview
# Day 74 | DevOps Mastery Series
# Usage: ./cluster-health-report.sh [--namespace <ns>]
# ============================================================

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

header()  { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${RESET}"; }
ok()      { echo -e "  ${GREEN}✅ $1${RESET}"; }
warn()    { echo -e "  ${YELLOW}⚠️  $1${RESET}"; }
fail()    { echo -e "  ${RED}❌ $1${RESET}"; }

echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo -e "║   Kubernetes Cluster Health Report       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo "Generated: $(date)"
echo "Context: $(kubectl config current-context 2>/dev/null)"

# ─── NODE HEALTH ──────────────────────────────────
header "Node Health"
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | awk '{print $1}' || true)

echo "  Total Nodes: $NODE_COUNT | Ready: $READY_COUNT"
if [[ -n "$NOT_READY" ]]; then
  fail "NotReady nodes: $NOT_READY"
else
  ok "All nodes Ready"
fi
kubectl get nodes -o wide

# ─── NODE RESOURCE USAGE ──────────────────────────
header "Node Resource Usage"
kubectl top nodes 2>/dev/null || warn "metrics-server not available"

# ─── CONTROL PLANE PODS ───────────────────────────
header "Control Plane Pods (kube-system)"
kubectl get pods -n kube-system -o wide

FAILED_CP=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v -E "(Running|Completed)" | wc -l)
if [[ "$FAILED_CP" -gt 0 ]]; then
  fail "$FAILED_CP control plane pods NOT Running"
  kubectl get pods -n kube-system | grep -v -E "(Running|Completed)"
else
  ok "All control plane pods Running"
fi

# ─── CLUSTER-WIDE POD STATUS ──────────────────────
header "Cluster-Wide Pod Status"
TOTAL=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
RUNNING=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "Running" || true)
PENDING=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "Pending" || true)
CRASHLOOP=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "CrashLoopBackOff" || true)
FAILED=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "Error\|OOMKilled\|ImagePullBackOff" || true)

echo "  Total: $TOTAL | Running: $RUNNING | Pending: $PENDING | CrashLoop: $CRASHLOOP | Failed: $FAILED"

if [[ "$CRASHLOOP" -gt 0 ]] || [[ "$FAILED" -gt 0 ]]; then
  fail "Unhealthy pods detected:"
  kubectl get pods -A | grep -v -E "(Running|Completed|Terminating)" | head -20
else
  ok "No unhealthy pods"
fi

# ─── PVC STATUS ───────────────────────────────────
header "PersistentVolumeClaims"
UNBOUND=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -v "Bound" | wc -l)
if [[ "$UNBOUND" -gt 0 ]]; then
  warn "$UNBOUND PVCs not Bound:"
  kubectl get pvc -A | grep -v "Bound"
else
  ok "All PVCs Bound"
fi

# ─── RECENT WARNING EVENTS ────────────────────────
header "Recent Warning Events (last 20)"
kubectl get events -A --field-selector type=Warning \
  --sort-by='.lastTimestamp' 2>/dev/null | tail -20 || warn "No events found"

# ─── TOP RESOURCE CONSUMERS ───────────────────────
header "Top CPU Consumers"
kubectl top pods -A --sort-by=cpu 2>/dev/null | head -10 || warn "metrics-server not available"

header "Top Memory Consumers"
kubectl top pods -A --sort-by=memory 2>/dev/null | head -10 || warn "metrics-server not available"

# ─── SUMMARY ──────────────────────────────────────
echo -e "\n${BOLD}══════════ Summary ══════════${RESET}"
[[ "$NOT_READY" ]] && fail "Nodes NotReady: $NOT_READY" || ok "All nodes Ready"
[[ "$CRASHLOOP" -gt 0 ]] && fail "CrashLoopBackOff pods: $CRASHLOOP" || ok "No CrashLoopBackOff pods"
[[ "$PENDING" -gt 0 ]] && warn "Pending pods: $PENDING" || ok "No Pending pods"
[[ "$UNBOUND" -gt 0 ]] && warn "Unbound PVCs: $UNBOUND" || ok "All PVCs bound"
echo ""
