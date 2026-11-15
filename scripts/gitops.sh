#!/usr/bin/env bash
# GitOps setup: kind cluster + Argo CD, which deploys mini-idp from GitHub.
# Usage: ./scripts/gitops.sh
set -euo pipefail

CLUSTER="mini-idp"
ARGOCD_VERSION="v3.6.1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\n==> %s\n' "$*"; }

for cmd in docker kind kubectl; do
  command -v "$cmd" >/dev/null || { echo "missing: $cmd" >&2; exit 1; }
done

if ! kind get clusters | grep -qx "$CLUSTER"; then
  log "creating cluster '$CLUSTER'"
  kind create cluster --name "$CLUSTER" --wait 60s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

log "installing Argo CD $ARGOCD_VERSION"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml" >/dev/null
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

log "registering the mini-idp Application"
kubectl apply -f "$ROOT/argocd/application.yaml"

log "waiting for Argo CD to sync"
for i in {1..60}; do
  status=$(kubectl -n argocd get application mini-idp -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
  echo "  $status"
  [ "$status" = "Synced/Healthy" ] && break
  sleep 5
done

log "done"
echo "Argo CD UI : kubectl -n argocd port-forward svc/argocd-server 8443:443  ->  https://localhost:8443"
echo "admin pass : kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
