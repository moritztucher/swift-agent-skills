# CarPlay Guide for iOS Development

## Overview

CarPlay is Apple's in-vehicle experience that lets users get directions, make calls, send and receive messages, listen to music, and more from their car's built-in display while staying focused on the road. CarPlay projects a simplified, driver-safe interface from the connected iPhone to the vehicle's infotainment system.

### Key Characteristics

- **Client-Server Model**: The iPhone handles all application logic (server), while the vehicle only displays the interface and transmits user input (client)
- **Template-Based UI**: Apps use predefined templates rather than custom views, ensuring consistency and safety
- **Single-Category Apps**: Each CarPlay app can only belong to one category (with one exception: EV Charging and Fueling can be combined)

### Supported App Categories

| Category | Description | Template Depth Limit |
|----------|-------------|---------------------|
| **Audio** | Music, podcasts, audiobooks | 5 templates |
| **Communication** | VoIP calling, messaging (via SiriKit) | 5 templates |
| **Navigation** | Turn-by-turn directions | 5 templates |
| **EV Charging** | Electric vehicle charging station locators | 5 templates |
| **Fueling** | Gas station locators | 3 templates |
| **Parking** | Parking location services | 5 templates |
| **Quick Food Ordering** | Food ordering and pickup | 2 templates |
| **Driving Task** | Tasks needed while driving | 2 templates |

---

## Requirements

### iOS Version Support

- **iOS 12+**: Basic CarPlay template support
- **iOS 14+**: Scene-based CarPlay with `CPTemplateApplicationSceneDelegate`
- **iOS 16+**: Fueling apps, driving task apps
- **iOS 26+**: Widgets, Live Activities, multitouch navigation, video streaming (parked), Liquid Glass design

### Entitlements

CarPlay development requires explicit approval from Apple. You must request the appropriate entitlement for your app category.

**Step 1: Request Entitlement**

1. Visit [developer.apple.com/carplay](https://developer.apple.com/carplay/)
2. Agree to the CarPlay Entitlement Addendum
3. Provide app details and category information
4. Wait for Apple's review and approval

**Step 2: Add Entitlement to Project**

After approval, add the entitlement to your `.entitlements` file:

```xml
<!-- Audio App -->
<key>com.apple.developer.carplay-audio</key>
<true/>

<!-- Navigation App -->
<key>com.apple.developer.carplay-maps</key>
<true/>

<!-- Communication App -->
<key>com.apple.developer.carplay-communication</key>
<true/>

<!-- EV Charging App -->
<key>com.apple.developer.carplay-charging</key>
<true/>

<!-- Fueling App -->
<key>com.apple.developer.carplay-fueling</key>
<true/>

<!-- Parking App -->
<key>com.apple.developer.carplay-parking</key>
<true/>

<!-- Quick Food Ordering App -->
<key>com.apple.developer.carplay-quick-ordering</key>
<true/>

<!-- Driving Task App -->
<key>com.apple.developer.carplay-driving-task</key>
<true/>
```

### Info.plist Configuration

Configure the Application Scene Manifest to support CarPlay:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
    <key>UISceneConfigurations</key>
    <dict>
        <!-- CarPlay Scene -->
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>CarPlay Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
            </dict>
        </array>
        <!-- iPhone Scene -->
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

### Category-Specific Requirements

**Navigation Apps:**
- Must provide turn-by-turn directions with upcoming maneuvers
- Use `CPMapTemplate` for map display
- Implement `CPNavigationSession` for active guidance

**Communication Apps:**
- Must support CallKit for VoIP calling
- Must implement required SiriKit intents
- Handle calls via SiriKit, not direct CarPlay UI

**EV Charging / Fueling Apps:**
- Must only show relevant locations on maps (chargers or fuel stations)
- Provide meaningful functionality beyond just listing locations

**Parking Apps:**
- Must only show parking locations on maps
- Provide meaningful driving-related functionality

**Driving Task Apps:**
- Must enable tasks people need while driving
- Tasks must actually help with the drive

---

## Core Concepts

### CPTemplateApplicationSceneDelegate

The primary delegate that handles CarPlay connection/disconnection and lifecycle events.

**Navigation apps only:** because they draw map content, navigation apps receive the
`to window:` variant of the connect/disconnect callbacks and own a `CPWindow`. All other
categories use the interface controller exclusively and never touch a window:

```swift
// Navigation category — you get a CPWindow to draw the map into.
func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController,
    to window: CPWindow
) {
    self.interfaceController = interfaceController
    self.carWindow = window
    window.rootViewController = MapRenderingViewController()
    interfaceController.setRootTemplate(makeMapTemplate(), animated: true, completion: nil)
}
```

The plain `didConnect interfaceController:` form (no window) is what every non-navigation
category implements:

```swift
import CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    private var interfaceController: CPInterfaceController?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        configureRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Private Methods

    private func configureRootTemplate() {
        // Set up your root template
    }
}
```

### CPInterfaceController

Manages the template navigation stack, similar to `UINavigationController`:

```swift
// Set root template
interfaceController?.setRootTemplate(template, animated: true) { success, error in
    if let error = error {
        print("Failed to set root template: \(error)")
    }
}

// Push template onto stack
interfaceController?.pushTemplate(detailTemplate, animated: true) { success, error in
    // Handle completion
}

// Pop template
interfaceController?.popTemplate(animated: true) { success, error in
    // Handle completion
}

// Pop to root
interfaceController?.popToRootTemplate(animated: true) { success, error in
    // Handle completion
}

// Present modal
interfaceController?.presentTemplate(alertTemplate, animated: true) { success, error in
    // Handle completion
}

// Dismiss modal
interfaceController?.dismissTemplate(animated: true) { success, error in
    // Handle completion
}
```

### Available Templates

| Template | Description | Root Template |
|----------|-------------|---------------|
| `CPTabBarTemplate` | Container with tab navigation | Yes |
| `CPListTemplate` | Scrollable list of items (query `maximumItemCount` / `maximumSectionCount` at runtime — limits vary by vehicle) | Yes |
| `CPGridTemplate` | Grid of buttons (max 8 visible; >4 splits into two rows) | Yes |
| `CPMapTemplate` | Navigation map with overlays | Yes (Navigation only) |
| `CPNowPlayingTemplate` | Audio playback controls | No |
| `CPPointOfInterestTemplate` | Map with selectable POIs (max 12) | No |
| `CPInformationTemplate` | Information display with actions | No |
| `CPAlertTemplate` | Modal alert dialog | No (Modal) |
| `CPActionSheetTemplate` | Modal action sheet | No (Modal) |
| `CPSearchTemplate` | Search interface | No |
| `CPVoiceControlTemplate` | Voice input feedback | No |
| `CPContactTemplate` | Contact information | No |
| `CPMessageListTemplate` | Message conversation list | No |

---

## Basic Implementation

### Audio App Example

```swift
import CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    private var interfaceController: CPInterfaceController?
    private let audioManager = AudioManager.shared

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupAudioInterface()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Private Methods

    private func setupAudioInterface() {
        let tabBarTemplate = CPTabBarTemplate(templates: [
            createLibraryTemplate(),
            createPlaylistsTemplate(),
            createGenresTemplate()
        ])

        interfaceController?.setRootTemplate(tabBarTemplate, animated: false)
    }

    private func createLibraryTemplate() -> CPListTemplate {
        let albums = audioManager.albums.map { album in
            let item = CPListItem(text: album.title, detailText: album.artist)
            item.accessoryType = .disclosureIndicator
            item.setImage(album.artwork)

            item.handler = { [weak self] _, completion in
                self?.showAlbumDetail(album)
                completion()
            }

            return item
        }

        let section = CPListSection(items: albums)
        let template = CPListTemplate(title: "Library", sections: [section])
        template.tabSystemItem = .favorites

        return template
    }

    private func createPlaylistsTemplate() -> CPListTemplate {
        let playlists = audioManager.playlists.map { playlist in
            let item = CPListItem(text: playlist.name, detailText: "\(playlist.trackCount) songs")
            item.accessoryType = .disclosureIndicator

            item.handler = { [weak self] _, completion in
                self?.showPlaylistDetail(playlist)
                completion()
            }

            return item
        }

        let section = CPListSection(items: playlists)
        let template = CPListTemplate(title: "Playlists", sections: [section])
        template.tabTitle = "Playlists"
        template.tabImage = UIImage(systemName: "music.note.list")

        return template
    }

    private func createGenresTemplate() -> CPGridTemplate {
        let genres = ["Pop", "Rock", "Jazz", "Classical", "Hip Hop", "Electronic"]

        let buttons = genres.map { genre in
            CPGridButton(
                titleVariants: [genre],
                image: UIImage(systemName: "music.mic")!
            ) { [weak self] button in
                self?.showGenreDetail(genre)
            }
        }

        let template = CPGridTemplate(title: "Genres", gridButtons: buttons)
        template.tabImage = UIImage(systemName: "guitars")

        return template
    }

    private func showAlbumDetail(_ album: Album) {
        let tracks = album.tracks.map { track in
            let item = CPListItem(text: track.title, detailText: track.duration)

            item.handler = { [weak self] _, completion in
                self?.audioManager.play(track: track)
                self?.showNowPlaying()
                completion()
            }

            return item
        }

        let section = CPListSection(items: tracks)
        let template = CPListTemplate(title: album.title, sections: [section])

        interfaceController?.pushTemplate(template, animated: true)
    }

    private func showNowPlaying() {
        let nowPlayingTemplate = CPNowPlayingTemplate.shared

        // Configure now playing buttons
        let shuffleButton = CPNowPlayingShuffleButton { [weak self] _ in
            self?.audioManager.toggleShuffle()
        }

        let repeatButton = CPNowPlayingRepeatButton { [weak self] _ in
            self?.audioManager.toggleRepeat()
        }

        nowPlayingTemplate.updateNowPlayingButtons([shuffleButton, repeatButton])

        interfaceController?.pushTemplate(nowPlayingTemplate, animated: true)
    }

    private func showPlaylistDetail(_ playlist: Playlist) {
        // Implementation similar to showAlbumDetail
    }

    private func showGenreDetail(_ genre: String) {
        // Implementation to show genre tracks
    }
}
```

### Navigation App Example

```swift
import CarPlay
import MapKit

class NavigationCarPlayDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    private var interfaceController: CPInterfaceController?
    private var mapTemplate: CPMapTemplate?
    private var navigationSession: CPNavigationSession?
    private let navigationManager = NavigationManager.shared

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupMapInterface()
    }

    // MARK: - Private Methods

    private func setupMapInterface() {
        mapTemplate = CPMapTemplate()
        mapTemplate?.mapDelegate = self

        // Configure map buttons
        let zoomInButton = CPMapButton { [weak self] _ in
            self?.zoomIn()
        }
        zoomInButton.image = UIImage(systemName: "plus.magnifyingglass")

        let zoomOutButton = CPMapButton { [weak self] _ in
            self?.zoomOut()
        }
        zoomOutButton.image = UIImage(systemName: "minus.magnifyingglass")

        let recenterButton = CPMapButton { [weak self] _ in
            self?.recenterMap()
        }
        recenterButton.image = UIImage(systemName: "location.fill")

        mapTemplate?.mapButtons = [zoomInButton, zoomOutButton, recenterButton]

        // Configure bar buttons
        let searchButton = CPBarButton(title: "Search") { [weak self] _ in
            self?.showSearchTemplate()
        }
        mapTemplate?.leadingNavigationBarButtons = [searchButton]

        let favoritesButton = CPBarButton(image: UIImage(systemName: "star.fill")!) { [weak self] _ in
            self?.showFavorites()
        }
        mapTemplate?.trailingNavigationBarButtons = [favoritesButton]

        interfaceController?.setRootTemplate(mapTemplate!, animated: false)
    }

    private func showSearchTemplate() {
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = self
        interfaceController?.pushTemplate(searchTemplate, animated: true)
    }

    private func showFavorites() {
        let favorites = navigationManager.favoriteLocations.map { location in
            let item = CPListItem(text: location.name, detailText: location.address)

            item.handler = { [weak self] _, completion in
                self?.startNavigationTo(location)
                completion()
            }

            return item
        }

        let section = CPListSection(items: favorites)
        let template = CPListTemplate(title: "Favorites", sections: [section])

        interfaceController?.pushTemplate(template, animated: true)
    }

    private func startNavigationTo(_ destination: Location) {
        // Create trip with route choices
        let origin = MKMapItem.forCurrentLocation()
        let destinationItem = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))

        let trip = CPTrip(
            origin: origin,
            destination: destinationItem,
            routeChoices: []
        )

        // Calculate routes
        Task {
            let routes = await navigationManager.calculateRoutes(to: destination)

            let routeChoices = routes.map { route in
                CPRouteChoice(
                    summaryVariants: [route.summary],
                    additionalInformationVariants: [route.distance],
                    selectionSummaryVariants: ["Via \(route.name)"]
                )
            }

            let tripWithRoutes = CPTrip(
                origin: origin,
                destination: destinationItem,
                routeChoices: routeChoices
            )

            await MainActor.run {
                showTripPreview(tripWithRoutes)
            }
        }
    }

    private func showTripPreview(_ trip: CPTrip) {
        let previewConfiguration = CPTripPreviewTextConfiguration(
            startButtonTitle: "Go",
            additionalRoutesButtonTitle: "Routes",
            overviewButtonTitle: "Overview"
        )

        mapTemplate?.showTripPreviews([trip], textConfiguration: previewConfiguration)
    }

    func startNavigation(for trip: CPTrip, routeChoice: CPRouteChoice) {
        mapTemplate?.hideTripPreviews()

        navigationSession = mapTemplate?.startNavigationSession(for: trip)
        navigationSession?.pauseTrip(for: .loading, description: "Calculating route...")

        Task {
            let maneuvers = await navigationManager.getManeuvers(for: routeChoice)

            await MainActor.run {
                navigationSession?.upcomingManeuvers = maneuvers
                navigationSession?.resumeTrip(for: .navigating)
            }
        }
    }

    func updateManeuver(_ maneuver: CPManeuver, distance: Measurement<UnitLength>) {
        let estimates = CPTravelEstimates(
            distanceRemaining: distance,
            timeRemaining: navigationManager.estimatedTimeRemaining
        )

        navigationSession?.updateEstimates(estimates, for: maneuver)
    }

    func completeNavigation() {
        navigationSession?.finishTrip()
        navigationSession = nil
    }

    private func zoomIn() {
        // Notify your map view to zoom in
    }

    private func zoomOut() {
        // Notify your map view to zoom out
    }

    private func recenterMap() {
        // Notify your map view to recenter
    }
}

// MARK: - CPMapTemplateDelegate

extension NavigationCarPlayDelegate: CPMapTemplateDelegate {

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        selectedPreviewFor trip: CPTrip,
        using routeChoice: CPRouteChoice
    ) {
        // User selected a route preview
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        startedTrip trip: CPTrip,
        using routeChoice: CPRouteChoice
    ) {
        startNavigation(for: trip, routeChoice: routeChoice)
    }

    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        navigationSession?.cancelTrip()
        navigationSession = nil
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        panWith direction: CPMapTemplate.PanDirection
    ) {
        // Handle map panning
    }

    // iOS 26+: Multitouch support
    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didUpdatePanGestureWithTranslation translation: CGPoint,
        velocity: CGPoint
    ) {
        // Handle pan gesture
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didEndPanGestureWithVelocity velocity: CGPoint
    ) {
        // Handle pan gesture end
    }
}

// MARK: - CPSearchTemplateDelegate

extension NavigationCarPlayDelegate: CPSearchTemplateDelegate {

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        Task {
            let results = await navigationManager.search(query: searchText)

            let items = results.map { result in
                let item = CPListItem(text: result.name, detailText: result.address)

                item.handler = { [weak self] _, completion in
                    self?.startNavigationTo(result)
                    completion()
                }

                return item
            }

            completionHandler(items)
        }
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        selectedResult item: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
```

### EV Charging / Parking App Example

```swift
import CarPlay

class ChargingCarPlayDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    private var interfaceController: CPInterfaceController?
    private let chargingManager = ChargingManager.shared

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupChargingInterface()
    }

    // MARK: - Private Methods

    private func setupChargingInterface() {
        let tabBar = CPTabBarTemplate(templates: [
            createNearbyTemplate(),
            createFavoritesTemplate(),
            createRecentTemplate()
        ])

        interfaceController?.setRootTemplate(tabBar, animated: false)
    }

    private func createNearbyTemplate() -> CPPointOfInterestTemplate {
        let nearbyChargers = chargingManager.nearbyChargers.prefix(12).map { charger in
            let poi = CPPointOfInterest(
                location: MKMapItem(placemark: MKPlacemark(coordinate: charger.coordinate)),
                title: charger.name,
                subtitle: charger.availabilityText,
                summary: charger.pricingText,
                detailTitle: charger.name,
                detailSubtitle: charger.address,
                detailSummary: charger.detailText,
                pinImage: UIImage(systemName: "bolt.car.fill")
            )

            poi.primaryButton = CPTextButton(
                title: "Navigate",
                textStyle: .normal
            ) { [weak self] _ in
                self?.navigateToCharger(charger)
            }

            poi.secondaryButton = CPTextButton(
                title: "Details",
                textStyle: .normal
            ) { [weak self] _ in
                self?.showChargerDetails(charger)
            }

            return poi
        }

        let template = CPPointOfInterestTemplate(
            title: "Nearby Chargers",
            pointsOfInterest: Array(nearbyChargers),
            selectedIndex: NSNotFound
        )
        template.tabTitle = "Nearby"
        template.tabImage = UIImage(systemName: "location.fill")

        return template
    }

    private func createFavoritesTemplate() -> CPListTemplate {
        let favorites = chargingManager.favoriteChargers.map { charger in
            let item = CPListItem(
                text: charger.name,
                detailText: charger.address
            )
            item.accessoryType = .disclosureIndicator

            item.handler = { [weak self] _, completion in
                self?.showChargerDetails(charger)
                completion()
            }

            return item
        }

        let section = CPListSection(items: favorites)
        let template = CPListTemplate(title: "Favorites", sections: [section])
        template.tabSystemItem = .favorites

        return template
    }

    private func createRecentTemplate() -> CPListTemplate {
        let recent = chargingManager.recentChargers.map { charger in
            let item = CPListItem(
                text: charger.name,
                detailText: charger.lastVisited.formatted()
            )
            item.accessoryType = .disclosureIndicator

            item.handler = { [weak self] _, completion in
                self?.showChargerDetails(charger)
                completion()
            }

            return item
        }

        let section = CPListSection(items: recent)
        let template = CPListTemplate(title: "Recent", sections: [section])
        template.tabSystemItem = .recents

        return template
    }

    private func showChargerDetails(_ charger: Charger) {
        let items = [
            CPInformationItem(title: "Address", detail: charger.address),
            CPInformationItem(title: "Availability", detail: charger.availabilityText),
            CPInformationItem(title: "Connector Types", detail: charger.connectorTypes.joined(separator: ", ")),
            CPInformationItem(title: "Pricing", detail: charger.pricingText),
            CPInformationItem(title: "Hours", detail: charger.operatingHours)
        ]

        let navigateAction = CPTextButton(
            title: "Navigate",
            textStyle: .confirm
        ) { [weak self] _ in
            self?.navigateToCharger(charger)
        }

        let favoriteAction = CPTextButton(
            title: charger.isFavorite ? "Remove Favorite" : "Add Favorite",
            textStyle: .normal
        ) { [weak self] _ in
            self?.toggleFavorite(charger)
        }

        let template = CPInformationTemplate(
            title: charger.name,
            layout: .leading,
            items: items,
            actions: [navigateAction, favoriteAction]
        )

        interfaceController?.pushTemplate(template, animated: true)
    }

    private func navigateToCharger(_ charger: Charger) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: charger.coordinate))
        mapItem.name = charger.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func toggleFavorite(_ charger: Charger) {
        chargingManager.toggleFavorite(charger)
        interfaceController?.popTemplate(animated: true)
    }
}
```

---

## Common Patterns

### Managing Template State

```swift
import CarPlay

@Observable
class CarPlayState {
    var currentTemplate: CPTemplate?
    var isConnected = false
    var navigationSession: CPNavigationSession?
}

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private let state = CarPlayState()

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        state.isConnected = true

        // Restore state if needed
        if let lastTemplate = state.currentTemplate {
            interfaceController.setRootTemplate(lastTemplate, animated: false)
        } else {
            setupInitialInterface()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        state.isConnected = false
    }

    private func setupInitialInterface() {
        // Initial setup
    }
}
```

### Handling User Interactions

```swift
private func createInteractiveList() -> CPListTemplate {
    let items = dataSource.items.map { item in
        let listItem = CPListItem(
            text: item.title,
            detailText: item.subtitle,
            image: item.image
        )

        // Configure accessory
        listItem.accessoryType = item.hasChildren ? .disclosureIndicator : .none

        // Configure handler
        listItem.handler = { [weak self] selectedItem, completion in
            defer { completion() } // Always call completion

            guard let self = self else { return }

            if item.hasChildren {
                self.navigateToDetail(item)
            } else {
                self.performAction(item)
            }
        }

        return listItem
    }

    let section = CPListSection(items: items, header: "Items", sectionIndexTitle: nil)
    return CPListTemplate(title: "List", sections: [section])
}
```

### Updating Templates Dynamically

```swift
class DynamicListManager {

    private weak var listTemplate: CPListTemplate?
    private var items: [DataItem] = []

    func setListTemplate(_ template: CPListTemplate) {
        self.listTemplate = template
    }

    func updateItems(_ newItems: [DataItem]) {
        self.items = newItems

        let listItems = newItems.map { item in
            let listItem = CPListItem(text: item.title, detailText: item.subtitle)
            listItem.handler = { [weak self] _, completion in
                self?.handleSelection(item)
                completion()
            }
            return listItem
        }

        let section = CPListSection(items: listItems)
        listTemplate?.updateSections([section])
    }

    func updateSingleItem(_ item: DataItem, at index: Int) {
        guard index < items.count else { return }

        items[index] = item

        // Update just the specific item if needed
        let listItems = items.map { item in
            CPListItem(text: item.title, detailText: item.subtitle)
        }

        let section = CPListSection(items: listItems)
        listTemplate?.updateSections([section])
    }

    private func handleSelection(_ item: DataItem) {
        // Handle item selection
    }
}
```

### Presenting Alerts and Action Sheets

```swift
func showAlert(title: String, message: String, actions: [AlertAction]) {
    let alertActions = actions.map { action in
        CPAlertAction(
            title: action.title,
            style: action.isDestructive ? .destructive : .default
        ) { [weak self] _ in
            self?.handleAlertAction(action)
            self?.interfaceController?.dismissTemplate(animated: true)
        }
    }

    // Add cancel action
    let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
        self?.interfaceController?.dismissTemplate(animated: true)
    }

    let alertTemplate = CPAlertTemplate(
        titleVariants: [title],
        actions: alertActions + [cancelAction]
    )

    interfaceController?.presentTemplate(alertTemplate, animated: true)
}

func showActionSheet(title: String, message: String, actions: [SheetAction]) {
    let sheetActions = actions.map { action in
        CPAlertAction(
            title: action.title,
            style: action.isDestructive ? .destructive : .default
        ) { [weak self] _ in
            self?.handleSheetAction(action)
            self?.interfaceController?.dismissTemplate(animated: true)
        }
    }

    let actionSheetTemplate = CPActionSheetTemplate(
        title: title,
        message: message,
        actions: sheetActions
    )

    interfaceController?.presentTemplate(actionSheetTemplate, animated: true)
}
```

---

## SwiftUI Integration

### SwiftUI App with CarPlay Support

For SwiftUI apps using the `@main` App protocol, you need to disable automatic scene manifest generation:

**Build Settings:**
1. Set `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` to `NO`
2. Manually configure `Info.plist` with scene manifest

```swift
import SwiftUI
import CarPlay

@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

// Separate CarPlay scene delegate
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?

    // Access shared app state
    private var appState: AppState {
        // Access via shared container or dependency injection
        AppState.shared
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupInterface()
    }

    private func setupInterface() {
        // Build CarPlay UI using app state
    }
}
```

### Sharing Data Between iPhone and CarPlay

```swift
import SwiftUI
import Observation

@Observable
class SharedMusicState {
    static let shared = SharedMusicState()

    var currentTrack: Track?
    var isPlaying = false
    var queue: [Track] = []
    var progress: Double = 0

    private init() {}

    func play(track: Track) {
        currentTrack = track
        isPlaying = true
        // Start playback
    }

    func togglePlayPause() {
        isPlaying.toggle()
        // Update playback state
    }
}

// SwiftUI View
struct MusicPlayerView: View {
    @Environment(SharedMusicState.self) private var musicState

    var body: some View {
        VStack {
            if let track = musicState.currentTrack {
                Text(track.title)
                    .font(.headline)
                Text(track.artist)
                    .font(.subheadline)

                Button(action: { musicState.togglePlayPause() }) {
                    Image(systemName: musicState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
            }
        }
    }
}

// CarPlay Integration
class MusicCarPlayDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var musicState: SharedMusicState { SharedMusicState.shared }
    private var observation: Any?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupObservation()
        setupInterface()
    }

    private func setupObservation() {
        // Observe state changes and update CarPlay UI
        observation = withObservationTracking {
            _ = musicState.currentTrack
            _ = musicState.isPlaying
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateNowPlayingInfo()
                self?.setupObservation() // Re-register
            }
        }
    }

    private func updateNowPlayingInfo() {
        // Update Now Playing template with current state
    }

    private func setupInterface() {
        // Build initial interface
    }
}
```

### Using Combine for Reactive Updates

```swift
import Combine
import CarPlay

class ReactiveCarPlayManager {

    private var cancellables = Set<AnyCancellable>()
    private weak var listTemplate: CPListTemplate?

    func observeDataChanges(_ publisher: AnyPublisher<[Item], Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.updateListTemplate(with: items)
            }
            .store(in: &cancellables)
    }

    private func updateListTemplate(with items: [Item]) {
        let listItems = items.map { item in
            CPListItem(text: item.title, detailText: item.subtitle)
        }

        let section = CPListSection(items: listItems)
        listTemplate?.updateSections([section])
    }
}
```

---

## Error Handling

### Common Errors and Solutions

```swift
enum CarPlayError: LocalizedError {
    case templateStackFull
    case invalidTemplate
    case connectionLost
    case entitlementMissing
    case timeoutError

    var errorDescription: String? {
        switch self {
        case .templateStackFull:
            return "Cannot push more templates. Maximum depth reached."
        case .invalidTemplate:
            return "The template configuration is invalid."
        case .connectionLost:
            return "CarPlay connection was lost."
        case .entitlementMissing:
            return "CarPlay entitlement is not configured."
        case .timeoutError:
            return "The operation timed out."
        }
    }
}
```

### Safe Template Operations

```swift
class SafeCarPlayController {

    private var interfaceController: CPInterfaceController?
    private var templateStack: [CPTemplate] = []
    private let maxDepth: Int

    init(maxDepth: Int = 5) {
        self.maxDepth = maxDepth
    }

    func setInterfaceController(_ controller: CPInterfaceController) {
        self.interfaceController = controller
        templateStack = []
    }

    func safelyPushTemplate(_ template: CPTemplate) async throws {
        guard templateStack.count < maxDepth else {
            throw CarPlayError.templateStackFull
        }

        return try await withCheckedThrowingContinuation { continuation in
            interfaceController?.pushTemplate(template, animated: true) { success, error in
                if success {
                    self.templateStack.append(template)
                    continuation.resume()
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CarPlayError.invalidTemplate)
                }
            }
        }
    }

    func safelyPopTemplate() async throws {
        guard !templateStack.isEmpty else { return }

        return try await withCheckedThrowingContinuation { continuation in
            interfaceController?.popTemplate(animated: true) { success, error in
                if success {
                    self.templateStack.removeLast()
                    continuation.resume()
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CarPlayError.invalidTemplate)
                }
            }
        }
    }

    func safelyPopToRoot() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            interfaceController?.popToRootTemplate(animated: true) { success, error in
                if success {
                    self.templateStack = [self.templateStack.first].compactMap { $0 }
                    continuation.resume()
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CarPlayError.invalidTemplate)
                }
            }
        }
    }

    var canPush: Bool {
        templateStack.count < maxDepth
    }

    var currentDepth: Int {
        templateStack.count
    }
}
```

### Handling Connection State

```swift
class CarPlayConnectionManager: CPTemplateApplicationSceneDelegate {

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(Error)
    }

    private(set) var state: ConnectionState = .disconnected
    var onStateChange: ((ConnectionState) -> Void)?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        state = .connected
        onStateChange?(.connected)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        state = .disconnected
        onStateChange?(.disconnected)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didFailToConnectInterfaceControllerWithError error: Error
    ) {
        state = .error(error)
        onStateChange?(.error(error))
    }
}
```

---

## Best Practices

### Driver Safety Guidelines

Following Apple's Human Interface Guidelines for CarPlay:

1. **Minimize Touchscreen Interactions**
   - Require as few manual interactions as possible
   - Use voice commands and Siri integration
   - Design for glanceable information

2. **Never Lock Users Out**
   - App must work when iPhone is locked or in trunk
   - Never instruct users to pick up their iPhone
   - All CarPlay flows must be possible without iPhone interaction

3. **Keep Information Glanceable**
   - Use large, readable text
   - Minimize cognitive load
   - Prioritize essential information

4. **Handle Errors Gracefully**
   - Avoid error alerts that block interaction
   - Communicate errors without requiring iPhone manipulation
   - Always call completion handlers promptly

### Code Organization

```swift
// MARK: - Recommended Project Structure

// CarPlay/
// ├── CarPlaySceneDelegate.swift       // Main scene delegate
// ├── Templates/
// │   ├── AudioTemplates.swift         // Audio-specific templates
// │   ├── NavigationTemplates.swift    // Navigation templates
// │   └── ListTemplates.swift          // Reusable list templates
// ├── Managers/
// │   ├── CarPlayConnectionManager.swift
// │   └── CarPlayTemplateManager.swift
// └── Extensions/
//     └── CPListItem+Extensions.swift
```

### Performance Considerations

```swift
// DO: Lazy load content
func createLazyLoadingList() -> CPListTemplate {
    let placeholderItems = (0..<10).map { _ in
        CPListItem(text: "Loading...", detailText: nil)
    }

    let template = CPListTemplate(
        title: "Content",
        sections: [CPListSection(items: placeholderItems)]
    )

    // Load actual content asynchronously
    Task {
        let items = await loadItems()
        await MainActor.run {
            let listItems = items.map { CPListItem(text: $0.title, detailText: $0.subtitle) }
            template.updateSections([CPListSection(items: listItems)])
        }
    }

    return template
}

// DO: Reuse templates when possible
class TemplateCache {
    private var cachedTemplates: [String: CPTemplate] = [:]

    func template(for key: String, creator: () -> CPTemplate) -> CPTemplate {
        if let cached = cachedTemplates[key] {
            return cached
        }

        let template = creator()
        cachedTemplates[key] = template
        return template
    }

    func invalidate(key: String) {
        cachedTemplates.removeValue(forKey: key)
    }

    func invalidateAll() {
        cachedTemplates.removeAll()
    }
}

// DON'T: Create heavy objects in handlers
// BAD
item.handler = { _, completion in
    let heavyObject = HeavyProcessor() // Don't do this
    heavyObject.process()
    completion()
}

// GOOD
item.handler = { [weak self] _, completion in
    self?.existingProcessor.process()
    completion()
}
```

### Testing

```swift
// Use CarPlay Simulator in Xcode
// 1. Run your app on a simulator
// 2. Open I/O > External Displays > CarPlay
// 3. Test all template flows

// Unit testing templates
final class CarPlayTemplateTests: XCTestCase {

    var sut: CarPlayTemplateBuilder!

    override func setUp() {
        super.setUp()
        sut = CarPlayTemplateBuilder()
    }

    func testListTemplateCreation() {
        let items = [
            TestItem(title: "Item 1", subtitle: "Subtitle 1"),
            TestItem(title: "Item 2", subtitle: "Subtitle 2")
        ]

        let template = sut.createListTemplate(items: items)

        XCTAssertEqual(template.sectionCount, 1)
        XCTAssertEqual(template.itemCount(inSection: 0), 2)
    }

    func testTemplateStackLimit() async {
        let controller = SafeCarPlayController(maxDepth: 3)

        // Should succeed
        try? await controller.safelyPushTemplate(CPListTemplate(title: "1", sections: []))
        try? await controller.safelyPushTemplate(CPListTemplate(title: "2", sections: []))
        try? await controller.safelyPushTemplate(CPListTemplate(title: "3", sections: []))

        XCTAssertEqual(controller.currentDepth, 3)
        XCTAssertFalse(controller.canPush)

        // Should throw
        do {
            try await controller.safelyPushTemplate(CPListTemplate(title: "4", sections: []))
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is CarPlayError)
        }
    }
}
```

---

## Troubleshooting

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Application does not implement CarPlay template application lifecycle methods" | SwiftUI lifecycle conflict | Disable `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` in Build Settings |
| "Maximum level exception" | Template stack depth exceeded | Redesign navigation flow; use tabs instead of deep hierarchies |
| CarPlay not appearing in simulator | Missing entitlement | Add CarPlay entitlement to debug profile |
| Templates not updating | Not calling completion handler | Always call completion handlers in item handlers |
| App crashes on connection | Nil interface controller | Store interface controller reference properly |
| Now Playing not showing | MPNowPlayingInfoCenter not configured | Set up MPNowPlayingInfoCenter alongside CarPlay |

### Debugging Tips

```swift
// Enable CarPlay logging
func enableCarPlayDebugging() {
    // Add to your scene delegate
    #if DEBUG
    print("CarPlay: Scene connected")
    print("CarPlay: Interface controller: \(String(describing: interfaceController))")
    print("CarPlay: Current template stack depth: \(interfaceController?.templates.count ?? 0)")
    #endif
}

// Monitor template operations
extension CPInterfaceController {
    func debugPushTemplate(_ template: CPTemplate, animated: Bool) {
        #if DEBUG
        print("CarPlay: Pushing template: \(type(of: template))")
        print("CarPlay: Current stack depth before push: \(templates.count)")
        #endif

        pushTemplate(template, animated: animated) { success, error in
            #if DEBUG
            if success {
                print("CarPlay: Push succeeded, new depth: \(self.templates.count)")
            } else {
                print("CarPlay: Push failed: \(error?.localizedDescription ?? "Unknown error")")
            }
            #endif
        }
    }
}
```

### SwiftUI Lifecycle Fix

If your SwiftUI app shows the error "Application does not implement CarPlay template application lifecycle methods":

1. Open your project's Build Settings
2. Search for "Application Scene Manifest"
3. Set `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` to `NO`
4. Ensure your `Info.plist` has the complete scene manifest configuration
5. Verify your `CarPlaySceneDelegate` properly conforms to `CPTemplateApplicationSceneDelegate`

---

## iOS 26 Changes

### New Features in iOS 26

#### Liquid Glass Design
CarPlay adopts the new Liquid Glass UI design language:
- App icons and UI elements have glass-like depth
- New icon appearance modes: Default, Dark, and Clear variants
- Consistent design with iOS 26 on iPhone

#### Widgets Support
```swift
// Widgets from WidgetKit now appear in CarPlay
// No special CarPlay code needed - existing widgets work automatically
// Widgets appear to the left of CarPlay Dashboard
// iOS 26.2+: Support for 3+ widget rows on larger displays

// For widget-specific CarPlay optimizations:
struct MyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MyWidget", provider: Provider()) { entry in
            MyWidgetView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("Shows important info")
        .supportedFamilies([.systemSmall, .systemMedium])
        // Widgets automatically adapt to CarPlay display
    }
}
```

#### Live Activities Support
```swift
import ActivityKit

// Live Activities now sync to CarPlay automatically
// Perfect for tracking deliveries, flights, sports scores

struct DeliveryActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var estimatedArrival: Date
    }

    var orderNumber: String
    var restaurantName: String
}

// Start activity - it will appear in CarPlay Dashboard
func startDeliveryTracking(order: Order) async throws {
    let attributes = DeliveryActivity(
        orderNumber: order.id,
        restaurantName: order.restaurant
    )

    let initialState = DeliveryActivity.ContentState(
        status: "Preparing",
        estimatedArrival: order.estimatedArrival
    )

    let activity = try Activity.request(
        attributes: attributes,
        content: .init(state: initialState, staleDate: nil),
        pushType: .token
    )
}
```

#### Multitouch Navigation Support
```swift
// iOS 26+: Enhanced gesture support for navigation apps
extension NavigationCarPlayDelegate: CPMapTemplateDelegate {

    // Handle pinch-to-zoom gestures
    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didUpdatePanGestureWithTranslation translation: CGPoint,
        velocity: CGPoint
    ) {
        // Handle pan gesture for map movement
        mapView?.handlePanGesture(translation: translation, velocity: velocity)
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didEndPanGestureWithVelocity velocity: CGPoint
    ) {
        // Handle gesture end
        mapView?.handlePanGestureEnd(velocity: velocity)
    }

    // New in iOS 26: Pinch gesture support
    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didUpdatePinchGestureWithScale scale: CGFloat,
        velocity: CGFloat
    ) {
        mapView?.handlePinchGesture(scale: scale, velocity: velocity)
    }

    func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didEndPinchGestureWithScale scale: CGFloat
    ) {
        mapView?.handlePinchGestureEnd(scale: scale)
    }
}
```

#### Video Streaming When Parked
```swift
// iOS 26+: AirPlay video support when vehicle is parked
// Third-party apps can implement custom video support

import AVKit

class VideoCarPlayManager {

    private var player: AVPlayer?
    private var isVehicleParked = false

    func setupVideoPlayback(for url: URL) {
        guard isVehicleParked else {
            // Video only available when parked
            showParkingRequiredAlert()
            return
        }

        player = AVPlayer(url: url)
        // Configure for CarPlay AirPlay streaming
    }

    func handleVehicleStateChange(isParked: Bool) {
        isVehicleParked = isParked

        if !isParked && player?.rate != 0 {
            // Automatically pause when vehicle starts moving
            player?.pause()
        }
    }

    private func showParkingRequiredAlert() {
        // Inform user that video requires parked vehicle
    }
}
```

#### Smart Display Zoom
```swift
// iOS 26+: Smart Display Zoom automatically adjusts UI density
// No code changes required - CarPlay handles this automatically
// Users can configure in Settings app within CarPlay

// However, you can optimize your templates for different display sizes:
func createAdaptiveListTemplate(displayInfo: CPDisplayInfo?) -> CPListTemplate {
    let itemsPerSection: Int

    if let displayInfo = displayInfo {
        // Adjust content density based on display
        switch displayInfo.displayType {
        case .higherResolution:
            itemsPerSection = 10
        default:
            itemsPerSection = 6
        }
    } else {
        itemsPerSection = 6
    }

    // Create template with appropriate item count
    let items = dataSource.items.prefix(itemsPerSection).map { item in
        CPListItem(text: item.title, detailText: item.subtitle)
    }

    return CPListTemplate(title: "Content", sections: [CPListSection(items: Array(items))])
}
```

#### Enhanced Messages Integration
```swift
// iOS 26+: Tapback support and pinned conversations in CarPlay
// These features work automatically through SiriKit
// No additional code required for basic functionality

// For communication apps, ensure proper SiriKit integration:
class IntentHandler: INExtension, INSendMessageIntentHandling {

    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Handle message sending
        let response = INSendMessageIntentResponse(code: .success, userActivity: nil)
        completion(response)
    }
}
```

#### Compact Incoming Call UI
```swift
// iOS 26+: Incoming calls no longer take over the entire screen
// This is handled automatically by CallKit
// Ensure your app properly implements CallKit for VoIP:

import CallKit

class CallManager: NSObject, CXProviderDelegate {

    private let provider: CXProvider

    override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.phoneNumber]

        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncomingCall(from caller: String, completion: @escaping (Error?) -> Void) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: caller)
        update.hasVideo = false

        let uuid = UUID()
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            completion(error)
        }
    }

    func providerDidReset(_ provider: CXProvider) {
        // Handle provider reset
    }
}
```

### Migration from Earlier iOS Versions

```swift
// Check for iOS 26+ features
func configureCarPlayForCurrentVersion() {
    if #available(iOS 26, *) {
        // Use iOS 26+ features
        setupModernCarPlayInterface()
    } else {
        // Fallback for earlier versions
        setupLegacyCarPlayInterface()
    }
}

@available(iOS 26, *)
func setupModernCarPlayInterface() {
    // Use new iOS 26 features
    // - Multitouch gestures
    // - Enhanced template options
    // - Video streaming support (when parked)
}

func setupLegacyCarPlayInterface() {
    // Standard CarPlay implementation
    // Works on iOS 14-25
}
```

---

## Additional Resources

- [Apple CarPlay Developer Portal](https://developer.apple.com/carplay/)
- [CarPlay Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/carplay)
- [CarPlay Framework Documentation](https://developer.apple.com/documentation/carplay)
- [WWDC 2025: Turbocharge your app for CarPlay](https://developer.apple.com/videos/play/wwdc2025/216/)
- [WWDC 2020: Accelerate your app with CarPlay](https://developer.apple.com/videos/play/wwdc2020/10635/)
- [CarPlay App Programming Guide (PDF)](https://developer.apple.com/carplay/documentation/CarPlay-App-Programming-Guide.pdf)
