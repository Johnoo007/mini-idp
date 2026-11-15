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
