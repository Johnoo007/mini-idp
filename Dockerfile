# ---- build stage: has the Go toolchain ----
# build on the runner's native platform, cross-compile for the target (no QEMU needed)
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
ARG VERSION=dev
ARG TARGETOS TARGETARCH
# static binary, strip debug info (-s -w)
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags "-s -w -X main.version=${VERSION}" -o /app .

# ---- run stage: only the binary ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
EXPOSE 8080
# numeric UID so Kubernetes runAsNonRoot can verify it (65532 = distroless "nonroot")
USER 65532:65532
ENTRYPOINT ["/app"]
