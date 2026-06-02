# SwiftUI Badge Guide

## `.badge()` Modifier

Works on more views than Apple docs suggest:
- **Tab items** (documented)
- **List rows** (documented)
- **Toolbar buttons** (undocumented but works)

### API

```swift
func badge(_ count: Int) -> some View
func badge(_ label: Text?) -> some View
func badge(_ key: LocalizedStringKey?) -> some View
func badgeProminence(_ prominence: BadgeProminence) -> some View
```

### Badge Prominence

- `.standard` — default red badge
- `.increased` — more prominent red badge
- `.decreased` — uses accent color instead of red

### Examples

```swift
// Tab badge
Tab("Alerts", systemImage: "bell") {
    AlertsView()
}
.badge(alerts.count)

// List row badge
List {
    Text("Recents")
        .badge(recentItems.count)
}

// Toolbar button badge (works despite not being in docs)
ToolbarItem(placement: .topBarTrailing) {
    Button { } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
    }
    .badge(filterCount)
    .badgeProminence(.decreased) // accent color instead of red
}
```

### Notes

- Badge of `0` hides the badge automatically
- `.badgeProminence(.decreased)` works on List rows and Tabs for accent-colored badges
- `.badge()` works on toolbar buttons (undocumented, iOS 26) but `.badgeProminence()` does NOT affect toolbar badges — they stay red regardless
- For accent-colored badges on toolbar buttons, use a manual overlay instead:

```swift
Button { } label: {
    Image(systemName: "line.3.horizontal.decrease.circle")
        .overlay(alignment: .topTrailing) {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 16, minHeight: 16)
                .background(Color.accentColor, in: .circle)
                .offset(x: 8, y: -8)
        }
}
```
