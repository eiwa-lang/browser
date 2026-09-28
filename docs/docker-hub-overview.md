# Quick reference

- **Maintained by:** [the Eiwa team](https://github.com/eiwa-lang/browser)
- **Where to get help:** [Eiwa documentation](https://eiwa.dev), [Eiwa Browser spec](https://github.com/eiwa-lang/browser/blob/main/docs/Eiwa-Browser-SPEC.md)
- **Where to file issues:** [https://github.com/eiwa-lang/browser/issues](https://github.com/eiwa-lang/browser/issues)
- **Supported architectures:** `linux/amd64`, `linux/arm64`
- **Source of this description:** [`docs/docker-hub-overview.md`](https://github.com/eiwa-lang/browser/blob/main/docs/docker-hub-overview.md) in [`eiwa-lang/browser`](https://github.com/eiwa-lang/browser) (synced to the Hub on every release)

# What is Eiwa Browser Worker?

Headless Chromium automation over a versioned JSON-RPC 2.0 protocol (one message per WebSocket frame). The worker manages Chromium processes and exposes the Eiwa Browser API to scraper workers on a trusted internal network — no ingress, no auth. See the [spec](https://github.com/eiwa-lang/browser/blob/main/docs/Eiwa-Browser-SPEC.md) and [plan](https://github.com/eiwa-lang/browser/blob/main/docs/PLAN.md).

This image bundles the engine binary with headless Chromium, fonts and shared libraries on `debian:trixie-slim`. `ENTRYPOINT` is the worker, `PORT` defaults to `8080`.

# How to use this image

## Run a worker

```console
$ docker run --rm -p 8080:8080 eiwac/browser-worker:latest
```

## Health check

```console
$ curl http://localhost:8080/health
{"status": "ok", "protocol": "eiwa-browser", "version": "1.0", "browsers": 0, "contexts": 0}
```

## Connect a client

Point the client pool at the internal Service DNS (K8s) or container host:

```eiwa
val browser = Browser.connect(
    workers: ["ws://browser-worker:8080"],
    poolSize: 8
)
```

The client picks the worker per context (sticky afterwards); see spec §§5.2, 30.2–30.3.

# Image variants

## `eiwac/browser-worker:<version>`

Pinned worker for a specific [browser release](https://github.com/eiwa-lang/browser/releases). **Use these in production.**

## `eiwac/browser-worker:latest`

Follows the newest release. Intended for **local development only**; never deploy on `latest`.

Both variants are published for `linux/amd64` and `linux/arm64`.

# License

The worker in this image follows the license of the [eiwa-lang/browser](https://github.com/eiwa-lang/browser) repository. As with all Docker images, your own deployments additionally contain other software under various licenses (notably Debian and Chromium packages); it is the image user's responsibility to ensure compliance.
