# Eiwa Browser

Eiwa-native browser automation: client library + JSON-RPC 2.0 protocol +
engine driving headless Chromium (CDP hidden behind the Chromium Adapter).

Canonical spec: `docs/Eiwa-Browser-SPEC.md`.

## Layout (§44)

- `protocol/` — JSON-RPC schema, `protocol.yaml`, `version`
- `src/` — `main.ei` worker entry; `browser/` (client, pool, protocol,
  net, worker, engine, chromium, storage, plugins, diagnostics),
  `context/`, `page/`
- `tests/` — one `*_test.ei` per area (`eiwa test` runs all)
- `Dockerfile` — multi-stage worker image (toolchain + Chromium runtime)
- `.github/workflows/` — CI (`eiwa test` + build) and release (Docker Hub)
- `examples/` — usage scripts + `scraping-demo/` reference consumer

## MVP (§45)

`Browser`, `BrowserContext`, `Page`, `Locator`; `goto/reload/goBack/goForward`;
`click/fill/type/press`; `text/content/attribute`; `waitFor/waitForUrl`;
`evaluate`; `cookies/addCookie/storageState`; request/response + console +
download events; observe-only plugin registration (`NetworkLogger`).
