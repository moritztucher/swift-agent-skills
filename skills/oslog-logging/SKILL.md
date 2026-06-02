---
name: oslog-logging
description: Structured logging and observability on Apple platforms — the unified log (OSLog/Logger), performance tracing with OSSignposter, and field telemetry with MetricKit. Use when the user mentions logging, OSLog, Logger, os_log, structured logging, log levels, removing print() / print cleanup, signpost, OSSignposter, performance intervals, Instruments timing, MetricKit, MXMetricPayload, MXDiagnosticPayload, observability, diagnostics, or crash/hang metrics.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple)
---

# OSLog Logging & Observability

Structured logging, performance tracing, and production telemetry on Apple platforms — three layers: `Logger`/`OSLog` (what happened), `OSSignposter` (how long it took), `MetricKit` (how the fleet behaves). The full API reference — setup, levels, the privacy model, viewing logs, signpost intervals, MetricKit payloads — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `LEVEL` — `notice-baseline` (default; `.notice`+ for anything you'd want after a field failure, `.debug`/`.info` for dev-only trace) · `debug-verbose` (heavy `.debug` tracing while actively debugging a path) · `errors-only` (terse libraries/hot paths — only `.error`/`.fault`).
2. `PRIVACY` — `default-private` (default; every interpolated value is `<private>`, you opt specific non-PII values into `.public`) · `explicit-public` (a logging subsystem where most values are deliberately `.public` — still never PII).
3. `SIGNALS` — `logs` (Logger only) · `logs+signposts` (add `OSSignposter` intervals for latency-sensitive paths) · `logs+metrickit` (also subscribe to MetricKit for field metrics + crash/hang diagnostics).

## When to use

Adding, reviewing, or cleaning up any logging, performance instrumentation, or production-observability code on Apple platforms — including ripping out `print()`/`NSLog`, choosing log levels, getting the privacy redaction right, timing a slow path, or wiring up MetricKit. If the task is purely reading logs for a bug (not writing logging code), this still applies for the `OSLogStore` / `log` CLI section.

## Core rules

- **`Logger`, not `print`/`NSLog`.** `Logger(subsystem:category:)` (iOS 14+) for all new code. `os_log`/`OSLog` only for legacy C/Objective-C interop or Metal shader logging.
- **One logger per subsystem/category, not one global `Logger`.** Subsystem = reverse-DNS app/module id; category = functional area (`networking`, `auth`). Define them once (a `Logger` extension) so filtering stays precise.
- **Dynamic values are redacted by default.** Interpolated values log as `<private>` unless marked `.public`. Mark non-sensitive values `.public` deliberately so logs are useful; never `.public` for PII (use the default `.private`, or `.sensitive`).
- **Level controls persistence.** `.debug`/`.info` are not persisted to disk by default and are gone after a field failure. Anything you need post-hoc must be `.notice` or higher.
- **Signposts for latency, not timestamps.** `OSSignposter` intervals, profiled in Instruments — not `Date()` subtraction.
- **MetricKit is fleet telemetry, not a live crash reporter.** Subscribe at launch; payloads arrive in the background (~daily), not in real time.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "`print()` is fine, I'll grep stdout." | stdout is invisible in production — not in the system log, not in a sysdiagnose, not retrievable from a user's device. A field failure logged with `print()` gives you nothing. Use `Logger`. |
| "I'll log the email so I can see who hit the bug — interpolation just works." | Interpolated values are redacted as `<private>` by default. To read it you'd mark it `.public` — which ships a PII leak to every device. Keep PII `.private`/`.sensitive`; `.public` only non-sensitive values (status codes, counts, error descriptions). |
| "One global `logger` everywhere is simpler." | Then everything lands in one category and you can't filter networking from auth in Console or the `log` CLI. One `Logger` per subsystem/category; define them once in an extension. |
| "I logged it at `.debug`, it'll be there when the user reports the bug." | `.debug` and `.info` are not persisted to disk — they live in a memory ring buffer and are dropped. Console even hides them unless you opt in. Anything needed after the fact must be `.notice`+. |
| "I'll just wrap the slow call in `Date()` start/end and log the delta." | That number has no timeline context and you pay log overhead. Use `OSSignposter.beginInterval`/`endInterval` (close it in `defer`) and read it in Instruments — and it shows up in MetricKit `signpostMetrics` across users. |
| "MetricKit is subscribed, so I'll see crashes live." | Payloads are delivered in the background, roughly once per 24h (diagnostics sooner but still async, never on the failing code path). It's aggregated fleet telemetry, not a real-time crash feed — use Xcode's Simulate MetricKit Payloads to test the handler. |

## Verification gate

Before shipping logging/observability code, confirm every line:

- [ ] No `print()` / `NSLog` in shipping code paths — all replaced by `Logger`.
- [ ] Loggers are per-subsystem/category (defined once), not a single global logger.
- [ ] Every interpolated value's privacy is intentional: PII stays `.private`/`.sensitive`; only non-sensitive values are `.public`. No PII marked `.public`.
- [ ] Levels are correct: anything needed after a field failure is `.notice`+; `.debug`/`.info` used only for dev-only trace (and known to be non-persisted).
- [ ] `OSSignposter` intervals (if any) are closed on every path (`defer`), use static names, and were verified in Instruments — no `Date()`-based timing.
- [ ] MetricKit (if used) is subscribed via `MXMetricManager.shared.add(_:)` at launch, both `didReceive` overloads implemented, payloads persisted/uploaded, and the handler tested via Simulate MetricKit Payloads.

## Deep reference

`references/guide.md` — why not `print()`, `Logger` setup, all five levels and when to use each, the privacy/redaction model, viewing logs (Console.app / `OSLogStore` / `log` CLI), `OSSignposter` intervals and events, the full MetricKit section (subscribing, `MXMetricPayload`/`MXDiagnosticPayload` types, timing), and a quick-reference table of key types and minimum OS versions. Load it for any concrete API question.
