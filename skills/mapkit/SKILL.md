---
name: mapkit
description: Build and review maps on Apple platforms with MapKit for SwiftUI — the Map view with MapContentBuilder, Marker/Annotation/MapPolyline/MapCircle/MapPolygon, MapCameraPosition, map styles and controls, selection, MKLocalSearch and search completion, MKDirections, Look Around, user location, and the iOS 26 geocoding APIs (MKGeocodingRequest/MKReverseGeocodingRequest) plus GeoToolbox PlaceDescriptor. Use when the user mentions MapKit, a map, Marker, annotation, MapCameraPosition, MKLocalSearch, geocoding, reverse geocoding, place search, Look Around, or directions on a map. For showing/permissions of the user's own location, pair with the `corelocation` skill.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple MapKit docs via Context7 (/websites/developer_apple_mapkit)
---

# MapKit for SwiftUI

Embedding maps, annotations, overlays, search, directions, Look Around, and geocoding on Apple platforms. The deep API reference — every map style and control, the full search/directions/Look Around flows, the iOS 26 geocoding APIs, GeoToolbox `PlaceDescriptor`, performance tuning, and known SwiftUI limitations — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `CAMERA` — `static` (one-shot `Map(initialPosition:)`, map owns the camera after; default for display-only maps) · `bound` (`Map(position: $position)` two-way binding when you drive the camera programmatically — "go to result", "recenter on user"). Don't use a binding you never write to.
2. `LOCATION` — `none` (no user location) · `display` (`UserAnnotation()` + `.userLocation(fallback:)` camera, needs Core Location auth + Info.plist string) · `tracking` (continuous `CLLocationManager` updates feeding annotations). Anything past `none` is a `corelocation` concern.
3. `SEARCH` — `none` · `local` (`MKLocalSearch` for one-shot queries) · `completer` (`MKLocalSearchCompleter` for as-you-type autocomplete, resolve to a `MKMapItem` on selection). `geocode` (`MKGeocodingRequest`/`MKReverseGeocodingRequest`) is a separate axis — address↔coordinate, not POI search.

## When to use

Building or reviewing any SwiftUI map: placing markers/annotations, drawing overlays, controlling the camera, searching for places, drawing routes, Look Around, or geocoding. If the task is "where is the user / ask for location permission," that's `corelocation` — this skill consumes the resulting coordinate. If the task is purely address↔coordinate with no map, you still want the geocoding section here.

## Core rules

- **SwiftUI `Map` for all new code.** iOS 17+ `Map` with `MapContentBuilder` is the supported surface. iOS 26 is the default target. Only reach for `MKMapView` via `UIViewRepresentable` for features SwiftUI still lacks (clustering, tile overlays, custom renderers — see the guide's limitations table).
- **`Marker` / `Annotation`, never the deprecated trio.** `MapAnnotation`, `MapMarker`, and `MapPin` are deprecated. `Marker` for the standard balloon, `Annotation` for a custom SwiftUI view.
- **iOS 26 geocoding replaces `CLGeocoder`.** Use `MKGeocodingRequest` (address→coordinate) and `MKReverseGeocodingRequest` (coordinate→address); both are failable inits returning `[MKMapItem]`. `CLGeocoder` is deprecated in iOS 26.
- **User location needs Core Location.** `UserAnnotation()` / `MapUserLocationButton` show nothing until authorization is granted and `NSLocationWhenInUseUsageDescription` is in Info.plist. Request via the `corelocation` flow before relying on `.userLocation` camera.
- **Network APIs are async and can fail.** `MKLocalSearch`, `MKDirections`, `MKLookAroundSceneRequest`, and the geocoding requests all hit the network — `await`, handle the throw, and never assume a result exists.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll wrap `MKMapView` in `UIViewRepresentable` like I always have." | For new code use SwiftUI `Map` + `MapContentBuilder`. The representable bridge is only for the handful of gaps SwiftUI still has (clustering, `MKTileOverlay`, geodesic polylines, custom renderers). Reaching for it by default means re-implementing coordinator/delegate plumbing the SwiftUI API removed. |
| "`MapAnnotation { … }` lets me put a custom view on the map." | `MapAnnotation`, `MapMarker`, and `MapPin` are **deprecated**. Use `Annotation(_:coordinate:) { … }` for custom views and `Marker` for the standard balloon. |
| "`CLGeocoder().reverseGeocodeLocation` is what I know — I'll use it." | `CLGeocoder` is deprecated in iOS 26. Use `MKReverseGeocodingRequest(location:)` and `MKGeocodingRequest(addressString:)` — note both are `init?` and return `[MKMapItem]` via `await … .mapItems`, not `CLPlacemark`. |
| "I'll fire an `MKLocalSearch` on every keystroke." | `MKLocalSearch` is rate-limited server-side and meant for discrete queries; hammering it per keystroke gets throttled and burns the user's quota. Use `MKLocalSearchCompleter` for as-you-type suggestions, then run one `MKLocalSearch` (or resolve the completion) on selection. |
| "I bound `$position` so I'll just read it to know where the map is." | A `MapCameraPosition` binding drives the camera; it does **not** continuously report the live region as the user pans. For the current visible region use `.onMapCameraChange`. And if you only ever set it once, use `Map(initialPosition:)` (static) instead of a binding. |
| "`UserAnnotation()` will show the blue dot." | Only after Core Location authorization is granted and the Info.plist usage string exists — otherwise it silently shows nothing and `.userLocation(fallback:)` falls through to the fallback. User location is a `corelocation` prerequisite, not something MapKit grants on its own. |

## Verification gate

Before shipping map code, confirm every line:

- [ ] New map UI uses SwiftUI `Map` + `MapContentBuilder`; any `MKMapView`/`UIViewRepresentable` is justified by a documented SwiftUI gap.
- [ ] No deprecated `MapAnnotation` / `MapMarker` / `MapPin` — only `Marker` and `Annotation`.
- [ ] Camera matches the dial: `Map(initialPosition:)` for display-only, `Map(position: $position)` only when code writes to the binding; live region read via `.onMapCameraChange`, not the binding.
- [ ] Geocoding uses `MKGeocodingRequest` / `MKReverseGeocodingRequest` (not `CLGeocoder`); failable inits are unwrapped and the async call's throw is handled.
- [ ] `MKLocalSearch` is one-shot per query; as-you-type uses `MKLocalSearchCompleter`, resolved to a `MKMapItem` on selection.
- [ ] Every network call (`search.start()`, `directions.calculate()`, `request.scene`, geocoding `.mapItems`) is `await`ed in a `do/catch` and tolerates an empty/nil result.
- [ ] User location: Info.plist has `NSLocationWhenInUseUsageDescription`, authorization is requested via the `corelocation` flow before `UserAnnotation`/`.userLocation` is relied on.
- [ ] Look Around availability is checked (`scene != nil`) before presenting Look Around UI.
- [ ] Large annotation sets are bounded (filter by visible region / zoom); no per-frame expensive work inside the `Map` content closure.

## Deep reference

`references/guide.md` — full coverage of the basic map view, markers/annotations, overlays (`MapCircle`/`MapPolygon`/`MapPolyline`), camera control and bounds, map styles, controls, selection, `MKLocalSearch` + completer, `MKDirections`, Look Around, user location, the iOS 26 GeoToolbox `PlaceDescriptor` and geocoding APIs, performance/best-practices, and the SwiftUI MapKit limitations table. Load it for any concrete API question.
