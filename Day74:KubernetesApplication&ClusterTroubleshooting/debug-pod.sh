#!/bin/bash
# ============================================================
# debug-pod.sh — Automated Pod Diagnostic Script
# Day 74 | DevOps Mastery Series
# Usage: ./debug-pod.sh <pod-name> <namespace>
# ============================================================

set -euo pipefail

POD=${1:-""}
NS=${2:-"default"}

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header()  { echo -e "\n${BOLD}${CYAN}=== $1 ===${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${RESET}"; }
error()   { echo -e "${RED}❌ $1${RESET}"; }
success() { echo -e "${GREEN}✅ $1${RESET}"; }

if [[ -z "$POD" ]]; then
  echo "Usage: $0 <pod-name> <namespace>"
  exit 1
fi

echo -e "${BOLD}🔍 Pod Diagnostic Report${RESET}"
echo "Pod: $POD | Namespace: $NS | Time: $(date)"
echo "─────────────────────────────────────────────"

# 1. Basic status
header "Pod Status"
kubectl get pod "$POD" -n "$NS" -o wide 2>/dev/null || error "Pod not found"

# 2. Phase and conditions
header "Phase & Conditions"
PHASE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
echo "Phase: $PHASE"
kubectl get pod "$POD" -n "$NS" \
  -o jsonpath='{range .status.conditions[*]}{.type}: {.status} - {.message}{"\n"}{end}' 2>/dev/null

# 3. Container states
header "Container States"
kubectl get pod "$POD" -n "$NS" \
  -o jsonpath='{range .status.containerStatuses[*]}Container: {.name}{"\n"}  Ready: {.ready}{"\n"}  RestartCount: {.restartCount}{"\n"}  State: {.state}{"\n"}  LastState: {.lastState}{"\n\n"}{end}' 2>/dev/null

# 4. Resource usage
header "Resource Requests & Limits"
kubectl get pod "$POD" -n "$NS" \
  -o jsonpath='{range .spec.containers[*]}Container: {.name}{"\n"}  Requests: {.resources.requests}{"\n"}  Limits:   {.resources.limits}{"\n\n"}{end}' 2>/dev/null

# 5. Events
header "Recent Events"
kubectl get events -n "$NS" \
  --field-selector involvedObject.name="$POD" \
  --sort-by='.lastTimestamp' 2>/dev/null | tail -20

# 6. Logs (current)
header "Current Logs (last 30 lines)"
kubectl logs "$POD" -n "$NS" --tail=30 2>/dev/null || warn "No current logs"

# 7. Previous logs
header "Previous Container Logs (if crashed)"
kubectl logs "$POD" -n "$NS" --previous --tail=30 2>/dev/null || warn "No previous container logs"

# 8. Node info
header "Node Assignment"
NODE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
if [[ -n "$NODE" ]]; then
  echo "Assigned to node: $NODE"
  kubectl describe node "$NODE" 2>/dev/null | grep -A5 "Conditions:" | head -20
else
  warn "Pod not scheduled to any node"
fi

echo -e "\n${BOLD}${GREEN}Diagnostic complete.${RESET}"
echo "For interactive debug: kubectl exec -it $POD -n $NS -- sh"
echo "For ephemeral debug:   kubectl debug -it $POD -n $NS --image=busybox"
