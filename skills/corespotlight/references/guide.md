# CoreSpotlight Framework Guide

A comprehensive guide for integrating CoreSpotlight to make your app's content searchable via Spotlight on iOS.

---

## 1. Overview & Purpose

CoreSpotlight is Apple's framework for indexing your app's content and making it searchable through the system's Spotlight search. When users search on their device, indexed content from your app appears alongside other system results, providing deep links directly into your app.

### Key Benefits

- **Discoverability:** Users find your app's content through system-wide search
- **Deep Linking:** Direct navigation to specific content within your app
- **App Intents Integration:** Connect indexed items with App Shortcuts and Siri
- **Apple Intelligence:** Enable AI-powered summarization and prioritization (iOS 18+)

### When to Use CoreSpotlight

- Apps with user-generated content (notes, documents, recipes)
- Media libraries (songs, podcasts, videos)
- E-commerce apps (products, orders)
- Social apps (messages, contacts, conversations)
- Any app where users need to quickly find specific content

---

## 2. Setup & Configuration

### Import the Framework

```swift
import CoreSpotlight
import UniformTypeIdentifiers
```

### Check Availability

Always verify indexing is available before attempting operations:

```swift
func canIndexContent() -> Bool {
    CSSearchableIndex.isIndexingAvailable()
}
```

### Info.plist Configuration

For handling Spotlight search results, add the activity type to your `Info.plist`:

```xml
<key>NSUserActivityTypes</key>
<array>
    <string>com.yourapp.viewItem</string>
</array>
```

### CoreSpotlight Delegate (iOS 18+)

For Apple Intelligence features, create a CoreSpotlight Delegate app extension:

1. In Xcode, add a new target
2. Select "CoreSpotlight Delegate"
3. Implement the delegate methods

---

## 3. Core Concepts

### CSSearchableItem

A `CSSearchableItem` represents a single piece of searchable content. It contains:

- **uniqueIdentifier:** A string that uniquely identifies the item within your app
- **domainIdentifier:** An optional string to group related items (useful for batch deletion)
- **attributeSet:** A `CSSearchableItemAttributeSet` containing metadata

```swift
let item = CSSearchableItem(
    uniqueIdentifier: "article-123",
    domainIdentifier: "articles",
    attributeSet: attributeSet
)
```

### CSSearchableItemAttributeSet

The attribute set contains all metadata about your searchable item. Common properties include:

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String?` | The primary title displayed in search results |
| `displayName` | `String?` | Localized name suitable for UI display |
| `contentDescription` | `String?` | A description of the item's content |
| `contentType` | `String?` | UTI identifier (e.g., `UTType.text.identifier`) |
| `thumbnailData` | `Data?` | Image data for the thumbnail |
| `thumbnailURL` | `URL?` | Local file URL for the thumbnail |
| `keywords` | `[String]?` | Additional searchable keywords |
| `contentURL` | `URL?` | File URL if indexing a file on disk |
| `contentCreationDate` | `Date?` | When the content was created |
| `rankingHint` | `NSNumber?` | Relative importance among your app's items |

### Domain Identifiers

Use domain identifiers to logically group content:

```swift
// Group by content type
let articleItem = CSSearchableItem(
    uniqueIdentifier: "article-123",
    domainIdentifier: "com.myapp.articles",
    attributeSet: articleAttributes
)

let recipeItem = CSSearchableItem(
    uniqueIdentifier: "recipe-456",
    domainIdentifier: "com.myapp.recipes",
    attributeSet: recipeAttributes
)
```

---

## 4. Indexing Content for Spotlight Search

### Basic Indexing Example

```swift
import CoreSpotlight
import UniformTypeIdentifiers

struct Article: Identifiable {
    let id: String
    let title: String
    let summary: String
    let author: String
    let createdAt: Date
    var thumbnailData: Data?
}

// MARK: - SpotlightIndexer

@Observable
final class SpotlightIndexer {

    private let index = CSSearchableIndex.default()

    // MARK: - Index Single Item

    func indexArticle(_ article: Article) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = article.title
        attributeSet.contentDescription = article.summary
        attributeSet.displayName = article.title
        attributeSet.keywords = ["article", article.author]
        attributeSet.thumbnailData = article.thumbnailData
        attributeSet.contentCreationDate = article.createdAt
        attributeSet.rankingHint = NSNumber(value: 1)

        let item = CSSearchableItem(
            uniqueIdentifier: article.id,
            domainIdentifier: "com.myapp.articles",
            attributeSet: attributeSet
        )

        // Set expiration (default is 30 days)
        item.expirationDate = Calendar.current.date(
            byAdding: .month,
            value: 6,
            to: Date.now
        )

        try await index.indexSearchableItems([item])
    }

    // MARK: - Index Multiple Items

    func indexArticles(_ articles: [Article]) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let items = articles.map { article -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = article.title
            attributeSet.contentDescription = article.summary
            attributeSet.displayName = article.title
            attributeSet.keywords = ["article", article.author]
            attributeSet.thumbnailData = article.thumbnailData
            attributeSet.contentCreationDate = article.createdAt

            let item = CSSearchableItem(
                uniqueIdentifier: article.id,
                domainIdentifier: "com.myapp.articles",
                attributeSet: attributeSet
            )

            item.expirationDate = Calendar.current.date(
                byAdding: .month,
                value: 6,
                to: Date.now
            )

            return item
        }

        try await index.indexSearchableItems(items)
    }
}
```

### Media Content Indexing

```swift
struct Song: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let genre: String
    let duration: TimeInterval
    var playCount: Int
    var lastPlayedDate: Date?
}

extension SpotlightIndexer {

    func indexSong(_ song: Song) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .audio)
        attributeSet.title = song.title
        attributeSet.artist = song.artist
        attributeSet.album = song.album
        attributeSet.genre = song.genre
        attributeSet.duration = NSNumber(value: song.duration)
        attributeSet.playCount = NSNumber(value: song.playCount)
        attributeSet.lastUsedDate = song.lastPlayedDate
        attributeSet.keywords = [song.artist, song.album, song.genre]

        let item = CSSearchableItem(
            uniqueIdentifier: song.id,
            domainIdentifier: "com.myapp.music",
            attributeSet: attributeSet
        )

        try await index.indexSearchableItems([item])
    }
}
```

### Batch Indexing for Large Datasets

For large datasets, use batch operations with a custom index:

```swift
extension SpotlightIndexer {

    func batchIndexArticles(_ articles: [Article]) async throws {
        let customIndex = CSSearchableIndex(name: "com.myapp.articles")

        let items = articles.map { createSearchableItem(from: $0) }

        // Store client state for recovery
        var clientData = Data()
        // Encode your state tracking data here

        customIndex.beginBatch()
        customIndex.indexSearchableItems(items)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            customIndex.endBatch(withClientState: clientData) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func createSearchableItem(from article: Article) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = article.title
        attributeSet.contentDescription = article.summary

        return CSSearchableItem(
            uniqueIdentifier: article.id,
            domainIdentifier: "com.myapp.articles",
            attributeSet: attributeSet
        )
    }
}
```

---

## 5. Updating and Deleting Indexed Items

### Update an Item

Re-indexing an item with the same `uniqueIdentifier` automatically updates it:

```swift
extension SpotlightIndexer {

    func updateArticle(_ article: Article) async throws {
        // Simply re-index with the same identifier
        try await indexArticle(article)
    }
}
```

### Delete by Identifiers

```swift
extension SpotlightIndexer {

    func deleteArticle(withId id: String) async throws {
        try await index.deleteSearchableItems(withIdentifiers: [id])
    }

    func deleteArticles(withIds ids: [String]) async throws {
        try await index.deleteSearchableItems(withIdentifiers: ids)
    }
}
```

### Delete by Domain

Delete all items in a domain (useful for clearing categories):

```swift
extension SpotlightIndexer {

    func deleteAllArticles() async throws {
        try await index.deleteSearchableItems(
            withDomainIdentifiers: ["com.myapp.articles"]
        )
    }

    func deleteMultipleDomains(_ domains: [String]) async throws {
        try await index.deleteSearchableItems(withDomainIdentifiers: domains)
    }
}
```

### Delete All Items

Clear the entire index for your app:

```swift
extension SpotlightIndexer {

    func deleteAllIndexedContent() async throws {
        try await index.deleteAllSearchableItems()
    }
}
```

---

## 6. Handling User Taps on Search Results

When a user taps a Spotlight search result, your app receives an `NSUserActivity`. Handle this to navigate to the appropriate content.

### SwiftUI Implementation

```swift
import SwiftUI
import CoreSpotlight

@main
struct MyApp: App {

    @State private var navigationPath = NavigationPath()
    @State private var selectedArticleId: String?

    var body: some Scene {
        WindowGroup {
            ContentView(
                navigationPath: $navigationPath,
                selectedArticleId: $selectedArticleId
            )
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                handleSpotlightActivity(userActivity)
            }
        }
    }

    private func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        // Navigate to the content
        selectedArticleId = identifier
    }
}
```

### Navigation Coordinator Pattern

```swift
import SwiftUI
import CoreSpotlight

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case article(id: String)
    case song(id: String)
    case recipe(id: String)
}

// MARK: - Navigation Coordinator

@Observable
final class NavigationCoordinator {

    var path = NavigationPath()

    func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        // Parse the identifier to determine content type
        if identifier.hasPrefix("article-") {
            path.append(AppDestination.article(id: identifier))
        } else if identifier.hasPrefix("song-") {
            path.append(AppDestination.song(id: identifier))
        } else if identifier.hasPrefix("recipe-") {
            path.append(AppDestination.recipe(id: identifier))
        }
    }
}

// MARK: - Content View

struct ContentView: View {

    @State private var coordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView()
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .article(let id):
                        ArticleDetailView(articleId: id)
                    case .song(let id):
                        SongDetailView(songId: id)
                    case .recipe(let id):
                        RecipeDetailView(recipeId: id)
                    }
                }
        }
        .environment(coordinator)
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            coordinator.handleSpotlightActivity(userActivity)
        }
    }
}
```

### Using Domain Identifiers for Routing

```swift
extension NavigationCoordinator {

    func handleSpotlightActivityWithDomain(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == CSSearchableItemActionType else { return }

        let userInfo = userActivity.userInfo

        guard let identifier = userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        // Check contentAttributeSet for domain information
        if let attributeSet = userActivity.contentAttributeSet,
           let domain = attributeSet.domainIdentifier {

            switch domain {
            case "com.myapp.articles":
                path.append(AppDestination.article(id: identifier))
            case "com.myapp.music":
                path.append(AppDestination.song(id: identifier))
            case "com.myapp.recipes":
                path.append(AppDestination.recipe(id: identifier))
            default:
                break
            }
        }
    }
}
```

---

## 7. App Shortcuts Integration

Connect CoreSpotlight items with App Intents for Siri and Shortcuts integration.

### Define an App Entity

```swift
import AppIntents
import CoreSpotlight

struct ArticleEntity: AppEntity, IndexedEntity {

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Article"
    }

    static var defaultQuery = ArticleQuery()

    var id: String
    var title: String
    var summary: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(summary)"
        )
    }
}

// MARK: - Article Query

struct ArticleQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [ArticleEntity] {
        // Fetch articles from your data store
        return identifiers.compactMap { id in
            // Return ArticleEntity for each id
            ArticleEntity(id: id, title: "Sample", summary: "Summary")
        }
    }

    func suggestedEntities() async throws -> [ArticleEntity] {
        // Return suggested articles
        []
    }
}
```

### Associate App Entity with Searchable Item

```swift
extension SpotlightIndexer {

    func indexArticleWithEntity(_ article: Article, isFavorite: Bool) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = article.title
        attributeSet.contentDescription = article.summary
        attributeSet.displayName = article.title

        let item = CSSearchableItem(
            uniqueIdentifier: article.id,
            domainIdentifier: "com.myapp.articles",
            attributeSet: attributeSet
        )

        // Create the App Entity
        let entity = ArticleEntity(
            id: article.id,
            title: article.title,
            summary: article.summary
        )

        // Associate with priority (favorites get higher priority)
        let priority = isFavorite ? 10 : 1
        item.associateAppEntity(entity, priority: priority)

        try await index.indexSearchableItems([item])
    }

    func indexArticlesWithEntities(_ articles: [Article], favorites: Set<String>) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let items = articles.map { article -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = article.title
            attributeSet.contentDescription = article.summary

            let item = CSSearchableItem(
                uniqueIdentifier: article.id,
                domainIdentifier: "com.myapp.articles",
                attributeSet: attributeSet
            )

            let entity = ArticleEntity(
                id: article.id,
                title: article.title,
                summary: article.summary
            )

            let isFavorite = favorites.contains(article.id)
            item.associateAppEntity(entity, priority: isFavorite ? 10 : 1)

            return item
        }

        try await index.indexSearchableItems(items)
    }
}
```

### Define an App Intent

```swift
import AppIntents

struct OpenArticleIntent: AppIntent {

    static var title: LocalizedStringResource = "Open Article"
    static var description = IntentDescription("Opens a specific article in the app")

    @Parameter(title: "Article")
    var article: ArticleEntity

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // The app will open and handle navigation via the entity
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct MyAppShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenArticleIntent(),
            phrases: [
                "Open \(\.$article) in \(.applicationName)",
                "Show \(\.$article) article"
            ],
            shortTitle: "Open Article",
            systemImageName: "doc.text"
        )
    }
}
```

---

## 8. SwiftUI Integration Patterns

### SpotlightIndexer as Environment Dependency

```swift
import SwiftUI

@main
struct MyApp: App {

    @State private var spotlightIndexer = SpotlightIndexer()
    @State private var coordinator = NavigationCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(spotlightIndexer)
                .environment(coordinator)
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    coordinator.handleSpotlightActivity(userActivity)
                }
                .task {
                    await initialIndexing()
                }
        }
    }

    private func initialIndexing() async {
        // Perform initial indexing on app launch
        do {
            let articles = await fetchAllArticles()
            try await spotlightIndexer.indexArticles(articles)
        } catch {
            print("Failed to index content: \(error)")
        }
    }

    private func fetchAllArticles() async -> [Article] {
        // Fetch from your data store
        []
    }
}
```

### Index on Content Creation

```swift
struct CreateArticleView: View {

    @Environment(SpotlightIndexer.self) private var indexer
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextEditor(text: $content)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await saveArticle()
                    }
                }
            }
        }
    }

    private func saveArticle() async {
        let article = Article(
            id: UUID().uuidString,
            title: title,
            summary: String(content.prefix(200)),
            author: "Current User",
            createdAt: Date.now
        )

        // Save to your data store
        // ...

        // Index for Spotlight
        do {
            try await indexer.indexArticle(article)
        } catch {
            print("Failed to index article: \(error)")
        }

        dismiss()
    }
}
```

### Index on Content Deletion

```swift
struct ArticleListView: View {

    @Environment(SpotlightIndexer.self) private var indexer
    @State private var articles: [Article] = []

    var body: some View {
        List {
            ForEach(articles) { article in
                ArticleRow(article: article)
            }
            .onDelete(perform: deleteArticles)
        }
    }

    private func deleteArticles(at offsets: IndexSet) {
        let idsToDelete = offsets.map { articles[$0].id }

        // Remove from local array
        articles.remove(atOffsets: offsets)

        // Remove from data store
        // ...

        // Remove from Spotlight index
        Task {
            do {
                try await indexer.deleteArticles(withIds: idsToDelete)
            } catch {
                print("Failed to remove from index: \(error)")
            }
        }
    }
}
```

### Search Your Own Index

```swift
import SwiftUI
import CoreSpotlight

struct SearchView: View {

    @State private var searchText = ""
    @State private var searchResults: [CSSearchableItem] = []

    var body: some View {
        NavigationStack {
            List(searchResults, id: \.uniqueIdentifier) { item in
                SearchResultRow(item: item)
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let queryString = "title == '*\(query)*'c"

        let context = CSSearchQueryContext()
        context.fetchAttributes = ["title", "contentDescription", "thumbnailData"]

        let searchQuery = CSSearchQuery(queryString: queryString, queryContext: context)

        var results = [CSSearchableItem]()

        do {
            for try await result in searchQuery.results {
                results.append(result.item)
            }

            await MainActor.run {
                searchResults = results
            }
        } catch {
            print("Search failed: \(error)")
        }
    }
}

struct SearchResultRow: View {

    let item: CSSearchableItem

    var body: some View {
        HStack {
            if let thumbnailData = item.attributeSet.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading) {
                Text(item.attributeSet.title ?? "Untitled")
                    .font(.headline)

                if let description = item.attributeSet.contentDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
```

---

## 9. iOS 18/26 Specific Features

### Apple Intelligence Summarization (iOS 18+)

Enable Apple Intelligence to automatically summarize and prioritize your indexed content:

```swift
extension SpotlightIndexer {

    func indexMessageForAISummarization(
        id: String,
        textContent: String,
        author: String,
        conversationId: String,
        createdAt: Date
    ) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet()
        attributeSet.contentType = UTType.message.identifier

        // Text content must be at least 200 characters for summarization
        attributeSet.textContent = textContent
        attributeSet.domainIdentifier = conversationId
        attributeSet.contentCreationDate = createdAt

        // Add author information
        let person = CSPerson(
            displayName: author,
            handles: [author],
            handleIdentifier: "displayName"
        )
        attributeSet.authors = [person]

        let item = CSSearchableItem(
            uniqueIdentifier: id,
            domainIdentifier: conversationId,
            attributeSet: attributeSet
        )

        // Opt into Apple Intelligence features
        item.updateListenerOptions.insert(.summarization)
        item.updateListenerOptions.insert(.priority)

        try await index.indexSearchableItems([item])
    }
}
```

### CoreSpotlight Delegate Extension

Create a CoreSpotlight Delegate app extension to receive AI-generated summaries:

```swift
import CoreSpotlight

class SpotlightDelegate: CSSearchableIndexDelegate {

    override func searchableItemsDidUpdate(_ items: [CSSearchableItem]) {
        for item in items {
            // Check if item has a priority classification
            if let isPriority = item.attributeSet.isPriority {
                // Handle priority status
                handlePriorityUpdate(
                    itemId: item.uniqueIdentifier,
                    isPriority: isPriority.boolValue
                )
            }

            // Check if item has an AI-generated summary
            if let summary = item.attributeSet.textContentSummary {
                // Store or display the summary
                handleSummaryUpdate(
                    itemId: item.uniqueIdentifier,
                    summary: summary
                )
            }
        }
    }

    private func handlePriorityUpdate(itemId: String, isPriority: Bool) {
        // Update your app's shared data store
        // This runs in an extension, so use App Groups for shared storage
    }

    private func handleSummaryUpdate(itemId: String, summary: String) {
        // Store the AI-generated summary
    }
}
```

### Enhanced Ranking Hints

```swift
extension SpotlightIndexer {

    func indexWithEnhancedRanking(_ article: Article, userEngagement: UserEngagement) async throws {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = article.title
        attributeSet.contentDescription = article.summary

        // Calculate ranking based on user engagement
        let rankingScore = calculateRankingScore(engagement: userEngagement)
        attributeSet.rankingHint = NSNumber(value: rankingScore)

        // Set last used date for recency ranking
        attributeSet.lastUsedDate = userEngagement.lastViewedDate

        let item = CSSearchableItem(
            uniqueIdentifier: article.id,
            domainIdentifier: "com.myapp.articles",
            attributeSet: attributeSet
        )

        try await index.indexSearchableItems([item])
    }

    private func calculateRankingScore(engagement: UserEngagement) -> Double {
        var score: Double = 1.0

        if engagement.isFavorite { score += 5.0 }
        if engagement.viewCount > 10 { score += 2.0 }
        if engagement.wasShared { score += 3.0 }

        return score
    }
}

struct UserEngagement {
    var isFavorite: Bool
    var viewCount: Int
    var wasShared: Bool
    var lastViewedDate: Date?
}
```

---

## 10. Common Use Cases

### Recipe App

```swift
struct Recipe: Identifiable {
    let id: String
    let name: String
    let description: String
    let ingredients: [String]
    let cookingTime: TimeInterval
    let cuisine: String
    var thumbnailData: Data?
}

extension SpotlightIndexer {

    func indexRecipe(_ recipe: Recipe) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = recipe.name
        attributeSet.contentDescription = recipe.description
        attributeSet.displayName = recipe.name

        // Include ingredients as keywords for better searchability
        attributeSet.keywords = recipe.ingredients + [recipe.cuisine, "recipe"]

        attributeSet.thumbnailData = recipe.thumbnailData
        attributeSet.duration = NSNumber(value: recipe.cookingTime)

        let item = CSSearchableItem(
            uniqueIdentifier: recipe.id,
            domainIdentifier: "com.myapp.recipes",
            attributeSet: attributeSet
        )

        try await index.indexSearchableItems([item])
    }
}
```

### Note-Taking App

```swift
struct Note: Identifiable {
    let id: String
    let title: String
    let content: String
    let folder: String
    let createdAt: Date
    let modifiedAt: Date
    var tags: [String]
}

extension SpotlightIndexer {

    func indexNote(_ note: Note) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = note.title
        attributeSet.textContent = note.content
        attributeSet.contentDescription = String(note.content.prefix(200))
        attributeSet.displayName = note.title
        attributeSet.keywords = note.tags + [note.folder]
        attributeSet.contentCreationDate = note.createdAt
        attributeSet.contentModificationDate = note.modifiedAt

        // Group by folder for batch operations
        let item = CSSearchableItem(
            uniqueIdentifier: note.id,
            domainIdentifier: "com.myapp.notes.\(note.folder)",
            attributeSet: attributeSet
        )

        try await index.indexSearchableItems([item])
    }

    func deleteFolder(_ folderName: String) async throws {
        try await index.deleteSearchableItems(
            withDomainIdentifiers: ["com.myapp.notes.\(folderName)"]
        )
    }
}
```

### E-Commerce Product Catalog

```swift
struct Product: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let price: Decimal
    let brand: String
    var thumbnailURL: URL?
}

extension SpotlightIndexer {

    func indexProduct(_ product: Product) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = product.name
        attributeSet.contentDescription = product.description
        attributeSet.displayName = product.name
        attributeSet.keywords = [product.category, product.brand, "shop", "buy"]
        attributeSet.thumbnailURL = product.thumbnailURL

        // Use alternateNames for brand searches
        attributeSet.alternateNames = [product.brand]

        let item = CSSearchableItem(
            uniqueIdentifier: product.id,
            domainIdentifier: "com.myapp.products.\(product.category)",
            attributeSet: attributeSet
        )

        try await index.indexSearchableItems([item])
    }

    func indexProductCatalog(_ products: [Product]) async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let items = products.map { product -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = product.name
            attributeSet.contentDescription = product.description
            attributeSet.keywords = [product.category, product.brand]
            attributeSet.thumbnailURL = product.thumbnailURL

            return CSSearchableItem(
                uniqueIdentifier: product.id,
                domainIdentifier: "com.myapp.products.\(product.category)",
                attributeSet: attributeSet
            )
        }

        try await index.indexSearchableItems(items)
    }
}
```

---

## 11. Best Practices

### Index Strategically

```swift
// Good: Index important, searchable content
func indexUserContent(_ content: UserContent) async throws {
    // Only index content users would realistically search for
    guard content.isComplete && !content.isDeleted else { return }
    try await performIndexing(content)
}

// Bad: Indexing everything
func indexEverything(_ allData: [Any]) async throws {
    // Don't index temporary data, drafts, or system content
}
```

### Keep Index Fresh

```swift
@Observable
final class ContentManager {

    private let indexer = SpotlightIndexer()

    // Index when content changes
    func saveArticle(_ article: Article) async throws {
        try await dataStore.save(article)
        try await indexer.indexArticle(article)
    }

    // Remove from index when content is deleted
    func deleteArticle(_ article: Article) async throws {
        try await dataStore.delete(article)
        try await indexer.deleteArticle(withId: article.id)
    }

    // Re-index on app launch to ensure consistency
    func synchronizeIndex() async {
        do {
            // Clear stale items
            try await indexer.deleteAllIndexedContent()

            // Re-index current content
            let articles = try await dataStore.fetchAllArticles()
            try await indexer.indexArticles(articles)
        } catch {
            print("Index synchronization failed: \(error)")
        }
    }
}
```

### Use Appropriate Expiration Dates

```swift
extension SpotlightIndexer {

    func indexWithAppropriateExpiration(_ item: Article, type: ContentType) async throws {
        let searchableItem = createSearchableItem(from: item)

        // Set expiration based on content type
        switch type {
        case .permanent:
            // Long-lived content (documents, saved items)
            searchableItem.expirationDate = Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date.now
            )

        case .timeSensitive:
            // Time-sensitive content (events, promotions)
            searchableItem.expirationDate = Calendar.current.date(
                byAdding: .week,
                value: 2,
                to: Date.now
            )

        case .ephemeral:
            // Short-lived content (temporary items)
            searchableItem.expirationDate = Calendar.current.date(
                byAdding: .day,
                value: 7,
                to: Date.now
            )
        }

        try await index.indexSearchableItems([searchableItem])
    }

    enum ContentType {
        case permanent
        case timeSensitive
        case ephemeral
    }
}
```

### Provide Rich Metadata

```swift
func createRichAttributeSet(for article: Article) -> CSSearchableItemAttributeSet {
    let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

    // Essential attributes
    attributeSet.title = article.title
    attributeSet.displayName = article.title
    attributeSet.contentDescription = article.summary

    // Enhance searchability
    attributeSet.keywords = extractKeywords(from: article)
    attributeSet.textContent = article.fullContent

    // Visual representation
    attributeSet.thumbnailData = article.thumbnailData

    // Temporal data
    attributeSet.contentCreationDate = article.createdAt
    attributeSet.contentModificationDate = article.modifiedAt
    attributeSet.lastUsedDate = article.lastViewedAt

    // Ranking
    attributeSet.rankingHint = NSNumber(value: article.popularityScore)

    return attributeSet
}

private func extractKeywords(from article: Article) -> [String] {
    var keywords = [String]()
    keywords.append(contentsOf: article.tags)
    keywords.append(article.category)
    keywords.append(article.author)
    return keywords
}
```

### Handle Errors Gracefully

```swift
extension SpotlightIndexer {

    func safeIndexArticle(_ article: Article) async {
        guard CSSearchableIndex.isIndexingAvailable() else {
            print("Spotlight indexing is not available on this device")
            return
        }

        do {
            try await indexArticle(article)
        } catch {
            // Log the error but don't crash the app
            print("Failed to index article \(article.id): \(error.localizedDescription)")

            // Optionally retry later
            scheduleRetry(for: article)
        }
    }

    private func scheduleRetry(for article: Article) {
        // Implement retry logic if needed
    }
}
```

### Test Your Integration

```swift
import XCTest
import CoreSpotlight

final class SpotlightIndexerTests: XCTestCase {

    var sut: SpotlightIndexer!

    override func setUp() {
        super.setUp()
        sut = SpotlightIndexer()
    }

    override func tearDown() async throws {
        // Clean up test data
        try await sut.deleteAllIndexedContent()
        sut = nil
        try await super.tearDown()
    }

    func testIndexArticle() async throws {
        // Given
        let article = Article(
            id: "test-123",
            title: "Test Article",
            summary: "Test summary",
            author: "Test Author",
            createdAt: Date.now
        )

        // When
        try await sut.indexArticle(article)

        // Then
        let results = try await searchForItem(withId: "test-123")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.attributeSet.title, "Test Article")
    }

    func testDeleteArticle() async throws {
        // Given
        let article = Article(
            id: "test-456",
            title: "To Be Deleted",
            summary: "Summary",
            author: "Author",
            createdAt: Date.now
        )
        try await sut.indexArticle(article)

        // When
        try await sut.deleteArticle(withId: "test-456")

        // Then
        let results = try await searchForItem(withId: "test-456")
        XCTAssertTrue(results.isEmpty)
    }

    private func searchForItem(withId id: String) async throws -> [CSSearchableItem] {
        let queryString = "title == '*'c"
        let context = CSSearchQueryContext()
        context.fetchAttributes = ["title"]

        let query = CSSearchQuery(queryString: queryString, queryContext: context)

        var results = [CSSearchableItem]()
        for try await result in query.results {
            if result.item.uniqueIdentifier == id {
                results.append(result.item)
            }
        }
        return results
    }
}
```

---

## Summary

CoreSpotlight is a powerful framework for making your app's content discoverable through Spotlight search. Key takeaways:

1. **Use `CSSearchableItem` and `CSSearchableItemAttributeSet`** to describe your content
2. **Group items with domain identifiers** for easier batch management
3. **Keep your index fresh** by updating when content changes
4. **Handle search result taps** using `onContinueUserActivity` in SwiftUI
5. **Integrate with App Intents** using `associateAppEntity` for Siri and Shortcuts
6. **Enable Apple Intelligence features** (iOS 18+) for automatic summarization
7. **Set appropriate expiration dates** to prevent stale content
8. **Provide rich metadata** for better search results and ranking

By following these patterns and best practices, you can create a seamless search experience that helps users quickly find and access your app's content from anywhere on their device.
