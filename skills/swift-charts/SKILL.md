---
name: swift-charts
description: Build and review data visualizations with Apple's Swift Charts — Chart, marks (BarMark/LineMark/PointMark/AreaMark/SectorMark/RuleMark/RectangleMark), axes and scales, legends, interactivity/selection, scrolling, and Chart3D/SurfacePlot on iOS 26. Use when the user mentions Swift Charts, chart, graph, plot, data visualization, BarMark, LineMark, pie/donut chart, or Chart3D. For general SwiftUI layout, state, and view composition use the `swiftui-pro` skill instead.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple)
---

# Swift Charts

Declarative data visualization for Apple platforms. The deep API reference — every 2D mark type, plottable values, styling, axis/scale customization, legends and annotations, interactivity, and the iOS 26 `Chart3D`/`SurfacePlot` story — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics. For everything around the chart (layout, state, navigation, view composition), use `swiftui-pro`.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `MARK` — the primitive that matches the data's meaning: `bar` (category comparison) · `line`/`area` (trend over time) · `point` (distribution/correlation) · `sector` (part-of-whole pie/donut) · `rule`/`rectangle` (reference lines, heatmaps). Pick by data shape, not by what looks nice.
2. `SERIES` — `single` (one mark, one color) · `grouped` (multiple categories distinguished by `.foregroundStyle(by:)`, optionally `.position(by:)` for side-by-side) · `stacked` (same with stacking, the default for repeated x). Driving color *by value* is what generates the legend.
3. `INTERACTION` — `static` (display only) · `selection` (`.chartXSelection`/`.chartYSelection`/`.chartAngleSelection`, iOS 17+) · `scrolling` (`.chartScrollableAxes` + `.chartXVisibleDomain`, iOS 17+). Don't reach for raw gestures when a selection modifier exists.

## When to use

Building or reviewing any chart, graph, plot, or data-visualization view that uses the `Charts` framework — marks, axes, scales, legends, selection, scrolling, or 3D. If the work is general SwiftUI (layout, navigation, `@State`, view modeling) with no `Charts` import, use `swiftui-pro`.

## Core rules

- 2D charts: iOS 16+. `SectorMark`, selection modifiers, and scrolling: iOS 17+. `Chart3D`/`SurfacePlot`: iOS 26+. Gate accordingly; iOS 26 is the default target.
- Data plotted with `Chart(data) { ... }` must be `Identifiable`; values passed to `.value(_:_:)` must be `Plottable` (`Int`/`Double`/`Float`/`String`/`Date` are built in — custom enums conform via `primitivePlottable`).
- One axis-encoding per concept: map the categorical/temporal dimension to x or y, the magnitude to the other, and any third dimension to color/symbol/size — don't fake a series with manual per-mark colors.
- Let the framework do the work: automatic axes, automatic legend (from `by:`), automatic scaling. Customize only when the default is wrong, and keep `references/guide.md` open for the exact modifier.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll color each bar manually so the categories look different." | Manual `.foregroundStyle(.blue)` per mark produces no legend and breaks accessibility grouping. Use `.foregroundStyle(by: .value("Category", x))` — that's what generates the legend and the data dimension. |
| "It works with 50 rows, so it'll work with 50,000." | Swift Charts renders every mark; thousands of points stutter and the axis becomes unreadable. Downsample/aggregate (bucket by day, average, decimate) before plotting, and use `.chartScrollableAxes` + `.chartXVisibleDomain` for long ranges. |
| "Dates are just strings on the axis." | Plotting dates as `String` kills temporal spacing and ordering. Plot the `Date` itself and set the axis unit with `AxisMarks(values: .stride(by: .month))` + a `.dateTime` format, so spacing reflects real time. |
| "I'll add a `DragGesture` in `.chartOverlay` to detect taps." | For selecting a value or range, use `.chartXSelection`/`.chartYSelection`/`.chartAngleSelection` (iOS 17+) — it's accessible, handles hit-testing, and binds straight to state. Reserve `.chartOverlay` + `proxy` for genuinely custom interactions. |
| "The chart is one view, so one `.accessibilityLabel` is enough." | A single label makes the whole chart one opaque element for VoiceOver. Give marks `.accessibilityLabel`/`.accessibilityValue` per data point so each is individually navigable and announces its value. |
| "3D looks more impressive, I'll use `Chart3D`." | `Chart3D` is for data that's genuinely 3-dimensional or where *shape* matters more than exact values. When precise reading matters or the data is 2D, a flat chart reads better — don't trade legibility for spectacle. |

## Verification gate

Before shipping a chart, confirm every line:

- [ ] Data is `Identifiable`; every `.value(_:_:)` argument is `Plottable` (no stringified numbers/dates).
- [ ] Mark type matches the data's meaning (the `MARK` dial), not aesthetics.
- [ ] Multi-series uses `.foregroundStyle(by:)` (+ `.position(by:)` for grouped) so the legend is generated automatically — no hand-assigned per-mark colors faking a series.
- [ ] Temporal data is plotted as `Date` with an appropriate axis stride/unit; quantitative axes have sensible domains (`.chartXScale`/`.chartYScale`).
- [ ] Interaction uses the right modifier: `.chartXSelection`/`.chartYSelection`/`.chartAngleSelection` for selection, `.chartScrollableAxes` + `.chartXVisibleDomain` for scrolling — gestures only for truly custom needs.
- [ ] Large datasets are aggregated/downsampled before plotting; long ranges scroll rather than cram.
- [ ] Accessibility: per-mark `.accessibilityLabel`/`.accessibilityValue`, plus an empty-state (`ContentUnavailableView`) when there's no data.
- [ ] Availability gates correct: `SectorMark`/selection/scrolling iOS 17+, `Chart3D`/`SurfacePlot` iOS 26+.

## Deep reference

`references/guide.md` — full coverage of basic charts, all 2D mark types, plottable values and custom `Plottable`, styling, axis/scale/grid customization, legends and annotations, interactivity (selection, range, overlay, scrolling), `Chart3D`, `SurfacePlot`, best practices, and a quick-reference of marks and modifiers. Load it for any concrete API question.
