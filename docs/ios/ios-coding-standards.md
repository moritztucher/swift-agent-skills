# iOS Coding Standards — Examples

> The rules live in `ios-guide.md` (loaded via `@import`). This file carries only the expanded examples and details the guide doesn't repeat.

## Code Organization Example

```swift
// MARK: - Properties
private let userManager: UserManager
@State private var isLoading = false

// MARK: - Body
var body: some View {
    VStack {
        // View content
    }
}

// MARK: - Methods
private func fetchData() async {
    // Implementation
}
```

## Handoff Comments

For complex logic that isn't self-explanatory, add inline comments explaining:
- Why the approach was taken (not just what it does)
- Any non-obvious dependencies or side effects
- Edge cases being handled

```swift
// We use a serial queue here because the API rate-limits concurrent requests
// and returns 429 errors if we exceed 5 requests/second
private let requestQueue = DispatchQueue(label: "api.serial")
```

## Error Handling

Create custom Error enums for different error domains:

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingFailed: return "Failed to decode response"
        }
    }
}
```

## Performance

- Use lazy loading for expensive operations
- Profile with Instruments before optimizing — avoid premature optimization

## Security Details (beyond the guide's rules)

- Never store credit card numbers, SSNs, or highly sensitive PII without encryption
- Consider certificate pinning for critical API calls
- Request permissions with clear, user-facing explanations

## Testing Example

```swift
final class UserViewModelTests: XCTestCase {
    var sut: UserViewModel!
    var mockNetworkService: MockNetworkService!

    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        sut = UserViewModel(networkService: mockNetworkService)
    }

    func testFetchUser() async throws {
        // Test implementation
    }
}
```
