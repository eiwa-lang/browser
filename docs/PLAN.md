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
- [ ] Chromium spawn/manage + CDP session — BLOCKED, see below
- [ ] `Browser`/`Context`/`Page` managers, `Chromium Adapter` (§§5.4, 5.5)

BLOCKER (reported, no workaround applied): `std.process` offers only
blocking `exec`/`capture` — no background spawn/kill for a long-lived
Chromium. The WS half is done in pure Eiwa (handshake with accept
verification via the crypto lib's new SHA-1/standard-base64, masking,
ping/pong, close; loopback integration test green). Remaining need:
(a) `std` gains background process spawn, or (b) engine transport
ships as a native helper outside Eiwa. Pure client logic + WS done and
tested (32/32).

## Phase 3 — Basic Automation (MVP)

- [x] `Locator` strategies + `{"strategy", "selector"}` wire form (§7)
- [x] Typed command builders for the MVP surface (§§6.3, 9, 45)
- [x] `TimeoutConfig` + most-specific-wins resolution, 30000ms default (§34)
- [x] `waitUntil` validation (`commit/domcontentloaded/load/networkidle`) (§9)
- [ ] Execution against a live engine (needs Phase 2 transport)

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

Language finding (to file upstream): `for` over a Map with a generic
value type fails (`Unresolved property 'list'`; minimal repro saved).
`PluginRegistry` keeps a parallel names list instead. Checker also
does not narrow through `||` chains — `!!` after explicit null guards.

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
