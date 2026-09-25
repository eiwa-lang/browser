# Eiwa Browser — Plan

Derived from `docs/Eiwa-Browser-SPEC.md` §53, adjusted by review decisions
(JSON-RPC 2.0, rule A for files, MVP scope in §45). Checkboxes track build
progress. `MVP` = first release; `post-MVP` = later.

## Phase 1 — Protocol (MVP)

- [x] JSON-RPC 2.0 framing: one message per WS text frame (§§24, 27)
- [x] `initialize` handshake with version + capabilities (§26)
- [x] Method naming `<object>.<camelCaseMethod>` (§24)
- [x] Success/error envelope: std codes + `data.code` mapping (§§24.3, 33)
- [x] Event notifications with `page`/`context` owner in `params` (§24.4)
- [ ] `cancel` notification (§24.6)
- [ ] `page.subscribe` implicit-subscribe rule (§18)
- [ ] Remote object IDs + client proxies (§25)
- [x] `protocol/protocol.yaml` kept in sync with implementation

## Phase 2 — Chromium Engine (MVP)

- [ ] Chromium process lifecycle (launch/close, configurable count) (§28)
- [ ] CDP isolated behind Chromium Adapter (no other CDP imports) (§5.5)
- [ ] `Browser`: `launch/connect/close/contexts/newContext/version/isConnected` (§6.1)
- [ ] `BrowserContext` isolation: cookies, storages, permissions (§6.2)
- [ ] `Page` handle + `Locator` (§6.3, §7)
- [ ] Unit mapping per §5.4 (managers, LocatorEngine, EventDispatcher)

## Phase 3 — Basic Automation (MVP)

- [ ] Navigation: `goto/reload/goBack/goForward` + `waitUntil` + timeouts (§9)
- [ ] Actions: `click/fill/type/press` with auto-wait (§8)
- [ ] `text/content/attribute`, `innerText/innerHtml` (§6.3)
- [ ] `waitFor/waitForUrl` + `defaultTimeout/navigationTimeout/actionTimeout` (§34)
- [ ] `evaluate` (primitives/JSON/arrays/serialized errors) (§10)
- [ ] CSS/XPath/text/role/attribute locator strategies (§7)
- [ ] Explicit lifecycle in examples (`page.close()` before `context.close()`) (§32)

## Phase 4 — Network Observe (MVP)

- [ ] `page.request` / `page.response` / `requestFailed` events (§11)
- [ ] `console` events (§18)
- [ ] `page.subscribe` wiring for high-volume events (§18)
- [ ] `route` interception — post-MVP (§§12, 24.5)

## Phase 5 — State (MVP minimal)

- [ ] `cookies/addCookie/clearCookies` (§13)
- [ ] `storageState` as value (no paths, rule A) (§14)
- [ ] `download` event + `download.bytes()` + `artifact.read` chunks (rule A) (§15)
- [ ] `setInputFiles` with bytes — post-MVP (§16)

## Phase 6 — Plugins (MVP: registration + observe-only)

- [ ] Plugin lifecycle: load/initialize/start/shutdown/unload (§21)
- [ ] `browser.use()` registration (§21)
- [ ] Observe-only `NetworkLogger` example (§§21, 48)
- [ ] Permission declarations (MVP: `network`; rest declared) (§22)
- [ ] `onChallenge` + `challenge` permission — post-MVP (§§19, 49)
- [ ] Auth/Captcha/Proxy examples — post-MVP (§20)

## Phase 7 — Diagnostics (MVP minimal)

- [ ] `GET /health` (`status/protocol/version/browsers/contexts`) (§30.1)
- [ ] Structured logs with redaction (§35)
- [ ] `screenshot()` returning bytes — post-MVP (§17)
- [ ] Tracing/metrics full — post-MVP (§§36, 37)

## Phase 8 — Production (MVP minimal)

- [ ] Docker worker image (Engine + Chromium, headless) (§§28, 29)
- [ ] Client pool: `Browser.connect(workers, poolSize)`, round-robin,
      sticky contexts, fail-fast eviction (§§5.2, 30.2)
- [ ] K8s `Service` discovery (stable DNS + `poolSize`) (§30.3)
- [ ] Resource limits + graceful shutdown (§§28, 53)
- [ ] Headless-service DNS discovery (least-loaded) — post-MVP (§30.3)
- [ ] `examples/court-example/` reference consumer validated (§44)

## Out of browser scope (eiwa-court)

Normalization, `Process Model`, PostgreSQL, connector fallback logic —
consumer-owned (§§39-41).
