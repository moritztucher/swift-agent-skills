# MapKit and GeoToolbox Guide for SwiftUI

A comprehensive guide covering MapKit for SwiftUI (iOS 17+) and the new GeoToolbox framework (iOS 26+).

---

## Table of Contents

1. [Overview](#overview)
2. [Basic Map View](#basic-map-view)
3. [Markers and Annotations](#markers-and-annotations)
4. [Overlays](#overlays)
5. [Camera Control](#camera-control)
6. [Map Styles](#map-styles)
7. [Map Controls](#map-controls)
8. [Selection and Interaction](#selection-and-interaction)
9. [Search with MKLocalSearch](#search-with-mklocalsearch)
10. [Directions with MKDirections](#directions-with-mkdirections)
11. [Look Around](#look-around)
12. [User Location](#user-location)
13. [GeoToolbox Framework (iOS 26)](#geotoolbox-framework-ios-26)
14. [New Geocoding APIs (iOS 26)](#new-geocoding-apis-ios-26)
15. [Performance and Best Practices](#performance-and-best-practices)
16. [Known Limitations](#known-limitations)

---

## Overview

MapKit for SwiftUI was significantly enhanced in iOS 17, introducing a feature-rich API that deprecates the iOS 14 implementation. The framework uses `MapContentBuilder` (similar to `ViewBuilder`) with types conforming to `MapContent` protocol.

**Minimum Requirements:**
- iOS 17+ for full MapKit SwiftUI features
- iOS 26+ for GeoToolbox and new geocoding APIs

**Import Statement:**
```swift
import MapKit
import CoreLocation  // For location services
import GeoToolbox    // iOS 26+ only
```

---

## Basic Map View

### Simple Map

```swift
import MapKit

struct BasicMapView: View {
    var body: some View {
        Map()
    }
}
```

### Map with Initial Position

```swift
struct MapWithPosition: View {
    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        ))
    }
}
```

### Map with Binding Position

```swift
struct MapWithBindingPosition: View {
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        Map(position: $position)
    }
}
```

---

## Markers and Annotations

### Marker

`Marker` provides a balloon-shaped annotation for marking locations.

```swift
struct MarkerExample: View {
    var body: some View {
        Map {
            Marker("San Francisco", coordinate: CLLocationCoordinate2D(
                latitude: 37.7749,
                longitude: -122.4194
            ))
            .tint(.orange)
        }
    }
}
```

### Marker with System Image

```swift
Marker("Coffee Shop", systemImage: "cup.and.saucer.fill", coordinate: location)
    .tint(.brown)
```

### Marker with Monogram

```swift
Marker("Alice's House", monogram: "A", coordinate: location)
```

### Annotation (Custom View)

`Annotation` allows fully custom SwiftUI views as map markers.

```swift
struct AnnotationExample: View {
    let location = CLLocationCoordinate2D(latitude: 37.8270, longitude: -122.4789)

    var body: some View {
        Map {
            Annotation("Golden Gate Bridge", coordinate: location) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.orange)
                    Text("GGB")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(5)
                }
            }
        }
    }
}
```

### Annotation with Anchor

Control the anchor point relative to the coordinate:

```swift
Annotation("Location", coordinate: coordinate, anchor: .bottom) {
    Image(systemName: "mappin.circle.fill")
        .font(.title)
        .foregroundStyle(.red)
}
```

Anchor options: `.top`, `.bottom`, `.leading`, `.trailing`, `.center`, `.topLeading`, `.topTrailing`, `.bottomLeading`, `.bottomTrailing`, or custom `CGPoint`.

### Multiple Markers from Data

```swift
struct Location: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct MultipleMarkersView: View {
    let locations = [
        Location(name: "Apple Park", coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)),
        Location(name: "Googleplex", coordinate: CLLocationCoordinate2D(latitude: 37.4220, longitude: -122.0841)),
        Location(name: "Meta HQ", coordinate: CLLocationCoordinate2D(latitude: 37.4847, longitude: -122.1477))
    ]

    var body: some View {
        Map {
            ForEach(locations) { location in
                Marker(location.name, coordinate: location.coordinate)
            }
        }
    }
}
```

---

## Overlays

### MapCircle

```swift
Map {
    MapCircle(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), radius: 1000)
        .foregroundStyle(.blue.opacity(0.3))
        .stroke(.blue, lineWidth: 2)
        .mapOverlayLevel(level: .aboveRoads)
}
```

Overlay levels:
- `.aboveRoads` - Labels appear above the overlay (default)
- `.aboveLabels` - Overlay appears above everything

### MapPolygon

```swift
Map {
    MapPolygon(coordinates: [
        CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42),
        CLLocationCoordinate2D(latitude: 37.78, longitude: -122.40),
        CLLocationCoordinate2D(latitude: 37.76, longitude: -122.40),
        CLLocationCoordinate2D(latitude: 37.76, longitude: -122.42)
    ])
    .foregroundStyle(.green.opacity(0.3))
    .stroke(.green, lineWidth: 2)
}
```

### MapPolyline

```swift
Map {
    MapPolyline(coordinates: [
        CLLocationCoordinate2D(latitude: 37.79, longitude: -122.42),
        CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
        CLLocationCoordinate2D(latitude: 37.77, longitude: -122.40)
    ])
    .stroke(.red, lineWidth: 3)
}
```

### MapPolyline with Route

```swift
// After getting MKRoute from MKDirections
Map {
    MapPolyline(route.polyline)
        .stroke(.blue, lineWidth: 5)
}
```

### Styled Polyline

```swift
MapPolyline(coordinates: routeCoordinates)
    .stroke(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        ),
        style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [10, 5])
    )
```

---

## Camera Control

### MapCameraPosition Options

```swift
// Region-based
let regionPosition = MapCameraPosition.region(MKCoordinateRegion(...))

// Camera with heading and pitch
let cameraPosition = MapCameraPosition.camera(
    MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        distance: 1000,
        heading: 45,
        pitch: 60
    )
)

// Automatic (frames all content)
let automaticPosition = MapCameraPosition.automatic

// User location
let userLocationPosition = MapCameraPosition.userLocation(fallback: .automatic)

// Item-based (frame specific items)
let itemPosition = MapCameraPosition.item(MKMapItem(...))

// Rect-based
let rectPosition = MapCameraPosition.rect(MKMapRect(...))
```

### Camera Bounds

Restrict the camera to a specific region:

```swift
Map(position: $position, bounds: MapCameraBounds(
    centerCoordinateBounds: MKCoordinateRegion(...),
    minimumDistance: 100,
    maximumDistance: 10000
))
```

### Interaction Modes

Control which interactions are allowed:

```swift
Map(position: $position, interactionModes: [.pan, .zoom])

// All interactions (default)
Map(interactionModes: .all)

// Specific interactions
Map(interactionModes: [.pan, .zoom, .pitch, .rotate])
```

### Programmatic Camera Updates

```swift
struct CameraUpdateExample: View {
    @State private var position = MapCameraPosition.automatic

    var body: some View {
        Map(position: $position) {
            // content
        }

        Button("Go to San Francisco") {
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
}
```

---

## Map Styles

### Standard Style

```swift
Map { }
    .mapStyle(.standard)

// With options
Map { }
    .mapStyle(.standard(
        elevation: .realistic,           // .automatic, .flat, or .realistic
        emphasis: .automatic,            // .automatic or .muted
        pointsOfInterest: .including([.restaurant, .cafe]),
        showsTraffic: true
    ))
```

### Imagery Style (Satellite)

```swift
Map { }
    .mapStyle(.imagery)

// With elevation
Map { }
    .mapStyle(.imagery(elevation: .realistic))
```

### Hybrid Style (Satellite + Labels)

```swift
Map { }
    .mapStyle(.hybrid)

// With options
Map { }
    .mapStyle(.hybrid(
        elevation: .realistic,
        pointsOfInterest: .including([.airport, .publicTransport]),
        showsTraffic: true
    ))
```

### Points of Interest Filtering

```swift
// Include specific categories
.mapStyle(.standard(pointsOfInterest: .including([
    .restaurant,
    .cafe,
    .bakery,
    .hotel
])))

// Exclude categories
.mapStyle(.standard(pointsOfInterest: .excluding([
    .store,
    .gasStation
])))

// Show all
.mapStyle(.standard(pointsOfInterest: .all))
```

---

## Map Controls

### Adding Controls

```swift
Map { }
    .mapControls {
        MapCompass()
        MapScaleView()
        MapUserLocationButton()
        MapPitchToggle()
        MapZoomStepper()
    }
```

### Available Controls

| Control | Description |
|---------|-------------|
| `MapCompass()` | Shows current orientation, appears when rotated |
| `MapScaleView()` | Distance legend |
| `MapUserLocationButton()` | Centers on user location |
| `MapPitchToggle()` | Toggle between flat and 3D view |
| `MapPitchSlider()` | Adjust pitch with slider |
| `MapZoomStepper()` | +/- buttons for zoom |

### Control Visibility

```swift
Map { }
    .mapControlVisibility(.hidden)      // Hide all
    .mapControlVisibility(.automatic)   // System default
    .mapControlVisibility(.visible)     // Always show
```

---

## Selection and Interaction

### Marker Selection

```swift
struct SelectionExample: View {
    @State private var selectedTag: Int?

    var body: some View {
        Map(selection: $selectedTag) {
            Marker("Location 1", coordinate: coord1)
                .tag(1)
            Marker("Location 2", coordinate: coord2)
                .tag(2)
        }
        .onChange(of: selectedTag) { oldValue, newValue in
            if let tag = newValue {
                print("Selected marker with tag: \(tag)")
            }
        }
    }
}
```

### Selection with Custom Types

```swift
struct Place: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}

struct PlaceSelectionView: View {
    @State private var selectedPlace: Place?
    let places: [Place]

    var body: some View {
        Map(selection: $selectedPlace) {
            ForEach(places) { place in
                Marker(place.name, coordinate: place.coordinate)
                    .tag(place)
            }
        }
    }
}
```

### Selection with MKMapItem

```swift
@State private var selectedItem: MKMapItem?

Map(selection: $selectedItem) {
    Marker(item: mapItem)
}
```

### Tap Gesture on Annotations

For custom tap handling, use `Annotation` with `.onTapGesture`:

```swift
Annotation("Tappable", coordinate: coord) {
    Image(systemName: "star.fill")
        .foregroundStyle(.yellow)
        .onTapGesture {
            // Handle tap
        }
}
```

---

## Search with MKLocalSearch

### Basic Search

```swift
@Observable
class SearchViewModel {
    var searchResults: [MKMapItem] = []
    var isSearching = false

    func search(for query: String, in region: MKCoordinateRegion) async {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
    }
}
```

### Search Completer (Autocomplete)

```swift
@Observable
class SearchCompleterManager: NSObject, MKLocalSearchCompleterDelegate {
    var completer = MKLocalSearchCompleter()
    var suggestions: [MKLocalSearchCompletion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Completer error: \(error)")
    }

    func getMapItem(for completion: MKLocalSearchCompletion) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.first
    }
}
```

### Complete Search View Example

```swift
struct SearchableMapView: View {
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var position = MapCameraPosition.automatic
    @State private var selectedItem: MKMapItem?

    var body: some View {
        Map(position: $position, selection: $selectedItem) {
            ForEach(searchResults, id: \.self) { item in
                Marker(item: item)
            }
        }
        .searchable(text: $searchText, prompt: "Search for places")
        .onSubmit(of: .search) {
            Task {
                await performSearch()
            }
        }
    }

    func performSearch() async {
        guard !searchText.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems

            // Frame all results
            if !searchResults.isEmpty {
                position = .automatic
            }
        } catch {
            print("Search failed: \(error)")
        }
    }
}
```

---

## Directions with MKDirections

### Getting Directions

```swift
@Observable
class DirectionsManager {
    var route: MKRoute?
    var isLoading = false
    var errorMessage: String?

    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async {
        isLoading = true
        defer { isLoading = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile // .walking, .transit, .cycling (iOS 26+)
        request.requestsAlternateRoutes = true

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            route = response.routes.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Displaying Route

```swift
struct DirectionsMapView: View {
    @State private var directionsManager = DirectionsManager()
    let source = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let destination = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    var body: some View {
        Map {
            Marker("Start", coordinate: source)
                .tint(.green)
            Marker("End", coordinate: destination)
                .tint(.red)

            if let route = directionsManager.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .task {
            await directionsManager.getDirections(from: source, to: destination)
        }
    }
}
```

### Route Information

```swift
if let route = directionsManager.route {
    // Distance in meters
    let distanceKm = route.distance / 1000

    // Expected travel time in seconds
    let travelTimeMinutes = route.expectedTravelTime / 60

    // Turn-by-turn steps
    for step in route.steps {
        print(step.instructions)
        print("Distance: \(step.distance) meters")
    }
}
```

### Cycling Directions (iOS 26+)

```swift
request.transportType = .cycling
```

---

## Look Around

### LookAroundPreview

```swift
struct LookAroundView: View {
    @State private var lookAroundScene: MKLookAroundScene?
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack {
            if let scene = lookAroundScene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 200)
            } else {
                ContentUnavailableView("No Look Around Available", systemImage: "eye.slash")
            }
        }
        .task {
            await getLookAroundScene()
        }
    }

    func getLookAroundScene() async {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        do {
            lookAroundScene = try await request.scene
        } catch {
            print("Look Around error: \(error)")
        }
    }
}
```

### LookAroundPreview Options

```swift
LookAroundPreview(
    initialScene: scene,
    allowsNavigation: true,          // Enable user navigation
    showsRoadLabels: true,           // Show street names
    pointsOfInterest: .all,          // POI visibility
    badgePosition: .topLeading       // Badge placement
)
```

### Look Around Viewer (Modal)

```swift
struct MapWithLookAround: View {
    @State private var showLookAround = false
    @State private var lookAroundScene: MKLookAroundScene?

    var body: some View {
        Map { }
            .lookAroundViewer(isPresented: $showLookAround, initialScene: lookAroundScene)
    }
}
```

**Note:** Look Around is only available in select cities.

---

## User Location

### Setup Requirements

1. Add to Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby places</string>
```

2. For always access:
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location for background tracking</string>
```

### Location Manager

```swift
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
```

### Showing User Location

```swift
struct UserLocationMapView: View {
    @State private var position = MapCameraPosition.userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
        }
    }
}
```

### LocationButton (One-Time Access)

```swift
import CoreLocationUI

struct LocationButtonView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        LocationButton(.currentLocation) {
            locationManager.requestAuthorization()
        }
        .labelStyle(.titleAndIcon)
    }
}
```

---

## GeoToolbox Framework (iOS 26)

GeoToolbox is a new framework introduced in iOS 26 for working with place information without requiring MapKit identifiers.

### PlaceDescriptor

`PlaceDescriptor` contains identifying information about a place that mapping services can use to find rich place data.

```swift
import GeoToolbox
import MapKit

// Create from coordinate
let descriptor = PlaceDescriptor(
    representations: [.coordinate(CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))],
    commonName: "Golden Gate Bridge"
)

// Create from address
let addressDescriptor = PlaceDescriptor(
    representations: [.address("1 Infinite Loop, Cupertino, CA")],
    commonName: "Apple Campus"
)

// Use with MapKit
let request = MKMapItemRequest(placeDescriptor: descriptor)
let mapItem = try await request.mapItem
```

### PlaceDescriptor Structure

- **commonName**: Well-known public name (e.g., "Sydney Opera House")
- **representations**: Array containing address, coordinate, or device location
- **supportingRepresentations**: Optional cross-provider service IDs

### When to Use PlaceDescriptor

- Working with data from external APIs or CRMs without MapKit IDs
- Passing place references to code that doesn't use MapKit
- Integrating with App Intents
- Cross-provider mapping scenarios

---

## New Geocoding APIs (iOS 26)

iOS 26 deprecates `CLGeocoder` in favor of new MapKit geocoding APIs.

### MKReverseGeocodingRequest (Coordinate to Address)

```swift
func reverseGeocode(location: CLLocation) async throws -> MKMapItem? {
    guard let request = MKReverseGeocodingRequest(location: location) else {
        return nil
    }

    let mapItems = try await request.mapItems
    return mapItems.first
}

// Usage
let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
if let mapItem = try await reverseGeocode(location: location) {
    print(mapItem.placemark.name ?? "Unknown")
}
```

### MKGeocodingRequest (Address to Coordinate)

```swift
func geocode(address: String) async throws -> [MKMapItem] {
    // init?(addressString:) — returns nil if the string is empty.
    guard let request = MKGeocodingRequest(addressString: address) else {
        return []
    }
    return try await request.mapItems
}

// Usage
let results = try await geocode(address: "1 Apple Park Way, Cupertino, CA")
if let first = results.first {
    print(first.placemark.coordinate)
}
```

### MKAddress

`MKAddress` provides formatted address strings:

```swift
if let address = mapItem.address {
    // Full postal address
    print(address.fullAddress)

    // Abbreviated address
    print(address.shortAddress)
}
```

### MKAddressRepresentations

Provides flexible address formatting based on locale and context:

```swift
if let representations = mapItem.addressRepresentations {
    // Get city with context (state/country as appropriate)
    if let cityWithContext = representations.cityWithContext {
        print(cityWithContext)
    }
}
```

**Key Point:** Address representations automatically adapt to the device locale.

---

## Performance and Best Practices

### Annotation Reuse

When displaying many annotations, ensure views are reused efficiently:

```swift
// Bad - creates new views constantly
ForEach(largeDataSet) { item in
    Marker(item.name, coordinate: item.coordinate)
}

// Better - use identifiable items and limit visible markers
ForEach(visibleItems) { item in
    Marker(item.name, coordinate: item.coordinate)
}
```

### Memory Management

Map views can consume significant memory. Consider:

1. **Lazy loading** - Only load visible annotations
2. **Limit overlay complexity** - Simplify polylines with many points
3. **Remove unused content** - Clear annotations when leaving the screen
4. **Avoid `showsUserLocation = true`** unless needed (uses ~10% CPU)

### Clustering (UIKit Fallback Required)

SwiftUI MapKit does not support clustering natively. Options:

1. **Third-party libraries** like [ClusterMap](https://github.com/vospennikov/ClusterMap)
2. **Custom clustering algorithm** driving which annotations to show
3. **UIViewRepresentable** wrapping MKMapView for full UIKit clustering support

### Reduce Annotations by Zoom Level

```swift
@Observable
class MapContentManager {
    var visibleAnnotations: [Place] = []

    func updateVisibleAnnotations(for region: MKCoordinateRegion, allPlaces: [Place]) {
        let zoomLevel = calculateZoomLevel(from: region)

        if zoomLevel < 5 {
            // Very zoomed out - show clusters or nothing
            visibleAnnotations = []
        } else if zoomLevel < 10 {
            // Medium zoom - show major places
            visibleAnnotations = allPlaces.filter { $0.importance > .high }
        } else {
            // Zoomed in - show all
            visibleAnnotations = allPlaces
        }
    }

    private func calculateZoomLevel(from region: MKCoordinateRegion) -> Double {
        // Approximate zoom level from span
        return log2(360 / max(region.span.latitudeDelta, region.span.longitudeDelta))
    }
}
```

### Avoid Expensive Operations in Map Content

```swift
// Bad - expensive computation in map content
Map {
    ForEach(items) { item in
        Marker(expensiveTransform(item), coordinate: item.coordinate)
    }
}

// Better - precompute outside the Map
let processedItems = items.map { ProcessedItem(from: $0) }

Map {
    ForEach(processedItems) { item in
        Marker(item.displayName, coordinate: item.coordinate)
    }
}
```

---

## Known Limitations

### SwiftUI MapKit Limitations (as of iOS 18)

| Feature | Status | Workaround |
|---------|--------|------------|
| Annotation clustering | Not supported | Use ClusterMap library or UIKit |
| Tile overlays (MKTileOverlay) | Not supported | Use UIViewRepresentable |
| Geodesic polylines | Not supported | Use UIKit's MKGeodesicPolyline |
| MKMultiPolyline/MKMultiPolygon | Not supported | Draw individual shapes |
| Custom overlay renderers | Not supported | Use UIViewRepresentable |

### Look Around Availability

- Only available in select cities
- Check availability before showing UI:

```swift
let request = MKLookAroundSceneRequest(coordinate: coordinate)
let scene = try? await request.scene
let isAvailable = scene != nil
```

### 3D Elevation Availability

Realistic elevation is only available in select areas. In other regions, the map falls back to flat rendering.

### iOS 18 Known Issues

- Some buttons in map annotations may not respond to tap events (regression from iOS 17)
- MKLookAroundSnapshotter may return original scene image when scene has been modified

---

## References

### Official Documentation
- [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)
- [GeoToolbox](https://developer.apple.com/documentation/GeoToolbox)
- [PlaceDescriptor](https://developer.apple.com/documentation/GeoToolbox/PlaceDescriptor)
- [MKReverseGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest)
- [MKGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest)

### WWDC Sessions
- [Meet MapKit for SwiftUI (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10043/)
- [Go further with MapKit (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/204/)

### Community Resources
- [Hacking with Swift - MapKit Tutorials](https://www.hackingwithswift.com/books/ios-swiftui/integrating-mapkit-with-swiftui)
- [Create with Swift - MapKit Articles](https://www.createwithswift.com/using-expanded-swiftui-support-for-mapkit/)
- [Swift with Majid - Mastering MapKit](https://swiftwithmajid.com/2023/11/28/mastering-mapkit-in-swiftui-basics/)
- [ClusterMap Library](https://github.com/vospennikov/ClusterMap)

---

*Last updated: February 2026*
