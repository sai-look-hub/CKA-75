#!/usr/bin/env bash
# =============================================================================
# pod-health-check.sh — Day 73: Per-Pod Deep Health Analysis
# Usage: ./scripts/pod-health-check.sh [namespace]
# =============================================================================

set -euo pipefail

NS="${1:-default}"
RED='\033[0;31m'
YLW='\033[1;33m'
GRN='\033[0;32m'
BLU='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "  ${GRN}✔${NC} $*"; }
warn() { echo -e "  ${YLW}!${NC} $*"; }
fail() { echo -e "  ${RED}✘${NC} $*"; }
info() { echo -e "  ${BLU}→${NC} $*"; }

echo ""
echo -e "${BLU}══════════════════════════════════════════${NC}"
echo -e "${BLU}  Pod Health Analysis — Namespace: $NS${NC}"
echo -e "${BLU}══════════════════════════════════════════${NC}"
echo ""

PODS=$(kubectl get pods -n "$NS" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)

if [ -z "$PODS" ]; then
  echo "  No pods found in namespace $NS"
  exit 0
fi

for POD in $PODS; do
  echo -e "${BLU}── Pod: $POD ──────────────────────────────${NC}"

  PHASE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "  Phase: $PHASE"

  # Check each container
  CONTAINERS=$(kubectl get pod "$POD" -n "$NS" \
    -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)

  for CTR in $CONTAINERS; do
    STATE=$(kubectl get pod "$POD" -n "$NS" \
      -o jsonpath="{.status.containerStatuses[?(@.name=='$CTR')].state}" 2>/dev/null)
    RESTARTS=$(kubectl get pod "$POD" -n "$NS" \
      -o jsonpath="{.status.containerStatuses[?(@.name=='$CTR')].restartCount}" 2>/dev/null)
    READY=$(kubectl get pod "$POD" -n "$NS" \
      -o jsonpath="{.status.containerStatuses[?(@.name=='$CTR')].ready}" 2>/dev/null)

    echo ""
    echo "  Container: $CTR"
    echo "    Ready   : ${READY:-unknown}"
    echo "    Restarts: ${RESTARTS:-0}"

    # High restart warning
    if [ "${RESTARTS:-0}" -gt 5 ]; then
      fail "High restart count ($RESTARTS) — likely CrashLoopBackOff"
      echo ""
      warn "Last 20 lines of crash log:"
      kubectl logs "$POD" -n "$NS" -c "$CTR" --previous --tail=20 2>/dev/null || \
        info "No previous logs available"
      echo ""
    elif [ "${RESTARTS:-0}" -gt 0 ]; then
      warn "Restart count: $RESTARTS — check for instability"
    else
      ok "Container is stable (0 restarts)"
    fi

    # Check ready state
    if [ "${READY:-false}" = "false" ]; then
      fail "Container $CTR is NOT ready"
    fi
  done

  # Check events for this pod
  EVENTS=$(kubectl get events -n "$NS" \
    --field-selector "involvedObject.name=$POD" \
    --sort-by='.lastTimestamp' \
    --no-headers 2>/dev/null | tail -5)

  if echo "$EVENTS" | grep -qi "warning\|backoff\|oom\|kill\|failed\|error"; then
    echo ""
    warn "Warning events for $POD:"
    echo "$EVENTS" | grep -i "warning\|backoff\|oom\|kill\|failed\|error" | \
      while read -r line; do echo "    $line"; done
  fi

  echo ""
done

echo -e "${BLU}══════════════════════════════════════════${NC}"
echo "  Analysis complete — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""
