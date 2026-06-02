# Swift Charts Framework Guide

A comprehensive guide for using Apple's Swift Charts framework for data visualization in iOS 16+ and the new Chart3D in iOS 26+.

---

## Table of Contents

1. [Overview](#overview)
2. [Basic Charts](#basic-charts)
3. [Mark Types](#mark-types)
4. [Data and Plottable Values](#data-and-plottable-values)
5. [Styling Charts](#styling-charts)
6. [Axis Configuration](#axis-configuration)
7. [Legends and Annotations](#legends-and-annotations)
8. [Interactivity](#interactivity)
9. [Chart3D (iOS 26+)](#chart3d-ios-26)
10. [SurfacePlot](#surfaceplot)
11. [Best Practices](#best-practices)

---

## Overview

Swift Charts is Apple's declarative framework for creating beautiful, accessible charts in SwiftUI.

### Requirements

- **2D Charts**: iOS 16+, macOS 13+, watchOS 9+, tvOS 16+
- **3D Charts**: iOS 26+, macOS 26+, visionOS 26+

### Import

```swift
import Charts
```

---

## Basic Charts

### Minimal Chart

```swift
import Charts
import SwiftUI

struct SalesData: Identifiable {
    let id = UUID()
    let month: String
    let revenue: Double
}

let sales = [
    SalesData(month: "Jan", revenue: 1200),
    SalesData(month: "Feb", revenue: 1800),
    SalesData(month: "Mar", revenue: 2400)
]

struct SalesChart: View {
    var body: some View {
        Chart(sales) { item in
            BarMark(
                x: .value("Month", item.month),
                y: .value("Revenue", item.revenue)
            )
        }
    }
}
```

### Chart with ForEach

```swift
Chart {
    ForEach(sales) { item in
        BarMark(
            x: .value("Month", item.month),
            y: .value("Revenue", item.revenue)
        )
    }
}
```

### Multiple Data Series

```swift
struct SeriesData: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let series: String
}

Chart(data) { item in
    BarMark(
        x: .value("Category", item.category),
        y: .value("Value", item.value)
    )
    .foregroundStyle(by: .value("Series", item.series))
}
```

---

## Mark Types

### BarMark

Vertical or horizontal bars:

```swift
// Vertical bars (default)
BarMark(
    x: .value("Category", item.category),
    y: .value("Value", item.value)
)

// Horizontal bars
BarMark(
    x: .value("Value", item.value),
    y: .value("Category", item.category)
)

// Stacked bars
Chart(data) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Sales", item.sales)
    )
    .foregroundStyle(by: .value("Product", item.product))
}

// Grouped bars
Chart(data) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Sales", item.sales)
    )
    .foregroundStyle(by: .value("Product", item.product))
    .position(by: .value("Product", item.product))
}

// Bar width
BarMark(...)
    .cornerRadius(4)
```

### LineMark

Line charts:

```swift
// Basic line
LineMark(
    x: .value("Date", item.date),
    y: .value("Value", item.value)
)

// With interpolation
LineMark(...)
    .interpolationMethod(.catmullRom)

// With symbols
LineMark(...)
    .symbol(by: .value("Category", item.category))

// Line width
LineMark(...)
    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
```

### AreaMark

Filled area charts:

```swift
// Basic area
AreaMark(
    x: .value("Date", item.date),
    y: .value("Value", item.value)
)

// Range area (min to max)
AreaMark(
    x: .value("Date", item.date),
    yStart: .value("Min", item.min),
    yEnd: .value("Max", item.max)
)

// Stacked areas
Chart(data) { item in
    AreaMark(
        x: .value("Date", item.date),
        y: .value("Value", item.value)
    )
    .foregroundStyle(by: .value("Category", item.category))
}

// Gradient fill
AreaMark(...)
    .foregroundStyle(
        .linearGradient(
            colors: [.blue.opacity(0.5), .blue.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
```

### PointMark

Scatter plots:

```swift
// Basic points
PointMark(
    x: .value("X", item.x),
    y: .value("Y", item.y)
)

// With symbol shape
PointMark(...)
    .symbol(.circle)  // .square, .triangle, .diamond, .cross, .plus

// Symbol size
PointMark(...)
    .symbolSize(100)

// Size by value
PointMark(...)
    .symbolSize(by: .value("Size", item.size))
```

### RuleMark

Reference lines:

```swift
// Horizontal rule
RuleMark(y: .value("Average", average))
    .foregroundStyle(.red)
    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

// Vertical rule
RuleMark(x: .value("Target Date", targetDate))

// Range rule
RuleMark(
    xStart: .value("Start", start),
    xEnd: .value("End", end),
    y: .value("Category", category)
)

// With annotation
RuleMark(y: .value("Goal", goal))
    .annotation(position: .top, alignment: .leading) {
        Text("Goal: \(goal)")
            .font(.caption)
    }
```

### RectangleMark

Rectangular marks for heatmaps:

```swift
RectangleMark(
    x: .value("Day", item.day),
    y: .value("Hour", item.hour)
)
.foregroundStyle(by: .value("Value", item.value))
```

### SectorMark (iOS 17+)

Pie and donut charts:

```swift
// Pie chart
Chart(data) { item in
    SectorMark(
        angle: .value("Value", item.value)
    )
    .foregroundStyle(by: .value("Category", item.category))
}

// Donut chart
Chart(data) { item in
    SectorMark(
        angle: .value("Value", item.value),
        innerRadius: .ratio(0.5)
    )
    .foregroundStyle(by: .value("Category", item.category))
}

// With corner radius
SectorMark(...)
    .cornerRadius(4)

// Angular inset
SectorMark(
    angle: .value("Value", item.value),
    angularInset: 1.5
)
```

---

## Data and Plottable Values

### PlottableValue

```swift
// Quantitative (numbers)
.value("Sales", 1200)
.value("Revenue", item.revenue)

// Nominal (categories)
.value("Category", "Electronics")
.value("Product", item.productName)

// Temporal (dates)
.value("Date", item.date)
.value("Time", Date.now)
```

### Supported Data Types

| Type | Usage |
|------|-------|
| `Int`, `Double`, `Float` | Quantitative values |
| `String` | Categorical values |
| `Date` | Temporal values |
| Enums with `Plottable` | Custom categories |

### Custom Plottable

```swift
enum ProductCategory: String, Plottable {
    case electronics = "Electronics"
    case clothing = "Clothing"
    case food = "Food"

    var primitivePlottable: String { rawValue }
}
```

---

## Styling Charts

### Foreground Style

```swift
// Single color
BarMark(...)
    .foregroundStyle(.blue)

// By category
BarMark(...)
    .foregroundStyle(by: .value("Category", item.category))

// Gradient
BarMark(...)
    .foregroundStyle(
        .linearGradient(
            colors: [.blue, .purple],
            startPoint: .bottom,
            endPoint: .top
        )
    )
```

### Chart Colors

```swift
Chart(data) { ... }
    .chartForegroundStyleScale([
        "Category A": .blue,
        "Category B": .green,
        "Category C": .orange
    ])
```

### Opacity

```swift
BarMark(...)
    .opacity(0.7)
```

### Corner Radius

```swift
BarMark(...)
    .cornerRadius(8)

// Specific corners
BarMark(...)
    .cornerRadius(8, style: .continuous)
```

---

## Axis Configuration

### Axis Labels

```swift
Chart(data) { ... }
    .chartXAxisLabel("Month")
    .chartYAxisLabel("Revenue ($)")

// Positioned label
.chartXAxisLabel("Month", position: .bottom, alignment: .center)
```

### Axis Scale

```swift
// Fixed domain
.chartXScale(domain: 0...100)
.chartYScale(domain: ["A", "B", "C"])

// Date domain
.chartXScale(domain: startDate...endDate)

// Scale type
.chartYScale(domain: 1...1000, type: .log)
```

### Axis Visibility

```swift
.chartXAxis(.hidden)
.chartYAxis(.visible)
```

### Custom Axis

```swift
.chartXAxis {
    AxisMarks(values: .stride(by: .month)) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel(format: .dateTime.month(.abbreviated))
    }
}

.chartYAxis {
    AxisMarks(position: .leading) { value in
        AxisGridLine()
        AxisValueLabel {
            if let intValue = value.as(Int.self) {
                Text("$\(intValue)")
            }
        }
    }
}
```

### Grid Lines

```swift
.chartXAxis {
    AxisMarks { _ in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
            .foregroundStyle(.gray.opacity(0.5))
    }
}
```

---

## Legends and Annotations

### Legend

```swift
// Automatic legend
Chart(data) { item in
    BarMark(...)
        .foregroundStyle(by: .value("Category", item.category))
}

// Hide legend
.chartLegend(.hidden)

// Legend position
.chartLegend(position: .bottom, alignment: .center)
```

### Annotations

```swift
// On mark
BarMark(...)
    .annotation {
        Text("\(item.value)")
            .font(.caption)
    }

// Positioned annotation
BarMark(...)
    .annotation(position: .top, alignment: .center) {
        Text("\(item.value, format: .number)")
    }

// Annotation with background
.annotation(position: .overlay) {
    Text(item.label)
        .font(.caption2)
        .padding(4)
        .background(.ultraThinMaterial)
        .cornerRadius(4)
}
```

---

## Interactivity

### Chart Selection

```swift
struct InteractiveChart: View {
    @State private var selectedElement: SalesData?

    var body: some View {
        Chart(sales) { item in
            BarMark(
                x: .value("Month", item.month),
                y: .value("Revenue", item.revenue)
            )
            .opacity(selectedElement == nil || selectedElement?.id == item.id ? 1 : 0.3)
        }
        .chartXSelection(value: $selectedElement)
    }
}
```

### Range Selection

```swift
@State private var selectedRange: ClosedRange<Date>?

Chart(data) { ... }
    .chartXSelection(range: $selectedRange)
```

### Chart Overlay for Custom Interaction

```swift
Chart(data) { ... }
    .chartOverlay { proxy in
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                            if let date: Date = proxy.value(atX: x) {
                                // Handle date selection
                            }
                        }
                )
        }
    }
```

### Scrollable Charts (iOS 17+)

```swift
Chart(data) { ... }
    .chartScrollableAxes(.horizontal)
    .chartXVisibleDomain(length: 7 * 24 * 60 * 60)  // 7 days in seconds
```

---

## Chart3D (iOS 26+)

### Basic 3D Chart

```swift
import Charts

struct DataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let z: Double
    let category: String
}

Chart3D(dataPoints) { point in
    PointMark(
        x: .value("X", point.x),
        y: .value("Y", point.y),
        z: .value("Z", point.z)
    )
}
```

### 3D PointMark Styling

```swift
Chart3D(data) { item in
    PointMark(
        x: .value("X", item.x),
        y: .value("Y", item.y),
        z: .value("Z", item.z)
    )
    .foregroundStyle(by: .value("Category", item.category))
    .symbol(.cube)        // .sphere, .cylinder, .cone, .cube
    .symbolSize(0.05)
}
```

### Symbol Shapes (3D)

| Symbol | Description |
|--------|-------------|
| `.sphere` | Default spherical marker |
| `.cube` | Cubic marker |
| `.cylinder` | Cylindrical marker |
| `.cone` | Conical marker |

### Z-Axis Scale

```swift
Chart3D(data) { ... }
    .chartXScale(domain: 0...100, range: -1.5...1.5)
    .chartYScale(domain: 0...50, range: -0.5...0.5)
    .chartZScale(domain: 0...100, range: -0.5...0.5)  // New in iOS 26
```

### Axis Labels (3D)

```swift
private let xLabel = "Length (cm)"
private let yLabel = "Width (cm)"
private let zLabel = "Height (cm)"

Chart3D(data) { ... }
    .chartXAxisLabel(xLabel)
    .chartYAxisLabel(yLabel)
    .chartZAxisLabel(zLabel)
```

### Chart3DPose

Control the viewing angle:

```swift
// Predefined poses
Chart3D(data) { ... }
    .chart3DPose(.front)   // .default, .front, .back, .left, .right

// Custom pose
Chart3D(data) { ... }
    .chart3DPose(Chart3DPose(
        azimuth: .degrees(20),     // Left-right rotation
        inclination: .degrees(7)   // Up-down tilt
    ))

// Interactive rotation with binding
@State private var pose = Chart3DPose(
    azimuth: .degrees(0),
    inclination: .degrees(20)
)

Chart3D(data) { ... }
    .chart3DPose($pose)  // Users can drag to rotate
```

### Camera Projection

```swift
// Orthographic (default) - consistent size regardless of depth
Chart3D(data) { ... }
    .chart3DCameraProjection(.orthographic)

// Perspective - emphasizes depth
Chart3D(data) { ... }
    .chart3DCameraProjection(.perspective)
```

### Combining 3D Marks

```swift
Chart3D {
    ForEach(dataPoints) { point in
        PointMark(
            x: .value("X", point.x),
            y: .value("Y", point.y),
            z: .value("Z", point.z)
        )
        .foregroundStyle(by: .value("Category", point.category))
    }

    // Add a reference surface
    SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
        regressionModel(x, z)
    }
    .foregroundStyle(.gray.opacity(0.5))
}
```

---

## SurfacePlot

SurfacePlot visualizes mathematical functions in 3D.

### Basic Surface

```swift
Chart3D {
    SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
        x * z  // Simple multiplication surface
    }
}
```

### Mathematical Functions

```swift
// Sine wave surface
SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
    sin(x) * cos(z)
}

// Trigonometric surface
SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
    (sin(5 * x) + sin(5 * z)) / 2
}

// Gaussian surface
SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
    exp(-(x * x + z * z) / 2)
}
```

### Regression Model

```swift
SurfacePlot(x: "Feature A", y: "Prediction", z: "Feature B") { a, b in
    linearRegression(featureA: a, featureB: b)
}
```

### Surface Styling

```swift
// Gradient coloring
SurfacePlot(...)
    .foregroundStyle(
        LinearGradient(
            colors: [.blue, .green, .yellow, .red],
            startPoint: .bottom,
            endPoint: .top
        )
    )

// Height-based coloring
SurfacePlot(...)
    .foregroundStyle(.heightBased)

// Normal-based coloring (lighting effect)
SurfacePlot(...)
    .foregroundStyle(.normalBased)

// Elliptical gradient
SurfacePlot(...)
    .foregroundStyle(
        EllipticalGradient(
            colors: [.red, .orange, .yellow, .green, .blue]
        )
    )
```

### Combined Data and Surface

```swift
Chart3D {
    // Scatter plot of actual data
    ForEach(measurements) { point in
        PointMark(
            x: .value("X", point.x),
            y: .value("Y", point.y),
            z: .value("Z", point.z)
        )
        .foregroundStyle(.blue)
    }

    // Regression surface
    SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
        predictedValue(x: x, z: z)
    }
    .foregroundStyle(.orange.opacity(0.6))
}
```

---

## Best Practices

### 1. Choose the Right Chart Type

| Data Type | Recommended Chart |
|-----------|-------------------|
| Categories comparison | BarMark |
| Trends over time | LineMark, AreaMark |
| Distribution | PointMark (scatter) |
| Part of whole | SectorMark (pie/donut) |
| Correlation | PointMark with two variables |
| 3D spatial data | Chart3D with PointMark |
| Mathematical surfaces | SurfacePlot |

### 2. Keep Charts Simple

```swift
// GOOD - Clear and focused
Chart(sales) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Revenue", item.revenue)
    )
}
.chartYAxisLabel("Revenue ($)")

// AVOID - Too cluttered
Chart(sales) { item in
    BarMark(...)
        .annotation { Text("\(item.revenue)") }
        .foregroundStyle(...)
}
.chartXAxis { /* complex axis */ }
.chartYAxis { /* complex axis */ }
.chartLegend { /* custom legend */ }
// ... many more modifiers
```

### 3. Use Meaningful Colors

```swift
// Define semantic color mapping
.chartForegroundStyleScale([
    "Profit": .green,
    "Loss": .red,
    "Neutral": .gray
])
```

### 4. Handle Empty States

```swift
if data.isEmpty {
    ContentUnavailableView(
        "No Data",
        systemImage: "chart.bar",
        description: Text("Add some data to see the chart")
    )
} else {
    Chart(data) { ... }
}
```

### 5. Optimize for Accessibility

```swift
Chart(data) { item in
    BarMark(...)
}
.accessibilityLabel("Sales Chart")
.accessibilityValue("Shows monthly revenue for \(data.count) months")
```

### 6. Use 3D Charts Appropriately

> "3D charts work great when the shape of the data is more important than the exact values."

Use Chart3D when:
- Data is naturally 3-dimensional (spatial coordinates)
- Showing surface relationships
- Building visionOS apps
- Shape matters more than precise values

Avoid Chart3D when:
- Precise value reading is critical
- Data is fundamentally 2D
- Screen space is limited

---

## Quick Reference

### 2D Mark Types

| Mark | Usage |
|------|-------|
| `BarMark` | Bar charts |
| `LineMark` | Line charts |
| `AreaMark` | Area charts |
| `PointMark` | Scatter plots |
| `RuleMark` | Reference lines |
| `RectangleMark` | Heatmaps |
| `SectorMark` | Pie/donut charts |

### 3D Mark Types (iOS 26+)

| Mark | Usage |
|------|-------|
| `PointMark` (with z) | 3D scatter plots |
| `SurfacePlot` | Mathematical surfaces |

### Common Modifiers

```swift
// Styling
.foregroundStyle(.blue)
.foregroundStyle(by: .value("Category", category))
.opacity(0.8)
.cornerRadius(4)

// 2D Scales
.chartXScale(domain: 0...100)
.chartYScale(domain: ["A", "B", "C"])

// 3D Scales (iOS 26+)
.chartZScale(domain: 0...50)

// Axes
.chartXAxis(.hidden)
.chartXAxisLabel("Label")
.chartYAxis { AxisMarks() }

// Legend
.chartLegend(.hidden)
.chartLegend(position: .bottom)

// 3D Specific (iOS 26+)
.chart3DPose(.front)
.chart3DCameraProjection(.perspective)
```

---

## Resources

- [Swift Charts | Apple Developer Documentation](https://developer.apple.com/documentation/charts)
- [Chart3D | Apple Developer Documentation](https://developer.apple.com/documentation/charts/chart3d)
- [Bring Swift Charts to the third dimension - WWDC25](https://developer.apple.com/videos/play/wwdc2025/313/)
- [Hello Swift Charts - WWDC22](https://developer.apple.com/videos/play/wwdc2022/10136/)
