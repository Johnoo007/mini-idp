#!/usr/bin/env bash
# One command: create a local kind cluster and deploy mini-idp.
# Usage: ./scripts/bootstrap.sh
set -euo pipefail

CLUSTER="mini-idp"
IMAGE="mini-idp:local"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\n==> %s\n' "$*"; }

# 1. check tools
for cmd in docker kind kubectl; do
  command -v "$cmd" >/dev/null || { echo "missing: $cmd" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running" >&2; exit 1; }

# 2. cluster (skip if it already exists)
if kind get clusters | grep -qx "$CLUSTER"; then
  log "cluster '$CLUSTER' already exists"
else
  log "creating cluster '$CLUSTER'"
  kind create cluster --name "$CLUSTER" --wait 60s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

# 3. build image and load it into the cluster nodes
log "building $IMAGE"
docker build -q --build-arg VERSION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)" -t "$IMAGE" "$ROOT" >/dev/null
log "loading image into kind"
kind load docker-image "$IMAGE" --name "$CLUSTER"

# 4. deploy
log "applying manifests"
EXISTED=false
kubectl -n mini-idp get deployment mini-idp >/dev/null 2>&1 && EXISTED=true
kubectl apply -f "$ROOT/k8s/namespace.yaml"
kubectl apply -f "$ROOT/k8s/"
# same tag, new image: restart so pods pick it up (not needed on first deploy)
if [ "$EXISTED" = true ]; then
  kubectl -n mini-idp rollout restart deployment/mini-idp >/dev/null
fi
kubectl -n mini-idp rollout status deployment/mini-idp --timeout=90s

# 5. smoke test through the Service
log "smoke test"
kubectl -n mini-idp port-forward svc/mini-idp 18081:80 >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
for i in {1..20}; do
  curl -fs localhost:18081/healthz >/dev/null 2>&1 && break
  sleep 0.5
done
echo "healthz: $(curl -fs localhost:18081/healthz)"
echo "version: $(curl -fs localhost:18081/api/version)"

log "done. try: kubectl -n mini-idp port-forward svc/mini-idp 8080:80"
