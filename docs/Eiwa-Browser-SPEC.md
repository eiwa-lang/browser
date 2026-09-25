# Eiwa Browser --- Technical Specification

**Status:** Draft v0.1\
**Scope:** Browser automation engine and protocol for Eiwa\
**Primary use case:** Reliable, containerized browser automation for
judicial portals and general web automation\
**Design principle:** Eiwa Browser is a browser automation platform, not
a browser implementation.

------------------------------------------------------------------------

## 1. Purpose

Eiwa Browser provides an Eiwa-native API for controlling Chromium-based
browsers without requiring application developers to interact directly
with Chrome DevTools Protocol (CDP).

It SHALL provide:

-   browser lifecycle management;
-   isolated browser contexts;
-   page navigation;
-   DOM interaction;
-   locators;
-   JavaScript evaluation;
-   cookies and storage;
-   downloads and uploads;
-   screenshots;
-   network observation and interception;
-   browser/page events;
-   explicit challenge detection;
-   extensibility through plugins;
-   remote execution through a bidirectional protocol;
-   headless execution suitable for Docker/Kubernetes;
-   deterministic resource lifecycle management.

Eiwa Browser SHALL NOT attempt to implement Chromium.

------------------------------------------------------------------------

## 2. Goals

### 2.1 Primary goals

1.  Provide an Eiwa-native browser automation API.
2.  Run Chromium headlessly in containers.
3.  Keep browser automation isolated from application/business logic.
4.  Support multiple independent browser contexts.
5.  Support concurrent pages and browser workers.
6.  Provide a stable Eiwa Browser Protocol.
7.  Hide Chromium/CDP implementation details from Eiwa applications.
8.  Provide a first-class plugin model.
9.  Support network inspection and interception.
10. Make browser workers disposable and horizontally scalable.

### 2.2 Secondary goals

-   tracing and diagnostics;
-   screenshots and artifacts;
-   browser session persistence;
-   configurable proxy support;
-   authentication state persistence;
-   browser extensions where technically supported;
-   future support for additional browser engines.

------------------------------------------------------------------------

## 3. Non-goals

Eiwa Browser SHALL NOT:

-   implement an HTML rendering engine;
-   implement JavaScript execution itself;
-   replace Chromium;
-   bypass CAPTCHA or anti-bot protections;
-   provide mechanisms intended to evade security controls;
-   automatically defeat authentication systems;
-   hide prohibited automation from websites;
-   define judicial-domain business logic.

------------------------------------------------------------------------

# 4. High-Level Architecture

``` text
                    ┌──────────────────────────┐
                    │       Eiwa Application   │
                    │                          │
                    │ Court Connectors         │
                    │ Crawlers                 │
                    │ Scrapers                 │
                    │ E2E Tests                │
                    └────────────┬─────────────┘
                                 │
                         Eiwa Browser API
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │       Eiwa Browser       │
                    │          Client          │
                    └────────────┬─────────────┘
                                 │
                    Eiwa Browser Protocol
                   JSON-RPC 2.0 over WebSocket
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │   Eiwa Browser Engine    │
                    │                          │
                    │ Browser Manager          │
                    │ Context Manager          │
                    │ Page Manager             │
                    │ Locator Engine            │
                    │ Network Manager          │
                    │ Event Dispatcher         │
                    │ Plugin Runtime            │
                    │ Challenge Detector       │
                    └────────────┬─────────────┘
                                 │
                              CDP
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │         Chromium         │
                    └────────────┬─────────────┘
                                 │
                                 ▼
                         Target Web Site
```

`Challenge Detector` in the Engine box is post-MVP. Unit-to-diagram
mapping is defined in §5.4.

------------------------------------------------------------------------

# 5. Architectural Layers

## 5.1 Eiwa Application

The application contains business logic.

Examples:

-   judicial connectors;
-   scraping workflows;
-   crawling;
-   scheduled jobs;
-   process normalization;
-   persistence;
-   queues.

It SHALL NOT depend directly on CDP.

------------------------------------------------------------------------

## 5.2 Eiwa Browser Client

The client provides the Eiwa API.

The app passes worker addresses once; the client alone decides which
pool worker runs each pipeline (no app-side routing).

Responsibilities:

-   expose typed Eiwa objects;
-   serialize commands;
-   deserialize responses;
-   maintain remote object references;
-   maintain a pool of worker connections;
-   route each new context to one worker (sticky afterwards);
-   dispatch events;
-   handle connection failures (fail fast + evict);
-   expose errors as Eiwa exceptions.

``` eiwa
val browser = Browser.connect(
    workers: ["ws://browser-worker-1:8080", "ws://browser-worker-2:8080"]
)
val ctx = browser.newContext() // client picks the worker alone
```

------------------------------------------------------------------------

## 5.3 Eiwa Browser Protocol

The protocol is the transport-independent logical contract between the
client and browser engine. It SHALL be strict JSON-RPC 2.0
(same base as `arest` MCP via `std.jsonrpc`).

Initial transport:

**WebSocket over TCP, one JSON-RPC message per text frame.**

Future transports MAY include:

-   Unix domain sockets;
-   stdio;
-   embedded/in-process transport.

The protocol SHALL support:

-   requests (`method` + `params` + `id`);
-   responses (`result` / `error` + `id`);
-   notifications/events (no `id`, server → client);
-   server → client requests (with `id`, e.g. `route` interception);
-   remote object references;
-   errors (standard JSON-RPC codes + Eiwa `data.code`);
-   cancellation via notification;
-   protocol version negotiation via `initialize`.

------------------------------------------------------------------------

## 5.4 Eiwa Browser Engine

The engine is the server-side runtime.

Runtime units and diagram mapping (diagram names in parentheses):

-   `BrowserManager` — Chromium process lifecycle;
-   `ContextManager` — isolated contexts;
-   `PageManager` (Navigation) — `goto/goBack/goForward/reload`,
    `evaluate`;
-   `LocatorEngine` (DOM) — locators, `click/fill/type/press`,
    `text/content/attribute`, `waitFor`;
-   `NetworkManager` (Network) — observe `request/response` (MVP);
    `route` interception is post-MVP;
-   `EventDispatcher` (Events) — JSON-RPC notifications (§18, §24.4);
-   `PluginRuntime` (Plugin Runtime) — registration + minimal events
    in MVP; permissions and isolation per §§22-23;
-   `ChallengeDetector` — post-MVP (with `challengeDetected`).

Responsibilities:

-   manage Chromium processes;
-   translate Eiwa Browser Protocol commands;
-   communicate with Chromium through CDP;
-   maintain remote object state;
-   manage contexts/pages;
-   dispatch events;
-   manage plugins (registration in MVP);
-   collect diagnostics (full tracing post-MVP, §36).

------------------------------------------------------------------------

## 5.5 Chromium Adapter

The Chromium Adapter encapsulates all CDP-specific implementation.

No other Eiwa Browser component SHALL depend directly on CDP.

``` text
Browser Engine
      │
      ▼
Chromium Adapter
      │
      ▼
CDP
      │
      ▼
Chromium
```

This isolation allows the engine to evolve independently of Chromium
internals.

------------------------------------------------------------------------

# 6. Browser Object Model

Naming convention (per `arest`): public Eiwa API SHALL use camelCase
(`newContext`, `newPage`, `addCookie`, `waitFor`, `onRequest`).
Exception: Prometheus-style metrics in §37 keep snake_case.

MVP scope (matches diagram): remote handles are `Browser`,
`BrowserContext`, `Page`, `Locator`. `Cookie`/`StorageState` are value
types used by `cookies()`/`addCookie()`/`storageState()`. `Download` is
an event payload (`download` event). `Frame` is post-MVP. The MVP method
subset is defined in §45; below is the full API.

The public object hierarchy SHALL be:

``` text
Browser
 └── BrowserContext
      ├── Page
      │    ├── Locator      (MVP)
      │    └── Frame        (post-MVP)
      │
      ├── Cookie            (value, MVP)
      ├── StorageState      (value, MVP)
      └── Download          (event payload, minimal in MVP)
```

## 6.1 Browser

Represents a Chromium process.

Operations:

``` text
launch()
connect(workers)
close()
contexts()
newContext()
version()
isConnected()
```

------------------------------------------------------------------------

## 6.2 BrowserContext

Represents an isolated browser session.

A context SHALL isolate:

-   cookies;
-   local storage;
-   session storage;
-   cache where applicable;
-   permissions;
-   authentication state.

Operations:

``` text
newPage()
pages()
cookies()
addCookie()
clearCookies()
storageState()
grantPermissions()
clearPermissions()
close()
```

------------------------------------------------------------------------

## 6.3 Page

Represents a browser tab.

Operations:

``` text
goto()
reload()
goBack()
goForward()
close()

click()
fill()
type()
press()
check()
uncheck()
selectOption()
uploadFile()   (post-MVP)

text()
innerText()
innerHtml()
content()
attribute()

evaluate()
screenshot()   (post-MVP)

waitFor()
waitForUrl()
waitForLoadState()

locator()
frame()        (post-MVP)
```

------------------------------------------------------------------------

# 7. Locator Model

Selectors SHALL be represented by a `Locator`.

Example:

``` eiwa
val processInput = page.locator("#process")
processInput.fill(processNumber)

page.locator("#search").click()

val result = page.locator(".process-result")
result.waitFor()
```

The locator API SHALL support at minimum:

``` text
CSS selector
XPath
text selector
role selector
attribute selector
```

Future locator strategies MAY include:

-   accessibility role;
-   label;
-   placeholder;
-   test identifier;
-   chained locators;
-   filtering;
-   nth element.

------------------------------------------------------------------------

# 8. Auto-Waiting

The Browser Engine SHOULD provide automatic waiting for common actions.

For example:

``` eiwa
page.locator("#submit").click()
```

SHOULD wait until the element is:

-   attached;
-   visible;
-   enabled;
-   actionable.

The API SHALL also expose explicit waits:

``` eiwa
page.waitFor("#result")
page.waitForUrl("**/result/**")
```

Timeouts SHALL be configurable.

------------------------------------------------------------------------

# 9. Navigation

Supported navigation operations:

``` eiwa
page.goto(url)
page.reload()
page.goBack()
page.goForward()
```

Navigation options SHALL include:

``` text
timeout
waitUntil
referer
```

Supported load states:

``` text
commit
domcontentloaded
load
networkidle
```

`networkidle` SHALL be treated as a heuristic, not a guarantee that an
application has completed all work.

------------------------------------------------------------------------

# 10. JavaScript Evaluation

The API SHALL support JavaScript execution inside the page:

``` eiwa
val title = page.evaluate("""
    () => document.title
""")
```

Evaluation SHALL support:

-   primitive return values;
-   JSON-compatible objects;
-   arrays;
-   serialized errors.

Remote DOM objects SHOULD NOT be exposed as arbitrary native Eiwa
objects unless explicitly modeled.

------------------------------------------------------------------------

# 11. Network API

The Browser Engine SHALL expose network events.

``` text
request
response
requestFailed
requestFinished
websocket
```

Example:

``` eiwa
page.onRequest { request ->
    log(request.url)
}

page.onResponse { response ->
    log(response.status)
}
```

Requests SHOULD expose:

``` text
url
method
headers
postData
resourceType
frame
```

Responses SHOULD expose:

``` text
url
status
headers
request
body()
```

------------------------------------------------------------------------

# 12. Request Interception

The API MAY allow authorized interception:

``` eiwa
page.route("**/api/**") { route ->
    route.continue()
}
```

Supported actions:

``` text
continue
abort
fulfill
```

This feature SHALL be explicitly permission-controlled for plugins.

------------------------------------------------------------------------

# 13. Cookies

Cookie model:

``` text
name
value
domain
path
expires
httpOnly
secure
sameSite
```

Example:

``` eiwa
context.addCookie(cookie)
val cookies = context.cookies()
```

------------------------------------------------------------------------

# 14. Storage State

The browser SHALL support exporting/importing authentication state where
permitted. Rule A: state travels as a value through the protocol; files
are app-side only.

Example:

``` eiwa
val state = context.storageState()
// `state` is a JSON-serializable value; the app persists it:
fs.write("state.json", state.toJson())

val ctx2 = browser.newContext(storageState: state)
```

A new context MAY be initialized from saved state.

Sensitive state SHALL never be logged by default.

------------------------------------------------------------------------

# 15. Downloads

Rule A: bytes travel through the protocol; who saves is the app. The
worker NEVER writes to app paths.

Pages SHALL expose download events. The event carries a handle; the app
fetches bytes and saves app-side:

``` eiwa
page.onDownload { download ->
    // download: downloadId, fileName, mime, size
    val bytes = download.bytes()   // small files, base64 inline
    fs.write("/tmp/document.pdf", bytes)
}
```

Large files use chunked fetch (`artifact.read { artifact, offset, size }`)
so the engine streams to the protocol without holding the whole file in
memory. The client `saveAs` is an app-side convenience, not a
worker-side path.

------------------------------------------------------------------------

# 16. Uploads (post-MVP)

Rule A mirrored: the app sends bytes; the engine materializes a
worker-side temp file for Chromium. No app path ever reaches the worker.

The API SHALL support:

``` eiwa
page.locator("input[type=file]").setInputFiles(
    name: "peticao.pdf",
    mime: "application/pdf",
    bytes: fileBytes
)
```

The implementation SHALL support:

-   single file;
-   multiple files;
-   file metadata;
-   stream-based upload where supported.

------------------------------------------------------------------------

# 17. Screenshots (post-MVP)

Rule A: `screenshot()` returns bytes; the app saves. No worker-side path.

The API SHALL support:

``` eiwa
val png = page.screenshot()
fs.write("page.png", png)
```

Options:

``` text
fullPage
quality
type
clip
```

Screenshots SHALL be usable as debugging artifacts.

------------------------------------------------------------------------

# 18. Events

The event system SHALL support at minimum:

``` text
pageCreated
pageClosed
navigation
request
response
requestFailed
console
dialog
download
websocket
popup
frameAttached
frameDetached
challengeDetected
```

Delivery (JSON-RPC notifications, §24.4):

-   events SHALL be delivered asynchronously and never block a command
    response;
-   order SHALL be FIFO per `page`;
-   the client SHOULD implicitly subscribe: the first local `onRequest`
    sends `page.subscribe("request")`; with no listener the engine MAY
    skip high-volume events (`request`, `response`, `console`);
-   on reconnect the client MUST resync via `contexts()`/`pages()`;
    events during the outage are lost;
-   backpressure: bounded buffer; `console`/`network` MAY be dropped
    under load, `download`/`dialog`/`popup`/`challengeDetected`
    MUST NOT.

------------------------------------------------------------------------

# 19. Challenge Detection (post-MVP)

The engine SHALL be able to report challenges without attempting to
defeat them. The core ships no solver and no evasion primitives.

Example:

``` text
ChallengeType
├── captcha
├── authenticationRequired
├── accessDenied
├── rateLimited
├── humanVerification
└── unknown
```

`unknown` means an unclassified blocking signal; the engine MUST attach
raw evidence (e.g. visible text snippet, HTTP status) so a plugin can
classify it.

Notification (JSON-RPC, §24.4):

``` json
{
  "jsonrpc": "2.0",
  "method": "page.challengeDetected",
  "params": {
    "challenge": "ch-9",
    "type": "captcha",
    "page": "page-7",
    "context": "ctx-3",
    "url": "https://example.com",
    "detectedAt": "2026-09-25T12:00:00Z"
  }
}
```

The default behavior SHALL be:

``` text
detect → pause page queue → notify → await authorized handling
```

-   with no `onChallenge` handler (or no `challenge` permission), the
    paused command fails fast with `ChallengeError` carrying the
    structured challenge object;
-   with a handler, the engine waits up to `challengeTimeout` for a
    decision, then resumes or aborts;
-   every detection and decision is logged and counted
    (`challenge_total`), without sensitive payloads.

The engine SHALL NOT include CAPTCHA bypass functionality.

------------------------------------------------------------------------

# 20. Plugin Architecture

Plugins are first-class extensions of Eiwa Browser.

``` text
                 Browser Engine
                       │
                Plugin Runtime
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Logger     Auth Plugin   Custom Plugin
       (MVP)      (future)      (future)
```

MVP: registration plus observe-only plugins (`NetworkLogger` on
`request/response/console`). `Auth`, `Captcha`/`challenge`, `Proxy`,
and custom command providers are future examples (post-MVP) — the
diagram shows the full vision.

Plugins MAY subscribe to:

``` text
navigation
request
response
console
download
challengeDetected
page lifecycle
browser lifecycle
```

Plugins MAY provide additional commands and events.

------------------------------------------------------------------------

# 21. Plugin API

Conceptual Eiwa API:

``` eiwa
plugin NetworkLogger

onRequest { request ->
    log(request.method)
    log(request.url)
}

onResponse { response ->
    log(response.status)
}
```

Challenge hook (post-MVP, requires `challenge` permission). The solver
lives in application code (e.g. `eiwa-court`), never in the core:

``` eiwa
plugin CourtCaptchaHandler

permissions {
    challenge
}

onChallenge { challenge ->
    // Eiwa code: enqueue for human operator or authorized provider,
    // suspend within challengeTimeout, then resume or abort.
    if (challenge.type == "captcha") {
        courtQueue.enqueue(challenge)
        challenge.awaitDecision()
    } else {
        challenge.abort("unsupported challenge")
    }
}
```

Application:

``` eiwa
browser.use(NetworkLogger)
browser.use(CourtCaptchaHandler)
```

Plugin lifecycle:

``` text
load
initialize
start
event handling
shutdown
unload
```

------------------------------------------------------------------------

# 22. Plugin Permissions

Plugins SHALL declare permissions.

Example:

``` eiwa
plugin MyPlugin

permissions {
    dom
    network
    storage
}
```

Initial permission classes:

``` text
dom
network
cookies
storage
filesystem
browserControl
process
challenge
```

`challenge` gates `onChallenge` and the `challenge.resolve/abort`
primitives. Without it the engine only reports and fails fast.

Plugins SHALL receive only explicitly granted capabilities.

------------------------------------------------------------------------

# 23. Plugin Isolation

The architecture SHOULD support two execution modes.

### In-process

``` text
Engine
 └── Plugin
```

Advantages:

-   low latency;
-   simple event handling.

Disadvantages:

-   lower isolation;
-   plugin crash can affect engine.

### Out-of-process

``` text
Engine
   │
   │ Plugin Protocol
   ▼
Plugin Worker
```

Advantages:

-   isolation;
-   independent lifecycle;
-   language independence.

The initial implementation MAY use in-process plugins, while keeping the
protocol compatible with future out-of-process plugins.

------------------------------------------------------------------------

# 24. Browser Protocol

The protocol SHALL be strict JSON-RPC 2.0 over a persistent bidirectional
connection. Either peer MAY send requests; events are notifications.

Protocol methods SHALL use `<object>.<camelCaseMethod>`
(e.g. `page.goto`, `page.goBack`, `context.newPage`, `context.addCookie`).
Event notifications SHALL use `<object>.<camelCaseEvent>`
(e.g. `page.navigated`, `page.request`, `page.response`).

## 24.1 Request (client → server)

``` json
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "page.goto",
  "params": {
    "page": "page-7",
    "url": "https://example.com"
  }
}
```

## 24.2 Success response (server → client)

``` json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "url": "https://example.com"
  }
}
```

## 24.3 Error response (server → client)

Standard JSON-RPC `code` (Int) plus Eiwa detail in `data.code`:

``` json
{
  "jsonrpc": "2.0",
  "id": 42,
  "error": {
    "code": -32603,
    "message": "Navigation timed out",
    "data": {
      "code": "TIMEOUT",
      "recoverable": true
    }
  }
}
```

Standard codes: `-32700` parse error, `-32600` invalid request,
`-32601` method not found, `-32602` invalid params, `-32603` internal
error. Eiwa error types (§33) map into `data.code`
(`TIMEOUT`, `NAVIGATION`, `SELECTOR`, `CHALLENGE`, ...).

## 24.4 Event (server → client notification, no `id`)

``` json
{
  "jsonrpc": "2.0",
  "method": "page.navigated",
  "params": {
    "page": "page-7",
    "context": "ctx-3",
    "url": "https://example.com"
  }
}
```

Every event `params` SHALL carry its owner (`page` and/or `context`,
plus `frame` when applicable) for client-side routing (§25).

## 24.5 Server → client request (e.g. route interception)

Used when the engine needs a client decision. The client MUST answer
with a matching `id`:

``` json
{
  "jsonrpc": "2.0",
  "id": 9001,
  "method": "route.paused",
  "params": {
    "route": "route-1",
    "page": "page-7",
    "url": "https://example.com/api/list"
  }
}
```

``` json
{
  "jsonrpc": "2.0",
  "id": 9001,
  "result": { "action": "continue" }
}
```

## 24.6 Cancellation

Either peer MAY cancel its own pending request with a notification:

``` json
{
  "jsonrpc": "2.0",
  "method": "cancel",
  "params": { "id": 42 }
}
```

The cancelled side SHOULD answer with `data.code: "CANCELLED"` when
practical and MUST NOT deliver a later `result` for that `id`.

Example flow:

``` text
c: { id: 42, method: "page.goto", params: { page: "page-7", ... } }
s: { method: "page.request", params: { page: "page-7", request: "req-1", ... } }
s: { method: "page.response", params: { page: "page-7", request: "req-1", status: 200 } }
s: { method: "page.navigated", params: { page: "page-7", url: "..." } }
s: { id: 42, result: { url: "..." } }
```

------------------------------------------------------------------------

# 25. Remote Object Identity

Remote objects SHALL have stable identifiers.

Example:

``` json
{
  "id": "page-7",
  "type": "Page"
}
```

The client SHALL maintain a local proxy.

Conceptually:

``` text
Eiwa Page object
      │
      │ page-7
      ▼
Browser Engine Page
```

This avoids serializing entire browser objects through every command.

------------------------------------------------------------------------

# 26. Protocol Versioning

Every connection SHALL negotiate a protocol version via `initialize`
(JSON-RPC request, like `arest` MCP).

Request:

``` json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocol": "eiwa-browser",
    "version": "1.0"
  }
}
```

Response:

``` json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocol": "eiwa-browser",
    "version": "1.0",
    "capabilities": [
      "browser",
      "context",
      "page",
      "network",
      "downloads",
      "plugins"
    ]
  }
}
```

Breaking changes SHALL increment the major version.

Backward-compatible additions SHOULD increment the minor version.

------------------------------------------------------------------------

# 27. Transport

## Primary transport

WebSocket with strict JSON-RPC 2.0. One JSON-RPC message per text
frame; binary frames are reserved for future artifact chunks.

Reasons:

-   bidirectional communication;
-   asynchronous events;
-   persistent connection;
-   low overhead;
-   works well between Docker containers;
-   works with remote browser workers.

## Local transport

Unix domain sockets MAY be supported with the same JSON-RPC framing
(newline-delimited JSON).

## Embedded transport

An in-process implementation MAY bypass serialization entirely.

------------------------------------------------------------------------

# 28. Browser Engine Process Model

Recommended deployment:

``` text
┌──────────────────────────────────────┐
│ Browser Worker Container              │
│                                      │
│ Eiwa Browser Engine                  │
│          │                           │
│          ├── Chromium #1             │
│          ├── Chromium #2             │
│          └── Chromium #3             │
│                                      │
└──────────────────────────────────────┘
```

The number of browser instances SHALL be configurable.

Each Chromium instance SHOULD have controlled resource limits.

------------------------------------------------------------------------

# 29. Docker

The official Browser Worker image SHALL contain:

``` text
Eiwa Browser Engine
Chromium
required fonts
required shared libraries
```

The image SHALL NOT require:

-   desktop environment;
-   X11 desktop session;
-   VNC;
-   physical display.

Headless execution SHALL be the default.

------------------------------------------------------------------------

# 30. Browser Worker API

A worker MAY expose:

``` text
ws://browser-worker:port
```

Example:

``` text
Eiwa Application
       │
       │ WebSocket (internal network)
       ▼
browser-worker
       │
       ▼
Chromium
```

The worker runs on a trusted internal network (no built-in auth).

## 30.1 Health

Read-only HTTP endpoint for K8s probes:

``` text
GET /health → 200 application/json
{
  "status": "ok",
  "protocol": "eiwa-browser",
  "version": "1.0",
  "browsers": 2,
  "contexts": 5
}
```

`status` is `ok` when the engine accepts new commands, `degraded`
otherwise. Used as liveness/readiness probe.

## 30.2 Pool and routing (client-owned)

-   the app configures worker URLs once (`Browser.connect(workers:)`);
    `Browser.launch()` is the single local worker shorthand;
-   the client keeps one persistent WebSocket per worker and picks the
    worker for each `newContext` alone — MVP: round-robin; full:
    least-loaded via §30.1;
-   afterwards everything of that context (`newPage`, commands, events)
    is pinned (sticky) to its worker until it dies;
-   a full worker rejects `newContext` (`RESOURCE_EXHAUSTED`); the client
    tries the next worker;
-   on socket drop the client marks that worker's contexts dead
    (`BrowserClosedError`), evicts it, and lets the app recreate —
    browser state never migrates.

## 30.3 Worker discovery (K8s)

Pod IPs are dynamic; the app never hardcodes them.

-   MVP: plain `Service` (`browser-worker:8080`, stable DNS). The client
    opens `poolSize` WebSockets against this single name; kube-proxy
    spreads each TCP to a different pod. Sticky holds per connection.
    Readiness uses §30.1 so unready pods leave the endpoint set.
    Config: `Browser.connect(workers: ["ws://browser-worker:8080"],
    poolSize: 8)`.
-   Full (post-MVP): headless `Service` (`clusterIP: None`). DNS returns
    one A-record per pod; the client re-resolves, keeps one WS per pod
    IP, and routes least-loaded via per-pod §30.1.
    Config: `discovery: dns("browser-worker-headless...")`.

------------------------------------------------------------------------

# 31. Concurrency

A single Browser process MAY host multiple contexts.

Example:

``` text
Chromium
├── Context A
│   ├── Page A1
│   └── Page A2
│
├── Context B
│   └── Page B1
│
└── Context C
    └── Page C1
```

Contexts SHALL remain isolated.

Concurrency limits SHALL be configurable.

------------------------------------------------------------------------

# 32. Resource Management

Every resource SHALL have explicit lifecycle methods.

``` eiwa
val browser = Browser.launch()

try
    val context = browser.newContext()

    try
        val page = context.newPage()
        ...
        page.close()
    finally
        context.close()
    end
finally
    browser.close()
end
```

The Eiwa language MAY later provide scoped-resource syntax to simplify
this.

------------------------------------------------------------------------

# 33. Error Model

Errors SHALL be structured.

Base:

``` text
BrowserError
```

Types:

``` text
ConnectionError
ProtocolError
BrowserLaunchError
NavigationError
TimeoutError
SelectorError
EvaluationError
NetworkError
DownloadError
PermissionError
ChallengeError
BrowserClosedError
```

`ChallengeError` SHALL contain a structured challenge object.

------------------------------------------------------------------------

# 34. Timeouts

Timeout categories:

``` text
defaultTimeout
navigationTimeout
actionTimeout
evaluationTimeout
downloadTimeout
challengeTimeout   (post-MVP, max wait for onChallenge decision)
```

Timeouts SHALL be configurable at:

``` text
Browser
Context
Page
Operation
```

Operation-level configuration SHALL override broader configuration.

------------------------------------------------------------------------

# 35. Logging

The engine SHALL provide structured logs.

Log levels:

``` text
trace
debug
info
warn
error
```

Sensitive values SHALL be redacted by default:

``` text
cookies
authorization headers
tokens
passwords
session identifiers
```

------------------------------------------------------------------------

# 36. Tracing

A tracing system SHOULD record:

``` text
navigation
commands
events
network metadata
timings
screenshots
errors
```

Trace artifacts MAY be stored as:

``` text
.zip
.json
.png
.har
```

------------------------------------------------------------------------

# 37. Observability

Metrics SHOULD include:

``` text
browser_launch_total
browser_crash_total
context_created_total
page_created_total
navigation_total
navigation_failure_total
request_total
response_total
challenge_total
plugin_error_total
command_latency
browser_memory
browser_cpu
```

------------------------------------------------------------------------

# 38. Security

The browser worker SHALL be treated as a privileged component.

Requirements:

-   trusted internal network only (no public endpoint);
-   container isolation;
-   filesystem restrictions;
-   configurable network restrictions;
-   secret redaction;
-   plugin permissions;
-   explicit proxy configuration;
-   no implicit credential persistence.

------------------------------------------------------------------------

# 39. Judicial Connector Architecture (out of scope, consumer-owned)

Eiwa Browser SHALL remain domain agnostic.

Judicial automation SHALL be implemented separately in the consumer
service (e.g. `eiwa-court`). Normalization, `Process Model`, and
PostgreSQL persistence (diagram flow steps 4-6) are NOT part of this
spec — Eiwa Browser returns page artifacts only (`text`, `content`,
`attribute`, `evaluate` results); the consumer normalizes and persists.

``` text
eiwa-court
├── core
├── connectors
│   ├── tjsp
│   ├── tjrj
│   ├── tjmg
│   └── ...
└── workers
```

A connector MAY choose HTTP or Browser automation.

``` text
CourtConnector
       │
       ├── HttpConnector
       │
       └── BrowserConnector
```

Example:

``` eiwa
connector TJSP

searchProcess(number) {
    // direct HTTP when possible
}
```

Another connector:

``` eiwa
connector TJXX

searchProcess(number) {
    val page = browser.newPage()
    ...
}
```

------------------------------------------------------------------------

# 40. HTTP-First Strategy (consumer decision)

The consumer (judicial system) SHALL prefer direct HTTP/API access when
an authorized interface is available. The HTTP-vs-Browser fallback
decision lives in the connector, not in Eiwa Browser.

Browser automation SHALL be used when:

-   no suitable direct interface exists;
-   the workflow genuinely requires browser execution;
-   the target permits the intended automation.

This minimizes:

-   CPU;
-   RAM;
-   latency;
-   operational complexity;
-   browser crashes.

------------------------------------------------------------------------

# 41. Scraping

Scraping means extracting structured information from a page.

Example:

``` text
HTML
 ↓
DOM
 ↓
Locator
 ↓
Structured Process
```

Eiwa Browser provides the browser primitives.

The judicial connector provides the extraction rules, plus all
normalization, `Process Model` mapping, and persistence outside this
spec.

------------------------------------------------------------------------

# 42. Crawling

Crawling means discovering and traversing pages/resources.

Eiwa Browser SHALL provide navigation primitives, while crawling
strategy remains application-level.

Example:

``` text
Process
 ├── movements
 ├── documents
 ├── related pages
 └── attachments
```

------------------------------------------------------------------------

# 43. Browser Automation

Automation means controlling the browser.

Examples:

``` eiwa
page.goto(url)
page.fill("#number", number)
page.click("#search")
page.waitFor(".result")
```

Automation is a capability of Eiwa Browser, not the judicial domain.

------------------------------------------------------------------------

# 44. Suggested Repository

``` text
eiwa-browser/
├── README.md
├── SPEC.md
├── LICENSE
│
├── protocol/
│   ├── schema/
│   ├── protocol.yaml
│   └── version
│
├── src/
│   ├── browser/
│   ├── context/
│   ├── page/
│   ├── locator/
│   ├── network/
│   ├── download/
│   ├── storage/
│   ├── plugins/
│   ├── protocol/
│   ├── chromium/
│   └── errors/
│
├── tests/
│   ├── protocol/
│   ├── browser/
│   ├── page/
│   ├── network/
│   └── plugins/
│
├── docker/
│   └── chromium/
│
└── examples/
    ├── basic.eiwa          (connect, newContext/newPage, goto, text, close)
    ├── scraping.eiwa       (locators, waitFor, evaluate)
    ├── network.eiwa        (onRequest/onResponse logging)
    └── court-example/      (reference consumer service: HTTP-first
        fallback, pool via Browser.connect, extraction +
        normalization outside the browser)
```

------------------------------------------------------------------------

# 45. Initial API (MVP)

The first release SHOULD implement only:

``` text
Browser
BrowserContext
Page
Locator

goto
reload
goBack
goForward

click
fill
type
press

text
content
attribute

waitFor
waitForUrl

evaluate

cookies
addCookie
storageState

request/response events
console events
download events

plugin registration (observe-only, e.g. NetworkLogger)
```

Out of MVP (post-MVP phases):

``` text
screenshot
challengeDetected event + ChallengeError + onChallenge
route/interception (page.route)
Auth/Captcha/Proxy plugin examples
tracing/metrics full
```

Avoid implementing the entire Playwright API initially.

------------------------------------------------------------------------

# 46. Example

``` eiwa
use browser

val browser = Browser.launch(
    headless: true
)

val context = browser.newContext()

val page = context.newPage()

page.goto("https://example.com")

page.locator("h1").waitFor()

val title = page.locator("h1").text()

print(title)

page.close()
context.close()
browser.close()
```

------------------------------------------------------------------------

# 47. Judicial Example

``` eiwa
use browser

connector TJExample

searchProcess(number) {
    val browser = Browser.launch(headless: true)
    val context = browser.newContext()

    try
        val page = context.newPage()

        page.goto("https://tribunal.example.gov")

        page.locator("#process-number")
            .fill(number)

        page.locator("#search")
            .click()

        page.waitFor(".process-result")

        return Process(
            number: page.locator(".number").text(),
            class: page.locator(".class").text(),
            subject: page.locator(".subject").text()
        )
    finally
        page.close()
        context.close()
        browser.close()
    end
}
```

------------------------------------------------------------------------

# 48. Plugin Example

``` eiwa
plugin NetworkLogger

onRequest { request ->
    log(
        method: request.method,
        url: request.url
    )
}

onResponse { response ->
    log(
        status: response.status,
        url: response.url
    )
}
```

Application:

``` eiwa
browser.use(NetworkLogger)
```

------------------------------------------------------------------------

# 49. Challenge Plugin Boundary (post-MVP)

The core exposes detection plus pause/resume primitives; solving is
application-owned (e.g. `eiwa-court`):

``` eiwa
onChallenge { challenge ->
    // challenge: id, type, page, context, url, detectedAt
    // challenge.awaitDecision() suspends within challengeTimeout
    // challenge.resolve() resumes the paused page queue
    // challenge.abort(reason) fails fast with ChallengeError
}
```

Rules:

-   the core detects, pauses the page queue, notifies, and awaits an
    authorized decision — it never solves, never spoofs fingerprints,
    never hides automation;
-   solver workflows (human operator queue, authorized provider, manual
    resolve then `resolve()`) live outside `eiwa-browser` and operate
    only where the target permits automation, under the site's rules
    and applicable law;
-   `onChallenge` requires the `challenge` permission and runs as a
    suspendable task (like `arest` `task(disp)`): it MUST NOT block the
    event dispatcher; exceeding `challengeTimeout` aborts with
    `ChallengeError`;
-   every detection/decision is audit-logged and metered.

The core SHALL NOT ship CAPTCHA bypass or anti-bot evasion
functionality.

------------------------------------------------------------------------

# 50. Relationship to Playwright

Eiwa Browser SHALL be conceptually comparable to Playwright:

``` text
Playwright
    │
    ├── Browser API
    ├── Context API
    ├── Page API
    ├── Locator API
    ├── Network API
    └── Browser protocol
```

Eiwa Browser:

``` text
Eiwa Browser
    │
    ├── Browser API
    ├── Context API
    ├── Page API
    ├── Locator API
    ├── Network API
    ├── Plugin API
    └── Eiwa Browser Protocol
```

Eiwa Browser SHALL NOT copy Playwright's implementation.

The API MAY be inspired by established browser automation concepts, but
the protocol and implementation SHALL be independently designed.

------------------------------------------------------------------------

# 51. Relationship to CDP

CDP SHALL be considered an implementation detail.

``` text
Eiwa Application
      │
Eiwa Browser API
      │
Eiwa Browser Protocol
      │
Browser Engine
      │
Chromium Adapter
      │
CDP
      │
Chromium
```

The Eiwa application SHALL never need to know that CDP is being used.

------------------------------------------------------------------------

# 52. Future Browser Engines

The architecture SHOULD allow:

``` text
Browser Engine
├── Chromium Adapter
├── Firefox Adapter
└── WebKit Adapter
```

The initial implementation SHALL target Chromium only.

------------------------------------------------------------------------

# 53. Recommended Implementation Phases

## Phase 1 --- Protocol

Implement:

-   command model;
-   response model;
-   event model;
-   errors;
-   remote object IDs;
-   WebSocket transport;
-   protocol versioning.

## Phase 2 --- Chromium Engine

Implement:

-   Chromium process lifecycle;
-   CDP connection;
-   Browser;
-   BrowserContext;
-   Page.

## Phase 3 --- Basic Automation

Implement:

-   navigation;
-   click;
-   fill;
-   keyboard;
-   selectors;
-   waits;
-   text extraction.

## Phase 4 --- Network

Implement:

-   request;
-   response;
-   interception;
-   WebSocket events.

## Phase 5 --- State

Implement:

-   cookies;
-   storage;
-   authentication state;
-   downloads;
-   uploads.

## Phase 6 --- Plugins

Implement:

-   plugin lifecycle;
-   events;
-   permissions;
-   plugin commands.

## Phase 7 --- Diagnostics

Implement:

-   screenshots;
-   tracing;
-   metrics;
-   structured logging.

## Phase 8 --- Production

Implement:

-   Docker image;
-   health checks (/health);
-   resource limits;
-   graceful shutdown;
-   Kubernetes deployment.

------------------------------------------------------------------------

# 54. Production Topology

Three services (diagram names). Connectors are pluggable modules inside
the Court Scraper Workers, not services. PostgreSQL is consumer-owned
context (out of browser scope, §39).

Recommended production topology:

``` text
                         ┌─────────────────────┐
                         │     API / Queue     │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ Court Scraper       │
                         │ Workers             │
                         │                     │
                         │ HTTP Connectors     │
                         │ Court Connectors    │
                         └──────────┬──────────┘
                                    │
                         Browser jobs only
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              Browser Worker  Browser Worker  Browser Worker
                    │               │               │
                 Chromium        Chromium        Chromium
                    │               │               │
                    ▼               ▼               ▼
                 Tribunal       Tribunal       Tribunal
```

HTTP-only workloads SHALL NOT require Chromium. Persisted results go to
the consumer's PostgreSQL (outside browser scope).

------------------------------------------------------------------------

# 55. Design Principles

The project SHALL follow these principles:

1.  **Browser is infrastructure, not business logic.**
2.  **HTTP/API first; browser when necessary.**
3.  **Chromium is an implementation dependency, not the public API.**
4.  **CDP is hidden behind the Chromium Adapter.**
5.  **The protocol is explicit and versioned.**
6.  **Remote objects use stable IDs.**
7.  **Events are first-class protocol messages.**
8.  **Plugins are first-class extensions.**
9.  **Plugins use explicit permissions.**
10. **Browser workers are disposable.**
11. **Headless execution is the default.**
12. **Containers are the default deployment unit.**
13. **The judicial domain stays outside Eiwa Browser.**
14. **Challenges are detected, not bypassed by the core.**
15. **The initial API remains intentionally small.**

------------------------------------------------------------------------

# 56. Final Architecture

``` text
                           Eiwa Ecosystem
                                 │
              ┌──────────────────┴──────────────────┐
              │                                     │
        Eiwa Court                              Other Apps
              │                                     │
      ┌───────┴────────┐                            │
      │                │                            │
 HTTP Connectors   Browser Connectors               │
      │                │                            │
      │                ▼                            │
      │          ┌──────────────┐                    │
      │          │ Eiwa Browser │                    │
      │          └──────┬───────┘                    │
      │                 │                            │
      │        Eiwa Browser Protocol                 │
      │                 │                            │
      │          ┌──────▼───────┐                    │
      │          │ Browser      │                    │
      │          │ Engine       │                    │
      │          └──────┬───────┘                    │
      │                 │                            │
      │          Chromium Adapter                    │
      │                 │                            │
      │                CDP                           │
      │                 │                            │
      │          ┌──────▼───────┐                    │
      │          │   Chromium   │                    │
      │          └──────┬───────┘                    │
      │                 │                            │
      └─────────────────┴────────────────────────────┘
                        │
                   Web / Internet
```

**Resultado esperado:** Eiwa Browser será uma infraestrutura de
automação web nativa do ecossistema Eiwa, comparável conceitualmente ao
Playwright, com protocolo próprio, Chromium headless, execução
containerizada, API Eiwa, rede/eventos, isolamento por contexto e um
sistema de plugins extensível.
