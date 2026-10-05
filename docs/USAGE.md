# Eiwa Browser — Usage Guide

Eiwa-native browser automation over JSON-RPC 2.0, in real Eiwa.
Untagged API exists and is tested; `[target]` is specified here and
lands per `docs/PLAN.md` Phase 9.

Conventions:

- imports are explicit: `import { x } from ".browser.y"`;
- methods live on handles (`Browser`, `BrowserContext`, `Page`,
  `Locator`) — never bare imported funs; wire builders
  (`gotoCmd`, `textCmd`, `cookiesCmd`, `css`, …) are internal;
- named args use `=`, not `:`; no `try/finally` — prefer `use`;
- provisioning failures throw (`NoWorkerAvailable`, `UnknownContext`);
- public API uses camelCase; Prometheus metrics keep snake_case.

## Quick Start

```eiwa
import { Browser, NoWorkerAvailable, UnknownContext } from ".browser.browser"
import { Log } from "std.log"
import { use } from "std.core"

fun main() {
    try {
        // workers, poolSize = 1, headless = true are the defaults.
        // Round-robin per newContext, sticky afterwards (§30.2).
        use(Browser(["ws://browser-worker:8080"], 8)) { browser ->
            val page = browser.newPage()            // private context by default
            page.goto("https://example.com")
            val title = page.locator("h1").text()
            Log.info { "headline: ${title}" }
        }
    } catch (e: NoWorkerAvailable | UnknownContext) {
        Log.error(e) { "browser provisioning failed" }
    }
}
```

`use` closes the browser at block end — including on exception —
draining every context and page (cascade). `headless = false` has no
display in MVP, so `newContext()` throws `NoWorkerAvailable`.

> Transport note: the pool above is routing state. Frames over the
> pinned worker WebSocket (`WorkerClient`, Phase 9) land next.

## Contexts and Pages

`browser.newContext(storageState = null): BrowserContext` mints a context pinned to one
worker. `ctx.newPage(): Page` mints a page under it.
`browser.newPage(ctx = null): Page` takes an optional context — omit
it for a page with a private context (reaped by `browser.close()`).

```eiwa
val ctxs = browser.contexts()   // List<BrowserContext>
val pages = ctx.pages()         // List<Page> under ctx
val worker = ctx.worker()       // pinned worker URL, String?
```

All three handles implement `Closeable`; prefer `use` over manual
`close`. Closing cascades remotely: `closePage`/`closeContext` send
their remote close frames first (best-effort), then drop local state;
`browser.close()` drains every context, then the sockets.

```eiwa
browser.version()      // worker protocol version, String? (null when unreachable)
browser.isConnected()  // any live worker socket, no I/O
```

## Navigation

Navigation runs on the page, over its pinned worker:

| Method (Page) | Params | Description |
|---------------|--------|-------------|
| `goto` | `url, waitUntil = "load", timeoutMs = 30000` | Navigate; `waitUntil`: `commit`, `domcontentloaded`, `load`, `networkidle` |
| `reload` | `timeoutMs = 30000` | Reload current page |
| `goBack` / `goForward` | `timeoutMs = 30000` | History travel |

```eiwa
page.goto("https://example.com")
page.goto("https://example.com", waitUntil = "networkidle", timeoutMs = 15000)
```

## Locators

`page.locator(raw)` [target] is the only constructor. The strategy is
auto-detected: `"xpath="`, `"text="`, `"role="` prefixes, `"//"` for
XPath, otherwise CSS (§7). It returns a `Locator` bound to the page,
serializing as `{"strategy", "selector"}` (`css`, `xpath`, `text`,
`role`):

```eiwa
page.locator("#search").fill("query")
page.locator("#search-button").click()
page.locator(".price").text()
page.locator("text=Buy").click()
page.locator("//h1").waitFor()
page.locator("role=button").click()
```

## Actions and Reading

Element actions run on the locator (auto-wait per §8); page-level
shortcuts take the locator explicitly:

| Method | Params | Description |
|--------|--------|-------------|
| `click` | `locator` / — | Click after auto-wait |
| `fill` | `locator, value` / `value` | Fill input (replace + `input`/`change`) |
| `typeText` | `locator, value` / `value` | Type keystrokes (append + `input`); `type` is an Eiwa keyword |
| `press` | `locator, key` / `key` | Press key (single char via `insertText`, named keys via key down/up) |
| `text` | `locator` / — | Visible text |
| `content` | — | Full HTML (`Page` only) |
| `attribute` | `locator, name` / `name` | Attribute value |
| `evaluate` | `script` | JS in page, JSON-compatible result (`Page` only) |
| `waitFor` | `selector, timeoutMs` / `timeoutMs` | Wait for selector (§8) |
| `waitForUrl` | `pattern, timeoutMs` | Wait for URL pattern (`Page` only, §8) |

```eiwa
page.goto("https://shop.example.com")
val price = page.locator(".price").text()
val title = page.evaluate("() => document.title")
page.waitFor(".product-detail")
page.waitForUrl("**/result/**")
```

## Cookies and Storage

Cookies and storage state live on the context:

```eiwa
val all = ctx.cookies()                    // List<Cookie>? (`null` on failure)
ctx.addCookie(Cookie("sid", "abc", "shop.example.com"))
ctx.clearCookies()
val state = ctx.storageState()             // JSON value; app persists it
val ctx2 = browser.newContext(state)       // applies the cookies
```

`Cookie(name, value, domain = "", path = "/", expires = 0,
httpOnly = false, secure = false, sameSite = "Lax")`. Rule A: state
travels as a value; files are app-side only (§§14–15). MVP state is
cookies-only (`origins` is always `[]`; localStorage needs
origin-by-origin injection — post-MVP).

## Network Observe

Observe-only in MVP (`route` interception is post-MVP). Subscribe on
the page — the client sends `page.subscribe` implicitly (§18) — or
once per browser via plugin. Callbacks fire on `poll()`:

```eiwa
page.onRequest { request ->
    Log.info { "${request.method} ${request.url}" }
}
page.onResponse { response ->
    Log.info { "${response.status} ${response.url}" }
}
browser.use(NetworkLogger.name(), NetworkLogger.topics())
browser.poll()
```

Payloads are `ObservedRequest` (`id`, `page`, `url`, `method`) and
`ObservedResponse` (`request`, `page`, `url`, `status`). Delivery is
poll-driven and eventually consistent: an event may land after the
dispatch that triggered it, so keep polling until the notes arrive
(`poll()` default 2000ms). Handler callbacks (`onRequest` etc.) live
on the handle you registered — re-listed pages are fresh objects.

## Downloads

Rule A: bytes travel through the protocol (base64url); the app saves.
Subscribe on the page; fetch bytes from the handle (chunked for large
files):

```eiwa
page.onDownload { download ->
    // download: downloadId, fileName, mime, size
    val bytes = download.bytes()   // small files, whole content
    fs.write("/tmp/document.pdf", bytes)
}
browser.poll()
```

`download.read(offset, size)` fetches chunks. Chromium saves to the
worker's temp dir and reports the exact path (`filePath`) on completion;
the engine streams those bytes back.

## Plugins

MVP is registration + observe-only (`NetworkLogger` on
`request`/`response`/`console`). `Auth`/`Captcha`/`Proxy`
providers are post-MVP. Subscribe pages before `use` (late pages
are not auto-subscribed).

```eiwa
browser.use(NetworkLogger.name(), NetworkLogger.topics())
browser.subscribed("NetworkLogger", "request")  // Bool
browser.unuse("NetworkLogger")                  // Bool
```

`challenge` permission enforcement lives at dispatch (post-MVP);
the core never solves or evades (§19).

## Timeouts

Every category defaults to 30000ms; most-specific scope wins —
Browser, Context, Page, then the operation itself (§34) [target]:

```eiwa
browser.setTimeout("navigationTimeout", 15000)
ctx.setTimeout("actionTimeout", 5000)
page.goto("https://example.com", timeoutMs = 10000)  // operation wins
```

Omit `timeoutMs` (or pass 0) to resolve scopes; an explicit positive
value always wins. Scopes live on the browser keyed by handle id, so
they survive re-listing pages and contexts. Navigation operations
(`goto`, `reload`, `goBack`, `goForward`, `waitForUrl`) resolve
`navigationTimeout`; waits resolve `actionTimeout`.

Categories: `defaultTimeout`, `navigationTimeout`, `actionTimeout`,
`evaluationTimeout`, `downloadTimeout` (`challengeTimeout` post-MVP).

## Errors

Structured errors mapped to standard JSON-RPC codes (`data.code`
carries the Eiwa code). Command failures throw the matching typed
error (§33):

| `data.code` | Meaning | Recoverable | Thrown as |
|-------------|---------|-------------|-----------|
| `TIMEOUT` | Operation timed out | true | `Timeout` |
| `CANCELLED` | Cancelled via `cancel` notification | false | `Cancelled` |
| `CHALLENGE` | Challenge detected (post-MVP handling) | false | `ChallengeDetected` |
| `BROWSER_CLOSED` | Worker/socket died | false | `WorkerClosed` |
| `RESOURCE_EXHAUSTED` | Worker full, try next | true | `ResourceExhausted` |

Unknown codes throw `UnknownBrowserError(code, detail)`. `null`
results stay reserved for transport failure (no reply); server-reported
failures always throw. Teardown (`closePage`/`closeContext`/`close`)
sends remote close frames best-effort and never throws: a dead worker
just drops local state.

## Running the Worker

```eiwa
// src/main.ei: serve PORT (default 8080)
```

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Worker TCP port | `8080` |
| `CHROMIUM_EXE` | Browser binary | `chromium` |
| `CHROMIUM_PORT` | DevTools port | `9333` |

`GET /health` → `200 application/json` with `status`, `protocol`,
`version`, `browsers`, `contexts` (K8s liveness/readiness, §30.1).

Docker: `docker build -t eiwac/browser-worker .` then
`docker run --rm -p 8080:8080 eiwac/browser-worker`
(multi-arch via release.yml).

## Scraping Pattern (consumer-owned)

Eiwa Browser returns page artifacts only; normalization, records and
persistence live in the consumer service (§§39–40: prefer HTTP first,
fall back to browser):

```eiwa
import { Browser, NoWorkerAvailable, UnknownContext } from ".browser.browser"
import { Log } from "std.log"
import { use } from "std.core"
import { httpGet } from ".browser.net.http"

fun searchProduct(sku: String): String {
    val http = httpGet("shop.example.com", 80, "/api/products/" + sku)
    if (http != null && http.status == 200) {
        return http.body
    }
    try {
        use(Browser(["ws://browser-worker:8080"], 8)) { browser ->
            val page = browser.newPage()
            page.goto("https://shop.example.com")
            return page.locator(".price").text()
        }
    } catch (e: NoWorkerAvailable | UnknownContext) {
        Log.error(e) { "browser provisioning failed" }
    }
    return ""
}
```

## Post-MVP (not in this guide's scope)

`screenshot()`, `page.route()` interception, `setInputFiles` bytes,
challenge detection/handling, tracing/metrics full, headless-service
DNS discovery, `Frame` objects, `check/uncheck/selectOption`,
`innerText/innerHtml/waitForLoadState`.
