FROM golang:1.26-bookworm AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY internal/ ./internal/
ARG APP_COMMIT=unknown
ARG APP_BUILT_AT=
RUN CGO_ENABLED=0 go build -trimpath \
    -ldflags "-s -w -X icloud-privacy-mail/internal/app.AppCommit=${APP_COMMIT} -X icloud-privacy-mail/internal/app.AppBuiltAt=${APP_BUILT_AT}" \
    -o /out/icloud-privacy-mail ./cmd/panel

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 icloud \
    && useradd --uid 10001 --gid icloud --no-create-home icloud \
    && mkdir -p /data /app \
    && chown icloud:icloud /data
WORKDIR /app
COPY --from=build /out/icloud-privacy-mail /app/icloud-privacy-mail
ENV TZ=Asia/Shanghai \
    IPM_UPDATE_ENABLED=false \
    IPM_UPDATE_REPOSITORY=1824313754/icloud
USER 10001:10001
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl --fail --silent --output /dev/null http://127.0.0.1:8787/login || exit 1
ENTRYPOINT ["/app/icloud-privacy-mail"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--config", "/data/config.json", "--data", "/data/state.json"]
