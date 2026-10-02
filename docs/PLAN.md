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
- [x] `cancel` notification (§24.6)
- [x] `page.subscribe`/`page.unsubscribe` frames (§18)
- [x] `page.subscribe` implicit-subscribe tracker (`Subscriptions`)
- [x] Remote ref parsing (`page-7` → kind) (§25)
- [x] Live proxy registry with cascade removal (`ProxyRegistry`)
- [x] `protocol/protocol.yaml` kept in sync with implementation

Note: tracker + registry unblocked by `eiwa-lang@43896db`
(`MutableMap.remove` / `MutableSet.remove`). Language finding: `val`
narrows after an early-return null check (redundant `!!` warns).

## Phase 2 — Chromium Engine (MVP)

- [x] Client routing: `WorkerPool` round-robin, sticky pins, eviction
- [x] `Browser.connect/launch`, `newContext/contexts/close` (§6.1)
- [x] `BrowserContext` / `Page` handles + cascade close (§§6.2, 6.3)
- [x] `ProxyRegistry.childrenOf` for `pages()`/`contexts()`
- [x] Real WebSocket transport: pure-Eiwa RFC 6455 client (`net/ws.ei`)
- [x] Chromium lifecycle: headless fixed-port spawn + terminate (§§28, 29)
- [x] Minimal HTTP GET + `/json/version` debugger-URL parse (CDP attach)
- [x] `CdpConn` driver: id correlation, session attach, full flow proven
      against a fake DevTools target (create→attach→navigate→load→title)
- [x] Live CDP session against real Chromium (proven in Docker build:
      `cdp live: ok:Example Domain`, full flow create→attach→load→title)
- [x] Worker drives live Engine: `serveEngine`, `engineDispatch` routing
      newContext/newPage/goto/text/content/close (+initialize/version
      fallback), Mutex-guarded, proven end-to-end against a fake
- [x] `ContextManager`/`PageManager` state machines + `Engine` facade (§5.4)
- [ ] `bootEngine` live-attach path + graceful shutdown + `Chromium Adapter`
      as named unit (§§5.4, 5.5)

`std.process` blocker resolved by `eiwa-lang@d54fc13`
(spawn/alive/kill/wait/terminate).

## Phase 3 — Basic Automation (MVP)

- [x] `Locator` strategies + `{"strategy", "selector"}` wire form (§7)
- [x] Typed command builders for the MVP surface (§§6.3, 9, 45)
- [x] `TimeoutConfig` + most-specific-wins resolution, 30000ms default (§34)
- [x] `waitUntil` validation (`commit/domcontentloaded/load/networkidle`) (§9)
- [x] Execution against a live engine (`worker_live_test`: JSON-RPC
      newContext/newPage/goto/text/close routed through `Engine`)

## Phase 4 — Network Observe (MVP)

- [x] `ObservedRequest/Response` parsing from event params (§11)
- [x] `page.subscribe` wiring for high-volume events (§18, via Subscriptions)
- [ ] `route` interception — post-MVP (§§12, 24.5)

## Phase 5 — State (MVP minimal)

- [x] `Cookie` value + `cookies/addCookie/clearCookies` builders (§13)
- [x] `storageState` request builder; value semantics, rule A (§14)
- [x] `Download` handle parsing + `download.bytes`/`artifact.read` (§15)
- [ ] `setInputFiles` with bytes — post-MVP (§16)

## Phase 6 — Plugins (MVP: registration + observe-only)

- [x] `PluginRegistry.use/unuse/subscribed/plugins` + topic validation
- [x] `NetworkLogger` topics (`request`, `response`)
- [ ] Dispatch + `challenge` permission — post-MVP (needs transport)
- [ ] `onChallenge` + Auth/Captcha/Proxy examples — post-MVP (§§19, 49, 20)

Language finding (upstream): `for` over a Map with a generic value
type fails (`Unresolved property 'list'`; RED test saved).
`PluginRegistry` keeps a parallel names list instead.

## Phase 7 — Diagnostics (MVP minimal)

- [x] `GET /health` endpoint (served by worker, validated in Docker)
- [x] Header redaction, case-insensitive sensitive set (§§35, 38)
- [x] `parseConsole` (MVP event) + `parseChallenge` (post-MVP payload, §19)
- [ ] `screenshot()` returning bytes — post-MVP (§17)
- [ ] Tracing/metrics full — post-MVP (§§36, 37)

## Phase 8 — Production (MVP minimal)

- [x] WS server side: handshake accept + frame echo path (`net/ws_server.ei`)
- [x] Engine dispatch skeleton: `initialize`/`browser.version`/unknown (§24)
- [x] `healthResponse` builder for k8s probes (§30.1)
- [x] Worker accept loop + `main` binary (`serve`/`serveOne`, `src/main.ei`)
- [x] Task-per-connection (unblocked by compiler TaskBlock fix; overlap
      proven: second connection served while a WS session is held)
- [x] Docker image validated: boots, `/health` per §30.1, WS `initialize`
      round-trip against the container (idle accept no longer exits)
- [x] worker round-trip with >125-byte frames (was blocked on backend:
      `String.substring` used `strncpy`, zeroing bytes after the first
      NUL — fixed in `eiwa-lang` `src/std/core.ei` via `memcpy`, same as
      the existing `String.slice`; `socket_binary_test.ei` green)
- [x] Docker worker image, Engine + Chromium headless (§§28, 29)
- [x] Client pool: `Browser.connect(workers, poolSize)`, round-robin,
      sticky contexts, fail-fast eviction (§§5.2, 30.2)
- [x] K8s decision: manifests live in the consumer repo, not here
- [ ] Headless-service DNS discovery (least-loaded) — post-MVP (§30.3)
- [x] `examples/scraping-demo/` reference consumer validated (§44: all
      examples compile against real modules via `--module-path`)

## Out of browser scope (separate scraper repo)

Normalization, record models, PostgreSQL, connector fallback logic —
consumer-owned (§§39-41).
