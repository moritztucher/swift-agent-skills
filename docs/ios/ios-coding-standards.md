# iOS Coding Standards

> Full coding standards reference. Core rules are in CLAUDE.md.

## General Rules

- Use `camelCase` for variables and functions
- Use `PascalCase` for types (classes, structs, enums, protocols)
- Prefer `let` over `var` whenever possible
- Use trailing closures when appropriate
- Use explicit `self` only when required by the compiler
- Maximum line length: **130 characters**
- Organize code sections with `// MARK: -` comments
- Each View file should only contain one View struct
- Subviews and helper components should be extracted to:
  - `Features/[Feature]/Views/ViewComponents/` for feature-specific components
  - `ViewComponents/` (root level) for components reusable across multiple features
- Reuse ViewComponents - make them customizable rather than creating new ones
- Always ask for clarifications, don't make assumptions
- Keep code simple and minimal
- Add DocC comments when suitable

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

## Best Practices

### Code Organization
- **No business logic in Views** - Views should only handle UI and user interactions
- **ViewModels contain business logic** - All data manipulation and business rules live here
- **Services handle external operations** - Networking, database, authentication, etc.
- Keep files focused and single-purpose

### Async/Await
- **Always use async/await** - Never use completion handlers
- Use `Task` for creating new async contexts
- Handle errors with do-catch blocks
- Use `@MainActor` for UI updates when necessary

### Security
- **Never hardcode API keys or secrets** - Use environment variables or configuration files
- **Always use HTTPS** for network requests
- Use Keychain for sensitive data (tokens, passwords, credentials)
- Use UserDefaults only for non-sensitive user preferences
- Implement certificate pinning for critical API calls

### Performance
- Use lazy loading for expensive operations
- Profile with Instruments before optimizing
- Avoid premature optimization
- Use SwiftUI's built-in performance tools

## Security & Privacy

### Data Storage
- **Keychain:** API tokens, passwords, authentication credentials
- **UserDefaults:** User preferences, app settings (non-sensitive only)
- **Never store:** Credit card numbers, SSNs, or highly sensitive PII without encryption

### Network Security
- All network requests must use HTTPS
- Implement proper certificate validation
- Never disable SSL/TLS verification
- Use URLSession with proper security configurations

### Privacy
- Include Privacy Manifest (PrivacyInfo.xcprivacy) for App Store compliance
- Request permissions with clear explanations
- Follow Apple's privacy guidelines
- Be transparent about data collection

## Testing

### Test Organization
- Tests location: `[ProjectName]Tests`
- Mirror the main project structure in tests
- Name test files: `[ClassName]Tests.swift`

### Testing Strategy
- **Unit test ViewModels** - Business logic should be fully tested
- **Mock NetworkService** - Create mock implementations for testing
- Test edge cases and error conditions
- Use XCTest framework

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

## Definition of Done

Before marking any task as complete, verify ALL of the following:

### Code Quality
- [ ] Code compiles without errors or warnings
- [ ] No hardcoded API keys, secrets, or credentials
- [ ] Follows naming conventions
- [ ] Code is simple and minimal (no over-engineering)

### Logic & Performance
- [ ] No unnecessary re-renders or state updates
- [ ] Async operations use `.task` modifier (not `onAppear`)
- [ ] Heavy computations are offloaded appropriately

### Views & UI
- [ ] Views follow Apple Human Interface Guidelines (HIG)
- [ ] Proper use of system components
- [ ] Respects Dynamic Type and accessibility settings
- [ ] Works correctly in both light and dark mode

### Architecture
- [ ] No business logic in Views
- [ ] ViewModels handle all data manipulation
- [ ] Services handle external operations

### Testing
- [ ] On-device testing completed
- [ ] Edge cases considered and handled
- [ ] Error states display user-friendly messages

### Security
- [ ] Sensitive data stored in Keychain
- [ ] All network requests use HTTPS
- [ ] Input validation where applicable
