# Eiwa Browser

Eiwa-native browser automation: client library + JSON-RPC 2.0 protocol +
engine driving headless Chromium (CDP hidden behind the Chromium Adapter).

Canonical spec: `spec/Eiwa-Browser-SPEC.md`.

## Layout (§44)

- `protocol/` — JSON-RPC schema, `protocol.yaml`, `version`
- `src/` — client (`browser/`, `context/`, `page/`, `locator/`,
  `network/`, `download/`, `storage/`, `plugins/`, `protocol/`,
  `errors/`), engine (`chromium/`)
- `tests/` — protocol, browser, page, network, plugins
- `docker/chromium/` — browser worker image
- `examples/` — usage scripts + `court-example/` reference consumer

## MVP (§45)

`Browser`, `BrowserContext`, `Page`, `Locator`; `goto/reload/goBack/goForward`;
`click/fill/type/press`; `text/content/attribute`; `waitFor/waitForUrl`;
`evaluate`; `cookies/addCookie/storageState`; request/response + console +
download events; observe-only plugin registration (`NetworkLogger`).
