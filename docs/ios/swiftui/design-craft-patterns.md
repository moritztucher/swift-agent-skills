# Design Craft Pattern Library

Reference library of concrete SwiftUI techniques for each design lever, extracted from 4 fully-realized theme explorations (Military, Forge, Athletic, Minimal). All themes render **identical data** (day 23/66, 5 habits, 34-day streak, 2.0x multiplier) with radically different personalities.

Use this document when generating design options, evaluating designs, or prescribing elevation opportunities. Every technique below is proven SwiftUI — not theoretical.

---

## Lever 1: Typography as Identity

### Techniques

**Monospaced technical personality:**
```swift
.font(.system(size: 13, weight: .bold, design: .monospaced))
.tracking(2)  // Letter spacing for military precision
```
Used in: Military theme — ALL labels, codes, status text. The entire UI reads like a terminal.

**Extreme weight as focal point:**
```swift
// Ultra-light = quiet confidence (Minimal)
.font(.system(size: 180, weight: .ultraLight))
.monospacedDigit()

// Black weight = aggressive energy (Forge, Athletic)
.font(.system(size: 100, weight: .black))
.font(.system(size: 120, weight: .black))
```

**Baseline-aligned compound numbers:**
```swift
HStack(alignment: .firstTextBaseline, spacing: 4) {
    Text("23")
        .font(.system(size: 120, weight: .black))
        .foregroundStyle(.white)
    VStack(alignment: .leading) {
        Text("/66")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.gray)
    }
}
```
Used in: Athletic theme — the day number and denominator feel like a sports scoreboard.

**Case as personality signal:**
- ALL-CAPS + tracking = commanding (Military: `"MISSION DAY"`, `"DAILY OBJECTIVES"`)
- lowercase + light weight = understated (Minimal: `"day"`, `"streak"`, `"multiplier"`)
- Title case + black weight = energetic (Forge: `"FORGING YOUR DISCIPLINE"`)

**Scale contrast ratio:**
- Military: 80pt day / 12pt labels = 6.7:1
- Forge: 100pt day / 12pt labels = 8.3:1
- Athletic: 120pt day / 11pt labels = 10.9:1
- Minimal: 180pt day / 14pt labels = 12.9:1

Higher ratio = more dramatic hierarchy. Award-level designs typically exceed 6:1.

---

## Lever 2: Color as Narrative

### Techniques

**Role-based color system (3 colors, 3 meanings):**
```swift
private let accentGreen = Color(red: 0.4, green: 0.8, blue: 0.4)   // active/complete
private let warningAmber = Color(red: 1.0, green: 0.75, blue: 0.0)  // rank/progress
private let dangerRed = Color(red: 0.9, green: 0.2, blue: 0.2)      // danger/urgent
```
Used in: Military — every color communicates status. No decorative color.

**Gradient as metaphor:**
```swift
private let fireGradient = LinearGradient(
    colors: [
        Color(red: 1.0, green: 0.4, blue: 0.0),  // ember
        Color(red: 1.0, green: 0.6, blue: 0.0),  // flame
        Color(red: 1.0, green: 0.8, blue: 0.2)   // heat
    ],
    startPoint: .bottom, endPoint: .top
)

// Applied to text — gradient fills the number
Text("23")
    .font(.system(size: 100, weight: .black))
    .foregroundStyle(fireGradient)
```
Used in: Forge — the gradient IS the brand. Applied to numbers, progress bars, and streak icons.

**Single ownable accent:**
```swift
private let accentColor = Color(red: 0.0, green: 0.8, blue: 1.0) // electric cyan
```
Used in: Athletic — cyan is the ONLY non-gray color. Everything else is white/gray/black.

**No accent (white only):**
```swift
.foregroundStyle(.white)          // completed items
.foregroundStyle(.gray)           // labels
.foregroundStyle(Color.white.opacity(0.4))  // pending items
```
Used in: Minimal — restraint IS the color strategy. Zero accent color.

**Ambient glow via RadialGradient:**
```swift
RadialGradient(
    colors: [emberColor.opacity(0.3), Color.clear],
    center: .bottom,
    startRadius: 0,
    endRadius: 400
)
```
Used in: Forge — subtle ember glow at bottom of screen. Sets mood without being literal.

**Color-as-state on background:**
```swift
.background(completed ? accentGreen.opacity(0.1) : Color.white.opacity(0.03))
```
Used in: Military, Forge, Athletic — completed items have a tinted background. The state change is visible before reading the text.

### Dark vs Light Mode Considerations

All color techniques above assume a DARK background (#000000 - #1A1A1A). On light backgrounds:
- **RadialGradient ambient glow:** use darker tones with higher opacity (0.1-0.2), not lighter tones
- **Color-as-state background tinting:** increase opacity from 0.1 to 0.15-0.2 for visibility
- **Materials** (ultraThinMaterial, thinMaterial): **avoid entirely** — they become invisible on light backgrounds. Use solid colors with opacity instead.
- **Accent colors:** may need reduced saturation on white backgrounds to avoid harshness
- **Fire/glow gradients:** replace shadow glow with inner shadow or overlay gradient; outer glows are invisible on light backgrounds

**Critical:** Always verify that `.preferredColorScheme()` is set to match the design system's intended mode. Every technique in this library was designed for a specific background context. A dark-mode design running in light mode produces invisible gray-on-gray rendering.

---

## Lever 3: Vocabulary as Design

### Word Choices by Personality

| Concept | Military | Forge | Athletic | Minimal |
|---------|----------|-------|----------|---------|
| Day label | `"MISSION DAY"` | `"DAY"` | (no label — number speaks) | `"day"` |
| Denominator | `"OF 66"` | `"35% COMPLETE"` | `"/66"` | `"of 66"` |
| Habits section | `"DAILY OBJECTIVES"` | `"TODAY'S FORGE"` | `"TODAY'S PROTOCOL"` | (no section header) |
| Habit done | `"[COMPLETE]"` | `"FORGED"` | `"DONE"` | (filled dot) |
| Habit pending | `"[PENDING]"` | (no label) | (no label) | (empty dot) |
| Streak | `"CURRENT RANK: SERGEANT"` | `"FLAME STREAK"` | `"PERFORMANCE SCORE"` | `"streak"` |
| Multiplier | `"2.0x MULTIPLIER"` | `"HEAT LEVEL"` | `"MULTI"` | `"multiplier"` |
| CTA | `"CONTINUE MISSION"` | (no CTA) | (no CTA) | (no CTA) |
| Habit codes | `"OBJ-01"`, `"OBJ-02"` | (none) | (none) | (none) |
| Bracket style | `[COMPLETE]`, `[PENDING]` | (none) | (none) | (none) |

### Principles

- The vocabulary should be **internally consistent** — Military uses brackets, codes, and status language everywhere, not just in one place.
- The vocabulary should **reinforce the metaphor** — Forge never breaks character to say "completed", it says "FORGED".
- The vocabulary should be **proportional to personality** — Minimal barely speaks. The absence of labels IS the design.
- Vocabulary is a **zero-cost lever** — no custom views, no complex code. Just different strings.

---

## Lever 4: Data Visualization as Personality

### Progress Bars

**Thin rectangle (Military):**
```swift
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        Rectangle()
            .fill(Color.white.opacity(0.1))
        Rectangle()
            .fill(accentGreen)
            .frame(width: geometry.size.width * (23.0 / 66.0))
    }
}
.frame(height: 4)
```

**Molten capsule with glow (Forge):**
```swift
ZStack(alignment: .leading) {
    Capsule()
        .fill(ashGray.opacity(0.5))
        .frame(height: 8)
    Capsule()
        .fill(fireGradient)
        .frame(width: 200 * (23.0 / 66.0), height: 8)
        .shadow(color: emberColor, radius: 4)
}
```

**Minimal line (Minimal):**
```swift
Rectangle()
    .fill(Color.white.opacity(0.2))
    .frame(width: 60, height: 1)
```
Between "of 66" and "35%" — the progress indicator is almost invisible.

### Gauges

**Heat gauge — segmented temperature scale (Forge):**
```swift
HStack(spacing: 4) {
    ForEach(0..<10, id: \.self) { index in
        RoundedRectangle(cornerRadius: 2)
            .fill(index < 6 ? heatColor(for: index) : ashGray.opacity(0.3))
            .frame(height: 24)
    }
}

// Color mapped to temperature position
private func heatColor(for index: Int) -> Color {
    let colors: [Color] = [
        Color(red: 0.3, green: 0.0, blue: 0.0),  // Dark red
        Color(red: 0.6, green: 0.0, blue: 0.0),  // Red
        // ... through to
        Color.white                                // White hot
    ]
    return colors[index]
}
```

**Circular trim gauge (Athletic):**
```swift
ZStack {
    Circle()
        .stroke(Color.white.opacity(0.1), lineWidth: 6)
        .frame(width: 80, height: 80)
    Circle()
        .trim(from: 0, to: 0.85)
        .stroke(accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        .frame(width: 80, height: 80)
        .rotationEffect(.degrees(-90))
    VStack(spacing: 0) {
        Text("85").font(.system(size: 24, weight: .black))
        Text("SCORE").font(.system(size: 8, weight: .bold))
    }
}
```

### Stat Layouts

**Stat row with dividers (Athletic):**
```swift
HStack(spacing: 0) {
    statItem(value: "34", unit: "DAYS", label: "STREAK")
    Divider().background(Color.white.opacity(0.2)).frame(height: 50)
    statItem(value: "2.0", unit: "x", label: "MULTI")
    Divider().background(Color.white.opacity(0.2)).frame(height: 50)
    statItem(value: "91", unit: "%", label: "RATE")
}
```

**Rank card with metadata (Military):**
```swift
HStack(spacing: 16) {
    rankBadge      // Custom Path chevrons
    VStack(alignment: .leading, spacing: 4) {
        Text("CURRENT RANK").font(.system(size: 10, weight: .medium, design: .monospaced))
        Text("SERGEANT").font(.system(size: 18, weight: .black, design: .monospaced))
        Text("34 day streak - 9 days to Captain").font(.system(size: 11, design: .monospaced))
    }
}
```

---

## Lever 5: Status Indicators as Signature

### Checkbox Variants

**Square military checkbox:**
```swift
ZStack {
    Rectangle()
        .stroke(completed ? accentGreen : Color.white.opacity(0.3), lineWidth: 2)
        .frame(width: 20, height: 20)
    if completed {
        Rectangle()
            .fill(accentGreen)
            .frame(width: 12, height: 12)
    }
}
```

**Rounded checkbox with checkmark (Athletic):**
```swift
ZStack {
    RoundedRectangle(cornerRadius: 4)
        .stroke(completed ? accentColor : Color.white.opacity(0.2), lineWidth: 2)
        .frame(width: 24, height: 24)
    if completed {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(accentColor)
    }
}
```

**Flame icon replacement (Forge):**
```swift
Image(systemName: completed ? "flame.fill" : icon)  // icon = original habit icon
    .foregroundStyle(completed ? emberColor : .gray)
    .shadow(color: completed ? emberColor.opacity(0.8) : .clear, radius: completed ? 4 : 0)
```
The original habit icon is REPLACED by a flame when completed. The entire icon changes meaning.

**8pt dot — filled vs stroked (Minimal):**
```swift
if completed {
    Circle()
        .fill(Color.white)
        .frame(width: 8, height: 8)
} else {
    Circle()
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
        .frame(width: 8, height: 8)
}
```
The smallest possible indicator. Personality through extreme restraint.

### Completion Labels

- Military: `"[COMPLETE]"` / `"[PENDING]"` in 9pt monospaced
- Forge: `"FORGED"` in capsule badge with tinted background
- Athletic: `"DONE"` in 10pt black weight
- Minimal: no text — the dot is enough

### Live Status Indicators

**Protocol active dot (Military):**
```swift
HStack(spacing: 6) {
    Circle()
        .fill(accentGreen)
        .frame(width: 8, height: 8)
    Text("PROTOCOL ACTIVE")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(accentGreen)
}
```

---

## Lever 6: Motion & Animation as Personality

### Breathing / Pulsing

**Ember glow breathing (Forge):**
```swift
@State private var flameAnimation = false

// Glow offset moves up/down
.offset(y: flameAnimation ? -5 : 5)

// Shadow radius pulses
.shadow(color: emberColor, radius: flameAnimation ? 20 : 10)

// Scale pulses
.scaleEffect(flameAnimation ? 1.1 : 0.9)

.onAppear {
    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
        flameAnimation = true
    }
}
```

**No animation (Minimal):**
Zero animations. The design is completely static. Restraint IS the craft.

### Key Principle

Animation should match the personality:
- Fire theme → breathing, pulsing, glowing (alive, organic)
- Military theme → sharp, instant, no idle animation (disciplined)
- Athletic theme → precise, data-driven transitions (performance)
- Minimal theme → nothing (quiet)

---

## Composition Patterns

### How Levers Work Together

**Military (pushes: Typography, Vocabulary, Status Indicators):**
- Monospaced + ALL-CAPS + tracking = every text element is "military"
- "[COMPLETE]" / "[PENDING]" / "OBJ-01" = every label is "military"
- Square checkboxes + chevron Path badge = every indicator is "military"
- Color is functional (3-role), not decorative → grounded lever

**Forge (pushes: Color, Data Viz, Motion):**
- Fire gradient on everything (numbers, progress, streak) = color IS the brand
- Heat gauge, molten progress bar, ember glow = custom viz everywhere
- Breathing animation + pulsing shadows = the UI feels alive
- Typography is standard weight → grounded lever

**Athletic (pushes: Typography, Data Viz):**
- Giant black-weight numbers + baseline alignment = sports scoreboard feel
- Circular gauge, stat row with dividers, split capsule badge = performance dashboard
- Single cyan accent → grounded lever (not the star, just the highlight)

**Minimal (pushes: Typography, and actively unpushes everything else):**
- 180pt ultraLight = the number IS the entire screen
- No accent, no animation, no section headers, 8pt dots = extreme restraint
- The personality comes from what's ABSENT

### The 2-3 Lever Rule

Every showcase design pushes 2-3 levers hard and keeps the others grounded or absent:
- Pushing ALL levers creates noise (every surface screams for attention)
- Pushing NO levers creates generic (indistinguishable from any other app)
- The contrast between pushed and grounded levers is what creates personality

---

## Anti-Patterns & Visibility Minimums

### What NOT to Do

These are specific failure patterns extracted from real elevation attempts that produced invisible results:

**1. The Invisible Border**
```swift
// BAD — invisible on any background
.overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.4), lineWidth: 1))

// GOOD — visible, intentional
.overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.7), lineWidth: 2))
```
Rule: Borders must be >= 2pt AND >= 0.6 opacity. Below either threshold, they don't register as design elements.

**2. The Material-on-Wrong-Background**
```swift
// BAD — material is invisible on light backgrounds
ZStack {
    Color(red: 0.94, green: 0.93, blue: 0.93) // light gray #F0EDED
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial) // invisible — nothing to blur through
}

// GOOD — material glows on dark backgrounds
ZStack {
    Color(red: 0.05, green: 0.05, blue: 0.06) // near-black #0D0D0F
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial) // beautiful frosted glass effect
}
```
Rule: Materials are context-dependent. Only use on backgrounds dark enough (< #333333) for the frosted effect to be visible.

**3. The Ghost Gradient**
```swift
// BAD — perceptually flat
LinearGradient(colors: [Color(hex: "#222222"), Color(hex: "#333333")], startPoint: .bottom, endPoint: .top)

// GOOD — visually distinct stops
LinearGradient(colors: [Color(hex: "#1a0000"), Color(hex: "#FF4400"), Color(hex: "#FFcc00")], startPoint: .bottom, endPoint: .top)
```
Rule: Gradient stops must span perceptually distinct colors. If you can't tell the difference at arm's length, it's not a gradient.

**4. The Opacity Stack**
```swift
// BAD — each layer is "subtle," collectively invisible
VStack {
    Text("Title").opacity(0.4)      // too faint for primary
    Text("Body").opacity(0.25)      // unreadable
    Divider().opacity(0.05)         // invisible
}
.background(Color.white.opacity(0.03)) // invisible card

// GOOD — clear hierarchy with visible elements
VStack {
    Text("Title").opacity(1.0)
    Text("Body").opacity(0.6)
    Divider().opacity(0.1)
}
.background(Color.white.opacity(0.08)) // visible card surface
```

**5. The Color Scheme Mismatch**
```swift
// BAD — dark design spec, no color scheme enforcement
// Materials, system colors, and vibrancy all render for LIGHT mode
var body: some View {
    ContentView() // runs in whatever the device default is
}

// GOOD — enforce the design system's intended mode
var body: some View {
    ContentView()
        .preferredColorScheme(.dark) // matches the design spec
}
```

### Visibility Minimums Reference

| Element | Minimum | Reasoning |
|---------|---------|-----------|
| Border width | 2pt | 1pt borders are invisible on retina displays at normal viewing distance |
| Border opacity | 0.6 | Below 0.6, borders blend into the background |
| Card bg opacity diff | 0.08 | Below 0.08 difference from parent, the card is invisible |
| Primary accent opacity | 0.6 | Below 0.6, accents look washed out |
| Secondary accent opacity | 0.3 | Below 0.3, accents look like rendering artifacts |
| Text secondary opacity | 0.5 | Below 0.5, text is hard to read |
| Text tertiary opacity | 0.3 | Below 0.3, text is unreadable |
| Shadow radius (for depth) | 4pt | Below 4pt, shadows are imperceptible |
| Shadow opacity | 0.15 | Below 0.15, shadows vanish |
| Separator opacity | 0.08 | Below 0.08, separators are invisible |
| Gradient stop distance | >= 30% hue/brightness shift | Closer stops are perceptually flat |

---

## Using This Library

### For the UI Design Advisor
When evaluating a design: identify which levers are pushed and compare the technique to this library. "Push Typography" is vague. "Use .weight(.ultraLight) at 180pt with monospacedDigit for a quiet-confidence personality" is actionable.

### For the Design Brief
When generating bold options: compose options from this library's techniques. Don't just say "bold typography" — specify the weight, size, design variant, tracking, and case treatment. Each option should be concrete enough to preview mentally.

### For the Design Audit
When scoring lever pushes: compare against these concrete benchmarks. A "bold" Typography push should approach the specificity of the showcase themes, not just "we used a slightly larger font."

### For Implementation
When building the chosen design: these code snippets are copy-paste ready. The patterns are proven in SwiftUI — no hypothetical techniques.
