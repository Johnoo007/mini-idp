# mini-idp

Small Go service used as the workload for a DevOps pipeline (Docker → CI → Kubernetes → GitOps).

## Endpoints
| Path | Purpose |
|---|---|
| `GET /healthz` | liveness probe |
| `GET /readyz` | readiness probe |
| `GET /api/hello?name=` | sample API |
| `GET /api/version` | build version (set via `-ldflags`) |

## Run
```bash
go test ./...
docker build --build-arg VERSION=0.1.0 -t mini-idp .
docker run --rm -p 8080:8080 mini-idp
```

## Image size: single-stage vs multi-stage
Measured with `docker images` (Docker 29.3, linux/arm64):

| Dockerfile | Base | Size |
|---|---|---|
| `Dockerfile.single` | `golang:1.26` | 1.42 GB |
| `Dockerfile` (multi-stage) | `distroless/static` (nonroot) | 14 MB |

~99% smaller. The final image has no shell or package manager and runs as a non-root user.

## Local Kubernetes (kind)
```bash
./scripts/bootstrap.sh   # create kind cluster, build + load image, deploy, smoke test
./scripts/teardown.sh    # delete the cluster
```
From an empty machine state (node image already cached) `bootstrap.sh` takes ~36 s.

- 2 replicas, liveness probe `/healthz`, readiness probe `/readyz`
- CPU/memory requests and limits
- non-root (UID 65532), read-only root filesystem, all Linux capabilities dropped

Problem hit on the way: the pod failed with `CreateContainerConfigError`
(`runAsNonRoot` cannot verify a non-numeric user). Fixed by using a numeric `USER 65532:65532` in the Dockerfile.

## GitOps with Argo CD
```bash
./scripts/gitops.sh   # kind + Argo CD v3.6.1 + the mini-idp Application
```
Flow: push to `main` → CI tests, builds a multi-arch image (amd64 + arm64), scans it with Trivy, pushes to GHCR →
CI writes the new tag into `k8s/kustomization.yaml` → Argo CD sees the commit and syncs the cluster.
Changes under `k8s/` skip CI and are deployed by Argo CD directly.

Auto-sync is on with `prune` and `selfHeal`.

### Tests (kind on Apple silicon, Nov 2026)
| Test | Result |
|---|---|
| Self-heal: `kubectl scale --replicas=5` by hand | Argo CD put it back to 2 replicas in ~1 s |
| Bad release: readiness probe pointed at a missing path | new pod never became Ready, rollout paused, the 2 old pods kept serving: **0 failed of 1,218 requests** |
| Rollback: `git revert` of the bad commit, pushed | back to Synced/Healthy with 2/2 ready in ~2 s, 0 failed requests |

Timings use a manual refresh (`argocd.argoproj.io/refresh` annotation), which is what a Git webhook does.
Without a webhook Argo CD polls Git every 3 minutes by default.
