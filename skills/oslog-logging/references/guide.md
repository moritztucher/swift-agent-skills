# Structured Logging & Observability on Apple Platforms

The unified logging system (`OSLog` / `Logger`), performance tracing with `OSSignposter`, and production telemetry with `MetricKit`. This guide is the deep API reference; the `SKILL.md` is the discipline layer.

The three layers map to three questions:

- **Logger / OSLog** — *what is my app doing right now, and what did it do leading up to a failure?* Structured, leveled, queryable event records.
- **OSSignposter** — *how long does this operation take, and where is the time going?* Performance intervals you measure in Instruments.
- **MetricKit** — *how is my app behaving in the field, across the whole install base?* Aggregated daily metrics plus crash/hang/disk diagnostics from real users.

---

## 1. Why not `print()`?

`print()` writes to stdout. In a shipping app that means:

- **It is invisible in production.** stdout is not captured by the system log, not retrievable from a user's device, not in a sysdiagnose. A crash report with `print()` "logging" gives you nothing.
- **It is unstructured.** No levels, no subsystem, no category, no timestamps you can rely on, no way to filter. You cannot ask "show me all networking errors in the last hour."
- **It has no privacy model.** Whatever you interpolate is dumped verbatim — including tokens, emails, and user content — to anyone who can read the console.
- **It is slow and synchronous.** String formatting happens eagerly even when nobody is listening. The unified log defers formatting and is designed for high-frequency use.
- **`NSLog` is no better.** It is the legacy bridge, synchronous, rate-limited, and writes to the same console with none of the structure. Treat both `print` and `NSLog` as banned in shipping code paths.

The unified logging system fixes all of this: messages are structured, leveled, persisted to a memory-and-disk ring buffer, privacy-aware by default, and retrievable from the field.

---

## 2. Logger setup — subsystem & category

`Logger` (the Swift API over `os_log`, iOS 14+/macOS 11+) is the modern entry point. Every logger carries a **subsystem** and a **category**.

```swift
import OSLog

let logger = Logger(subsystem: "com.example.myapp", category: "networking")
```

- **subsystem** — a reverse-DNS identifier for the whole app or a module. Use your bundle identifier (or a module-scoped variant like `com.example.myapp.payments`).
- **category** — a functional area within the subsystem: `networking`, `auth`, `persistence`, `ui`, `payments`. Categories are how you slice logs in Console.app and the `log` CLI, and they also group messages for performance.

**One logger per subsystem/category, not one global logger.** A common pattern is a namespaced factory so categories stay consistent:

```swift
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.myapp"

    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let auth       = Logger(subsystem: subsystem, category: "auth")
    static let ui         = Logger(subsystem: subsystem, category: "ui")
}

// usage
Logger.networking.error("Request failed: \(error.localizedDescription, privacy: .public)")
```

`Logger` is cheap to create and `Sendable`, but defining categories once keeps the namespace disciplined and lets you filter precisely.

### The legacy `os_log` and `OSLog`

Before `Logger` there was the C-style `os_log` function plus an `OSLog` object:

```swift
let log = OSLog(subsystem: "com.example.myapp", category: "networking")
os_log("Request failed: %{public}@", log: log, type: .error, error.localizedDescription)
```

This still works and is what you will see in older code. Differences vs. `Logger`:

- `os_log` uses C-style format specifiers (`%@`, `%d`, `%{public}@`) instead of Swift string interpolation.
- Privacy is expressed inside the format string (`%{public}s`, `%{private}d`) rather than as interpolation arguments.
- `Logger` gives you type-safe interpolation, the `privacy:`/`format:`/`align:` options, and reads far better.

Prefer `Logger` in all new code. Keep `os_log` only when interoperating with existing C/Objective-C logging or Metal shader logging (`os_log` is the only option in Metal Shading Language).

---

## 3. Log levels — and when to use each

The unified log defines five levels. They differ in **persistence** (whether the message is kept to disk) and **intent**. Choosing the right level is not cosmetic — it controls whether the message survives long enough to help you debug a field issue.

| Level | Method | Persisted to disk | Use for |
|---|---|---|---|
| Debug | `logger.debug(_:)` | **No** (memory only, often stripped) | High-volume developer-only tracing; values you only care about while attached to a debugger. |
| Info | `logger.info(_:)` | Only when collected with a log archive / under tooling | Helpful context that is not essential — request started, cache hit. Not persisted by default. |
| Notice (default) | `logger.notice(_:)` / `logger.log(_:)` | **Yes** | The default. Things worth keeping that aren't problems: lifecycle events, state transitions. |
| Error | `logger.error(_:)` | **Yes** | Errors the app can recover from — a failed request, a decode that fell back. |
| Fault | `logger.fault(_:)` | **Yes** | Bugs / programmer errors / unrecoverable conditions — a failed precondition, corrupt state. |

Key consequences:

- **`.debug` and `.info` are not persisted by default.** They live in an in-memory ring buffer and are dropped under memory pressure. If a user hits a bug and sends you a log, debug/info messages are usually *gone*. Anything you need post-hoc must be `.notice` or higher.
- `.debug` is the cheapest — formatting is skipped entirely when debug logging isn't enabled — so use it liberally for trace-level detail.
- Don't inflate levels to force persistence. A noisy `.error` log trains you to ignore errors. Use `.notice` for "keep this," `.error`/`.fault` for actual problems.

```swift
Logger.networking.debug("Sending \(request.httpMethod ?? "GET") to \(request.url?.path ?? "", privacy: .public)")
Logger.networking.notice("Sync completed: \(syncedCount, privacy: .public) items")
Logger.networking.error("Upload failed: \(error.localizedDescription, privacy: .public)")
Logger.networking.fault("Inconsistent cache state — expected token, found nil")
```

---

## 4. The privacy model — redaction by default

This is the single most important and most surprising part of the system.

**Dynamic values interpolated into a log message are redacted as `<private>` by default.** Static string literals are always shown; anything you interpolate at runtime is hidden unless you explicitly mark it `.public`.

```swift
let user = "alice@example.com"
logger.notice("Logged in user \(user)")
// Console shows: Logged in user <private>
```

Why: a log line could end up in a sysdiagnose, a shared screenshot, or a support ticket. Defaulting interpolated values to private means you don't leak PII just by logging.

### Privacy levels

| Privacy | Interpolation | Behavior |
|---|---|---|
| `.public` | `\(value, privacy: .public)` | Shown verbatim. Use only for non-sensitive values you need to read. |
| `.private` | `\(value, privacy: .private)` (default for dynamic values) | Redacted as `<private>` in logs collected off-device; visible when debugging on a connected device with the right entitlement. |
| `.sensitive` | `\(value, privacy: .sensitive)` | Stronger than private — for high-sensitivity data (auth material). Redacted even in more contexts. |

You can also **hash** a private value so you can correlate occurrences without revealing it:

```swift
logger.notice("Auth for account \(accountID, privacy: .private(mask: .hash))")
// Console shows a stable hash, so you can tell "same account" without seeing the ID
```

### Rules of thumb

- **Never `.public` for PII.** Emails, names, tokens, device IDs, file paths containing usernames, precise location — keep these `.private` (the default) or `.sensitive`. Marking them `.public` is a privacy leak that ships to every device.
- **Do `.public` the things that make logs useful and aren't sensitive:** error descriptions, HTTP status codes, enum/state names, counts, durations, feature flags. Without `.public` your production logs are a wall of `<private>` and tell you nothing.
- **Static text is always visible.** `logger.error("Decode failed")` shows fully. You only need `privacy:` on interpolated values.
- Default numbers/Bool/enums are also treated as private when dynamic — mark counts and codes `.public` deliberately.

### Formatting and alignment

Interpolation also supports `format:` and `align:` for readable, columnar logs:

```swift
logger.notice("Latency \(ms, format: .fixed(precision: 2), privacy: .public) ms")
logger.notice("HTTP \(statusCode, format: .decimal, align: .right(columns: 3), privacy: .public)")
```

---

## 5. Viewing logs

Three ways to read what you logged, in increasing order of automation.

### Console.app (live + saved)

- Open Console.app, select the device/simulator, hit Start.
- Filter by subsystem (`subsystem:com.example.myapp`) and category.
- **By default Console hides debug/info and metadata.** Enable "Include Info Messages" and "Include Debug Messages" in the Action menu, otherwise you'll think your logs vanished.
- Redacted values appear as `<private>`; connect the device and trust it (and use a debug build) to see private values during development.

### The `log` command-line tool (macOS)

```bash
# Stream live
log stream --predicate 'subsystem == "com.example.myapp"' --level debug

# Pull historical logs from the persisted store
log show --predicate 'subsystem == "com.example.myapp" AND category == "networking"' --last 1h --info --debug
```

`--info`/`--debug` are required to include those levels; without them you only get notice and above (which is also why those levels matter for field debugging).

### `OSLogStore` — read your own logs in-app

`OSLogStore` (iOS 15+/macOS 12+) lets the app read back the persisted log store programmatically — useful for an in-app "export diagnostics" feature or attaching recent logs to a bug report.

```swift
import OSLog

func recentLogs(since: Date) throws -> [String] {
    let store = try OSLogStore(scope: .currentProcessIdentifier)
    let position = store.position(date: since)
    let entries = try store.getEntries(at: position)

    return entries
        .compactMap { $0 as? OSLogEntryLog }
        .filter { $0.subsystem == "com.example.myapp" }
        .map { "[\($0.date)] [\($0.category)] \($0.composedMessage)" }
}
```

Notes:

- `.currentProcessIdentifier` reads only this process's logs without special entitlement. Reading the system-wide store (`.system`) requires elevated privileges and is generally not available to App Store apps.
- Only persisted entries are returned — debug/info that has aged out won't be there.
- `getEntries` is synchronous and can be slow over a large window; do it off the main thread and bound the time range.

---

## 6. Performance tracing with `OSSignposter`

Logging answers "what happened." Signposts answer "how long did it take." `OSSignposter` (iOS 15+/macOS 12+, the modern replacement for the `os_signpost` function) emits **intervals** that show up as regions in Instruments' timeline, aligned with CPU, allocations, and everything else Instruments captures.

**Use signposts, not manual timestamps.** `Date()`/`CFAbsoluteTimeGetCurrent()` subtraction gives you a number with no context — you can't see it on a timeline, can't correlate it with system activity, and you pay formatting/log overhead. Signposts are nearly free when no Instruments tool is recording and integrate with the profiling timeline.

### Intervals

```swift
import OSLog

let signposter = OSSignposter(subsystem: "com.example.myapp", category: "performance")

func loadFeed() async throws -> [Item] {
    let state = signposter.beginInterval("Load Feed", id: signposter.makeSignpostID())
    defer { signposter.endInterval("Load Feed", state) }

    let data = try await fetch()
    return try decode(data)
}
```

- `beginInterval` returns an `OSSignpostIntervalState` token that you must pass to the matching `endInterval`. The token is what links the two ends — so concurrent intervals with the same name don't get confused.
- Always end the interval. `defer` is the safe pattern so early returns and thrown errors still close it.
- The interval **name must be a static string** (it's the signpost name Instruments groups by); put dynamic data in the message arguments instead.

For concurrent or overlapping work, give each interval its own ID:

```swift
let id = signposter.makeSignpostID()
let state = signposter.beginInterval("Decode Image", id: id, "size: \(bytes)")
// ... work ...
signposter.endInterval("Decode Image", state)
```

### One-shot events and the convenience wrapper

```swift
// A point-in-time event (no duration)
signposter.emitEvent("Cache Miss", "key: \(key)")

// Closure form that begins/ends automatically and returns the result
let items = try signposter.withIntervalSignpost("Load Feed") {
    try loadSynchronously()
}
```

### Seeing it

Run the app from Instruments with the **os_signpost** (or **Points of Interest**) instrument, or any time-profile template. Your named intervals appear as labeled regions. This is the right tool for "this screen feels slow" — you instrument the suspect path, record, and read the durations against system activity rather than guessing.

---

## 7. Production telemetry with MetricKit

`Logger` and signposts are for *you* during development and on individual devices. **MetricKit** is the field layer: the system aggregates power, performance, and stability data across your real install base and hands it to your app in **daily payloads**, plus **diagnostic payloads** for crashes, hangs, and other faults.

### Subscribing

Conform to `MXMetricManagerSubscriber` and register against the shared manager early in app launch:

```swift
import MetricKit

final class MetricsMonitor: NSObject, MXMetricManagerSubscriber {

    func startReceiving() {
        MXMetricManager.shared.add(self)
    }

    func stopReceiving() {
        MXMetricManager.shared.remove(self)
    }

    // Daily aggregated metrics — delivered roughly once per day.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let data = payload.jsonRepresentation() as Data? else { continue }
            upload(data, endpoint: .metrics)   // send to your backend / store locally
        }
    }

    // Diagnostics (crashes, hangs, disk writes, CPU exceptions) — iOS 14+.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            upload(payload.jsonRepresentation(), endpoint: .diagnostics)
        }
    }
}
```

Register the subscriber in `application(_:didFinishLaunchingWithOptions:)` or `App.init`. The manager holds a weak reference, so keep your subscriber alive for the app lifetime.

### What you get

**`MXMetricPayload`** (daily, aggregated over ~24h, delivered at next launch):

- `applicationLaunchMetrics` — launch time, resume time (`MXAppLaunchMetric`).
- `applicationResponsivenessMetrics` — hang rate (`MXAppResponsivenessMetric`).
- `cpuMetrics`, `memoryMetrics`, `gpuMetrics` — resource consumption.
- `displayMetrics`, `locationActivityMetrics`, `networkTransferMetrics`.
- `diskIOMetrics`, `applicationTimeMetrics`, `cellularConditionMetrics`.
- `signpostMetrics` (`MXSignpostMetric`) — **your own `OSSignposter` intervals, aggregated across users.** This is how signposts you defined in section 6 become field data: tag intervals you care about and MetricKit reports their distribution from real devices.
- Histograms (e.g. launch-time distribution) rather than single values — you see the population, not one device.

**`MXDiagnosticPayload`** (delivered as soon as available after the next launch, iOS 14+):

- `crashDiagnostics` (`MXCrashDiagnostic`) — call stack, exception type/code, termination reason.
- `hangDiagnostics` (`MXHangDiagnostic`) — main-thread stalls with the blocking call stack.
- `diskWriteExceptionDiagnostics` (`MXDiskWriteExceptionDiagnostic`) — excessive disk writes.
- `cpuExceptionDiagnostics` (`MXCPUExceptionDiagnostic`) — runaway CPU.
- Each diagnostic carries a `callStackTree` you can symbolicate, plus `MetaData` (app version, OS version, device type, region).

### Timing and expectations

- **Payloads arrive in the background, not in real time.** Metric payloads come roughly **once per 24 hours**, delivered to your app at a convenient time (typically the next launch). Diagnostics arrive sooner but still asynchronously — never on the code path that produced them. Do not expect to see a crash "as it happens." MetricKit is aggregate fleet telemetry, not a live crash reporter.
- The simulator does not generate real payloads. In Xcode, use **Debug ▸ Simulate MetricKit Payloads** to exercise your handler with synthetic data.
- Payloads are JSON-serializable (`jsonRepresentation()`) — persist or upload them to your own backend; MetricKit itself stores nothing for you.
- This complements, not replaces, a crash reporter. MetricKit crash diagnostics are first-party and privacy-respecting but sampled/delayed; many teams pair it with a third-party SDK for immediate symbolicated crashes.

---

## 8. Putting the three layers together

A realistic setup:

1. **Logger** everywhere, with disciplined subsystem/category namespacing and correct levels. `.notice`+ for anything you'd want after a field failure, `.debug` for trace detail. Everything dynamic stays private unless deliberately `.public`, and never `.public` for PII.
2. **OSSignposter** around the operations whose latency matters (launch, first meaningful paint, sync, expensive decodes). Profile them in Instruments during development.
3. **MetricKit** subscribed at launch, payloads uploaded to your backend. The signpost intervals from step 2 show up here as `signpostMetrics`, so the same instrumentation that helped you profile locally now reports its distribution across all users — and crashes/hangs arrive as diagnostics.

The throughline: structured, leveled, privacy-aware data on the device; named intervals for latency; aggregated field telemetry for the fleet. No `print()`, no manual timestamps, no cached unstructured dumps.

---

## 9. Quick reference

| Need | API | Min OS |
|---|---|---|
| Structured logging (Swift) | `Logger(subsystem:category:)` | iOS 14 / macOS 11 |
| Legacy / C / Metal logging | `os_log(_:log:type:)`, `OSLog` | iOS 10 / macOS 10.12 |
| Log levels | `.debug` `.info` `.notice`/`.log` `.error` `.fault` | — |
| Privacy | `\(x, privacy: .public/.private/.sensitive)`, `.private(mask: .hash)` | iOS 14 |
| Format / align | `\(x, format:, align:, privacy:)` | iOS 14 |
| Read logs in-app | `OSLogStore(scope:)`, `getEntries(at:)`, `OSLogEntryLog` | iOS 15 / macOS 12 |
| Read logs (CLI) | `log stream`, `log show --predicate` | macOS |
| Performance intervals | `OSSignposter`, `beginInterval`/`endInterval`, `emitEvent`, `withIntervalSignpost` | iOS 15 / macOS 12 |
| Field metrics | `MXMetricManager.shared.add(_:)`, `MXMetricPayload`, `didReceive(_:[MXMetricPayload])` | iOS 13 |
| Field diagnostics | `MXDiagnosticPayload`, `MXCrashDiagnostic`/`MXHangDiagnostic`/`MXDiskWriteExceptionDiagnostic`, `didReceive(_:[MXDiagnosticPayload])` | iOS 14 |
| Signposts as field data | `MXSignpostMetric` in `signpostMetrics` | iOS 14 |

Sources: Apple Developer documentation for `os` (OSLog/Logger), `OSSignposter`, and `MetricKit` (`/websites/developer_apple`), verified 2026-06-02.
