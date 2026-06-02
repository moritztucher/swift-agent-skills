# PhotosUI Guide - iOS/Swift

Comprehensive guide for photo and video selection using PhotosUI framework in iOS/Swift with SwiftUI's PhotosPicker API.

---

## Overview

The **PhotosUI** framework provides APIs for:

- **PhotosPicker** - SwiftUI view for selecting photos/videos from the library
- **PhotosPickerItem** - Represents a selected item with async data loading
- **PHPickerViewController** - UIKit picker (wrapped for SwiftUI if needed)
- **PHLivePhotoView** - Display Live Photos in your app
- **PHPickerFilter** - Filter items by type (images, videos, screenshots, etc.)

### Key Benefits

- **Privacy-Preserving**: No photo library permission required for basic picker usage
- **Modern API**: Built for SwiftUI with async/await support
- **Flexible Filtering**: Filter by media type, screenshots, Live Photos, and more
- **Limited Library Access**: Support for iOS 14+ limited library selection

---

## Import

```swift
import PhotosUI
import SwiftUI

// For limited library access features:
import Photos
```

---

## Info.plist Configuration

### For Basic PhotosPicker (No Permission Needed)

The SwiftUI `PhotosPicker` does not require any Info.plist entries for basic usage. Users explicitly grant access to only the items they select.

### For Full/Limited Photo Library Access

If you need to access the photo library directly (beyond picker selection):

```xml
<!-- Required for read access -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to display them in the app.</string>

<!-- Optional: For write access (saving photos) -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save photos to your library.</string>

<!-- Optional: Prevent automatic limited access alert -->
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

---

## PhotosPicker (SwiftUI)

The primary way to let users select photos and videos in SwiftUI apps.

### Single Selection

```swift
import PhotosUI
import SwiftUI

struct SinglePhotoPickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?

    var body: some View {
        VStack {
            PhotosPicker(
                "Select a Photo",
                selection: $selectedItem,
                matching: .images
            )

            if let selectedImage {
                selectedImage
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
            }
        }
        .task(id: selectedItem) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let selectedItem else {
            selectedImage = nil
            return
        }

        do {
            selectedImage = try await selectedItem.loadTransferable(type: Image.self)
        } catch {
            print("Failed to load image: \(error)")
            selectedImage = nil
        }
    }
}
```

### Multiple Selection

```swift
struct MultiPhotoPickerView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [Image] = []

    var body: some View {
        VStack {
            PhotosPicker(
                "Select Photos",
                selection: $selectedItems,
                maxSelectionCount: 5,
                selectionBehavior: .ordered,
                matching: .images
            )

            ScrollView(.horizontal) {
                HStack {
                    ForEach(0..<selectedImages.count, id: \.self) { index in
                        selectedImages[index]
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .task(id: selectedItems) {
            await loadImages()
        }
    }

    private func loadImages() async {
        selectedImages = []

        for item in selectedItems {
            if let image = try? await item.loadTransferable(type: Image.self) {
                selectedImages.append(image)
            }
        }
    }
}
```

### Using View Modifier (Alternative Presentation)

```swift
struct PhotoPickerModifierView: View {
    @State private var isPickerPresented = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: Image?

    var body: some View {
        VStack {
            Button("Select Photo") {
                isPickerPresented = true
            }

            if let image {
                image
                    .resizable()
                    .scaledToFit()
            }
        }
        .photosPicker(
            isPresented: $isPickerPresented,
            selection: $selectedItem,
            matching: .images
        )
        .task(id: selectedItem) {
            image = try? await selectedItem?.loadTransferable(type: Image.self)
        }
    }
}
```

---

## PhotosPickerItem Data Loading

### Loading as SwiftUI Image

```swift
// Direct Image loading
let image = try await item.loadTransferable(type: Image.self)
```

### Loading as Data (for UIImage, Core Image, etc.)

```swift
// Load as Data for more control
if let data = try await item.loadTransferable(type: Data.self) {
    let uiImage = UIImage(data: data)
    // Use with Core Image, save to files, etc.
}
```

### Custom Transferable Type

Create a custom type for more control over image loading:

```swift
struct PickedImage: Transferable {
    let uiImage: UIImage
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return PickedImage(uiImage: uiImage, data: data)
        }
    }
}

enum TransferError: Error {
    case importFailed
}

// Usage
let pickedImage = try await item.loadTransferable(type: PickedImage.self)
```

### Loading with Progress

For large files, consider showing progress:

```swift
@Observable
class PhotoLoaderViewModel {
    var isLoading = false
    var loadedImage: Image?
    var errorMessage: String?

    func loadPhoto(from item: PhotosPickerItem) async {
        isLoading = true
        errorMessage = nil

        do {
            loadedImage = try await item.loadTransferable(type: Image.self)
        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
```

---

## PHPickerFilter Options

Filter what types of media users can select.

### Basic Filters

| Filter | Description | iOS Version |
|--------|-------------|-------------|
| `.images` | All image types | iOS 14+ |
| `.videos` | All video types | iOS 14+ |
| `.livePhotos` | Live Photos only | iOS 14+ |
| `.screenshots` | Screenshots only | iOS 15+ (backported) |
| `.screenRecordings` | Screen recordings | iOS 15+ (backported) |
| `.slomoVideos` | Slow-motion videos | iOS 15+ (backported) |
| `.timelapseVideos` | Time-lapse videos | iOS 15+ (backported) |
| `.cinematicVideos` | Cinematic mode videos | iOS 16+ |
| `.depthEffectPhotos` | Portrait mode photos | iOS 16+ |
| `.bursts` | Burst photo sequences | iOS 16+ |
| `.panoramas` | Panoramic photos | iOS 15+ (backported) |

### Filter Examples

```swift
// Single filter
PhotosPicker("Select Image", selection: $item, matching: .images)

// Videos only
PhotosPicker("Select Video", selection: $item, matching: .videos)

// Live Photos only
PhotosPicker("Select Live Photo", selection: $item, matching: .livePhotos)

// Screenshots only (iOS 15+)
PhotosPicker("Select Screenshot", selection: $item, matching: .screenshots)
```

### Compound Filters

Combine multiple filters using `.any(of:)`, `.all(of:)`, and `.not()`:

```swift
// Any of multiple types
let imageOrVideo = PHPickerFilter.any(of: [.images, .videos])
PhotosPicker("Select Media", selection: $item, matching: imageOrVideo)

// Images but not screenshots
let imagesNoScreenshots = PHPickerFilter.all(of: [
    .images,
    .not(.screenshots)
])

// Only certain image types
let specificImages = PHPickerFilter.any(of: [
    .screenshots,
    .panoramas,
    .depthEffectPhotos
])

// Exclude certain types
let noVideos = PHPickerFilter.not(.videos)
```

---

## PhotosPicker Customization

### Picker Styles (iOS 17+)

```swift
PhotosPicker("Select", selection: $item)
    .photosPickerStyle(.inline) // Inline presentation

PhotosPicker("Select", selection: $item)
    .photosPickerStyle(.compact) // Compact presentation

PhotosPicker("Select", selection: $item)
    .photosPickerStyle(.presentation) // Full presentation (default)
```

### Accessory Visibility (iOS 17+)

```swift
PhotosPicker("Select", selection: $item)
    .photosPickerAccessoryVisibility(.hidden, edges: .bottom)
```

### Disabled Capabilities (iOS 17+)

```swift
PhotosPicker("Select", selection: $item)
    .photosPickerDisabledCapabilities([.search, .collectionNavigation])
```

### Custom Label

```swift
PhotosPicker(selection: $selectedItem, matching: .images) {
    Label("Choose Photo", systemImage: "photo.on.rectangle")
        .font(.headline)
        .foregroundStyle(.blue)
}

// With image as label
PhotosPicker(selection: $selectedItem, matching: .images) {
    if let image = selectedImage {
        image
            .resizable()
            .scaledToFill()
            .frame(width: 100, height: 100)
            .clipShape(Circle())
    } else {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 100, height: 100)
            .foregroundStyle(.gray)
    }
}
```

---

## Using @Observable ViewModel Pattern

Recommended architecture for photo picking with SwiftUI:

```swift
import PhotosUI
import SwiftUI

@Observable
class PhotoPickerViewModel {
    var selectedItem: PhotosPickerItem?
    var selectedItems: [PhotosPickerItem] = []

    var loadedImage: Image?
    var loadedImages: [Image] = []
    var loadedData: Data?

    var isLoading = false
    var errorMessage: String?

    // MARK: - Single Photo Loading

    func loadSinglePhoto() async {
        guard let selectedItem else {
            loadedImage = nil
            loadedData = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Load as Image for display
            loadedImage = try await selectedItem.loadTransferable(type: Image.self)

            // Also load as Data if needed for uploading/saving
            loadedData = try await selectedItem.loadTransferable(type: Data.self)
        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
            loadedImage = nil
            loadedData = nil
        }

        isLoading = false
    }

    // MARK: - Multiple Photos Loading

    func loadMultiplePhotos() async {
        guard !selectedItems.isEmpty else {
            loadedImages = []
            return
        }

        isLoading = true
        errorMessage = nil
        loadedImages = []

        for item in selectedItems {
            do {
                if let image = try await item.loadTransferable(type: Image.self) {
                    loadedImages.append(image)
                }
            } catch {
                print("Failed to load item: \(error)")
            }
        }

        isLoading = false
    }

    // MARK: - Reset

    func reset() {
        selectedItem = nil
        selectedItems = []
        loadedImage = nil
        loadedImages = []
        loadedData = nil
        errorMessage = nil
    }
}

// MARK: - View Implementation

struct PhotoPickerScreen: View {
    @State private var viewModel = PhotoPickerViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Single photo picker
                PhotosPicker(
                    selection: $viewModel.selectedItem,
                    matching: .images
                ) {
                    Label("Select Photo", systemImage: "photo")
                }

                if viewModel.isLoading {
                    ProgressView()
                } else if let image = viewModel.loadedImage {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
            .navigationTitle("Photo Picker")
            .task(id: viewModel.selectedItem) {
                await viewModel.loadSinglePhoto()
            }
        }
    }
}
```

---

## Live Photo Support

### Loading Live Photos

```swift
import PhotosUI
import Photos

struct LivePhotoPickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        VStack {
            PhotosPicker(
                "Select Live Photo",
                selection: $selectedItem,
                matching: .livePhotos
            )

            if let livePhoto {
                LivePhotoView(livePhoto: livePhoto)
                    .frame(height: 300)
            }
        }
        .task(id: selectedItem) {
            await loadLivePhoto()
        }
    }

    private func loadLivePhoto() async {
        guard let selectedItem else {
            livePhoto = nil
            return
        }

        livePhoto = try? await selectedItem.loadTransferable(type: PHLivePhoto.self)
    }
}
```

### PHLivePhotoView Wrapper for SwiftUI

```swift
import PhotosUI
import SwiftUI

struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    var playbackStyle: PHLivePhotoViewPlaybackStyle = .hint

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto

        // Optionally start playback
        if playbackStyle != .hint {
            uiView.startPlayback(with: playbackStyle)
        }
    }
}

// Usage with playback control
struct LivePhotoDisplayView: View {
    let livePhoto: PHLivePhoto
    @State private var isPlaying = false

    var body: some View {
        VStack {
            LivePhotoView(
                livePhoto: livePhoto,
                playbackStyle: isPlaying ? .full : .hint
            )
            .frame(height: 300)

            Button(isPlaying ? "Stop" : "Play") {
                isPlaying.toggle()
            }
        }
    }
}
```

---

## Limited Photo Library Access

iOS 14+ allows users to grant access to only specific photos. Handle this gracefully.

### Check Authorization Status

```swift
import Photos

@Observable
class PhotoLibraryManager {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    func checkAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
        }
    }

    var accessDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted by parental controls"
        case .denied:
            return "Access denied"
        case .authorized:
            return "Full access granted"
        case .limited:
            return "Limited access - only selected photos"
        @unknown default:
            return "Unknown status"
        }
    }

    var hasAccess: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }
}
```

### Request Limited Library Selection (iOS 15+)

```swift
import PhotosUI

class LimitedLibraryManager {
    func presentLimitedLibraryPicker(from viewController: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    // With completion handler for selected assets
    @available(iOS 15, *)
    func presentLimitedLibraryPicker(
        from viewController: UIViewController,
        completion: @escaping ([String]) -> Void
    ) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController) { identifiers in
            completion(identifiers)
        }
    }
}
```

### SwiftUI Wrapper for Limited Library Picker

```swift
import PhotosUI
import SwiftUI

struct LimitedLibraryPickerButton: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onSelection: (([String]) -> Void)?

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            if #available(iOS 15, *) {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: uiViewController) { identifiers in
                    onSelection?(identifiers)
                    isPresented = false
                }
            } else {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: uiViewController)
                isPresented = false
            }
        }
    }
}

// Usage in SwiftUI
struct LimitedAccessView: View {
    @State private var showLimitedPicker = false

    var body: some View {
        VStack {
            Button("Manage Selected Photos") {
                showLimitedPicker = true
            }
        }
        .background(
            LimitedLibraryPickerButton(isPresented: $showLimitedPicker) { identifiers in
                print("Newly selected: \(identifiers)")
            }
        )
    }
}
```

### Observe Library Changes

```swift
import Photos

@Observable
class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    var lastChangeDetails: String = ""

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            lastChangeDetails = "Library changed at \(Date())"
            // Handle specific asset changes if needed
        }
    }
}
```

---

## PHPickerViewController (UIKit)

For UIKit apps or when you need UIKit integration with SwiftUI:

### UIKit Implementation

```swift
import PhotosUI

class PhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    var onImagePicked: ((UIImage?) -> Void)?

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            onImagePicked?(nil)
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            Task { @MainActor in
                self?.onImagePicked?(object as? UIImage)
            }
        }
    }
}

// Presenting the picker
func presentPicker(from viewController: UIViewController, delegate: PhotoPickerDelegate) {
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1

    let picker = PHPickerViewController(configuration: config)
    picker.delegate = delegate
    viewController.present(picker, animated: true)
}
```

### SwiftUI Wrapper for PHPickerViewController

```swift
import PhotosUI
import SwiftUI

struct PHPickerViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss

    var filter: PHPickerFilter = .images
    var selectionLimit: Int = 1

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = filter
        config.selectionLimit = selectionLimit

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewControllerWrapper

        init(_ parent: PHPickerViewControllerWrapper) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            Task {
                var images: [UIImage] = []

                for result in results {
                    if let image = await loadImage(from: result) {
                        images.append(image)
                    }
                }

                await MainActor.run {
                    parent.selectedImages = images
                }
            }
        }

        private func loadImage(from result: PHPickerResult) async -> UIImage? {
            await withCheckedContinuation { continuation in
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
    }
}

// Usage
struct PHPickerExampleView: View {
    @State private var showPicker = false
    @State private var images: [UIImage] = []

    var body: some View {
        VStack {
            Button("Select Photos") {
                showPicker = true
            }

            ForEach(images.indices, id: \.self) { index in
                Image(uiImage: images[index])
                    .resizable()
                    .scaledToFit()
            }
        }
        .sheet(isPresented: $showPicker) {
            PHPickerViewControllerWrapper(
                selectedImages: $images,
                filter: .images,
                selectionLimit: 3
            )
        }
    }
}
```

---

## Best Practices

### Memory Management

```swift
@Observable
class EfficientPhotoLoader {
    var thumbnailImages: [String: Image] = [:]
    var fullImages: [String: Image] = [:]

    // Load thumbnails for gallery display
    func loadThumbnail(for item: PhotosPickerItem, identifier: String) async {
        // Check cache first
        if thumbnailImages[identifier] != nil { return }

        // Load as data for resizing
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        // Create thumbnail
        let thumbnailSize = CGSize(width: 150, height: 150)
        let thumbnail = uiImage.preparingThumbnail(of: thumbnailSize) ?? uiImage

        await MainActor.run {
            thumbnailImages[identifier] = Image(uiImage: thumbnail)
        }
    }

    // Load full image only when needed
    func loadFullImage(for item: PhotosPickerItem, identifier: String) async {
        if fullImages[identifier] != nil { return }

        guard let image = try? await item.loadTransferable(type: Image.self) else { return }

        await MainActor.run {
            fullImages[identifier] = image
        }
    }

    // Clear cache when needed
    func clearCache() {
        thumbnailImages.removeAll()
        fullImages.removeAll()
    }
}
```

### Handle Large Files

```swift
@Observable
class LargePhotoHandler {
    var progress: Double = 0
    var isProcessing = false

    func processLargePhoto(from item: PhotosPickerItem) async throws -> Data {
        isProcessing = true
        defer { isProcessing = false }

        // Load data
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoError.loadFailed
        }

        // Check size and compress if needed
        let maxSize = 10 * 1024 * 1024 // 10 MB

        if data.count > maxSize {
            return try await compressImage(data: data, targetSize: maxSize)
        }

        return data
    }

    private func compressImage(data: Data, targetSize: Int) async throws -> Data {
        guard let image = UIImage(data: data) else {
            throw PhotoError.invalidImage
        }

        var compressionQuality: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compressionQuality)

        while let data = compressedData, data.count > targetSize, compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }

        guard let finalData = compressedData else {
            throw PhotoError.compressionFailed
        }

        return finalData
    }
}

enum PhotoError: Error {
    case loadFailed
    case invalidImage
    case compressionFailed
}
```

### Cancellation Support

```swift
@Observable
class CancellablePhotoLoader {
    var currentTask: Task<Void, Never>?
    var loadedImages: [Image] = []
    var isCancelled = false

    func loadPhotos(from items: [PhotosPickerItem]) {
        // Cancel previous task
        currentTask?.cancel()
        isCancelled = false

        currentTask = Task {
            var images: [Image] = []

            for item in items {
                // Check for cancellation
                if Task.isCancelled {
                    isCancelled = true
                    return
                }

                if let image = try? await item.loadTransferable(type: Image.self) {
                    images.append(image)

                    // Update UI incrementally
                    await MainActor.run {
                        loadedImages = images
                    }
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
    }
}
```

---

## Common Pitfalls

### 1. Not Using Task Properly

```swift
// BAD: Loading in onChange without Task
.onChange(of: selectedItem) { item in
    // This won't compile - async call in sync context
    let image = await item.loadTransferable(type: Image.self)
}

// GOOD: Use Task or .task modifier
.onChange(of: selectedItem) { _, newItem in
    Task {
        loadedImage = try? await newItem?.loadTransferable(type: Image.self)
    }
}

// BETTER: Use .task(id:) for automatic cancellation
.task(id: selectedItem) {
    loadedImage = try? await selectedItem?.loadTransferable(type: Image.self)
}
```

### 2. Memory Issues with Large Selections

```swift
// BAD: Loading all images at once
for item in selectedItems {
    let image = try? await item.loadTransferable(type: Image.self)
    images.append(image) // Could exhaust memory with many large images
}

// GOOD: Load thumbnails and full images on demand
func loadThumbnailsFirst() async {
    for item in selectedItems {
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            let thumbnail = uiImage.preparingThumbnail(of: CGSize(width: 100, height: 100))
            // Use thumbnail for display
        }
    }
}
```

### 3. Not Handling Nil Results

```swift
// BAD: Force unwrapping
let image = try! await item.loadTransferable(type: Image.self)!

// GOOD: Handle nil gracefully
if let image = try? await item.loadTransferable(type: Image.self) {
    loadedImage = image
} else {
    showErrorMessage = true
}
```

### 4. Blocking UI During Load

```swift
// BAD: No loading indicator
.task(id: selectedItem) {
    loadedImage = try? await selectedItem?.loadTransferable(type: Image.self)
}

// GOOD: Show loading state
.task(id: selectedItem) {
    isLoading = true
    loadedImage = try? await selectedItem?.loadTransferable(type: Image.self)
    isLoading = false
}

// In view:
if isLoading {
    ProgressView()
} else if let loadedImage {
    loadedImage
}
```

### 5. Filter Issues in Collections Tab

Some developers report that PHPickerFilter may not work correctly in the Collections tab of the picker. Test your filter configurations thoroughly.

---

## iOS Version Compatibility

| Feature | Minimum iOS |
|---------|-------------|
| PhotosPicker (SwiftUI) | iOS 16.0 |
| PHPickerViewController | iOS 14.0 |
| Limited Library Access | iOS 14.0 |
| `.screenshots` filter | iOS 15.0 (backported) |
| `.cinematicVideos` filter | iOS 16.0 |
| `.depthEffectPhotos` filter | iOS 16.0 |
| `.bursts` filter | iOS 16.0 |
| `.photosPickerStyle()` | iOS 17.0 |
| `.photosPickerAccessoryVisibility()` | iOS 17.0 |
| `.photosPickerDisabledCapabilities()` | iOS 17.0 |
| `presentLimitedLibraryPicker` with completion | iOS 15.0 |

---

## Complete Example: Profile Photo Picker

```swift
import PhotosUI
import SwiftUI

@Observable
class ProfileViewModel {
    var selectedItem: PhotosPickerItem?
    var profileImage: Image?
    var profileImageData: Data?
    var isLoading = false
    var error: String?

    func loadProfilePhoto() async {
        guard let selectedItem else {
            profileImage = nil
            profileImageData = nil
            return
        }

        isLoading = true
        error = nil

        do {
            // Load as data for uploading
            guard let data = try await selectedItem.loadTransferable(type: Data.self) else {
                throw PhotoError.loadFailed
            }

            // Compress if needed
            let compressedData = compressForUpload(data: data)

            // Create image for display
            guard let uiImage = UIImage(data: compressedData) else {
                throw PhotoError.invalidImage
            }

            await MainActor.run {
                profileImageData = compressedData
                profileImage = Image(uiImage: uiImage)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func compressForUpload(data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        // Target size: 500KB
        let targetSize = 500 * 1024

        if data.count <= targetSize {
            return data
        }

        var quality: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: quality) ?? data

        while compressedData.count > targetSize && quality > 0.1 {
            quality -= 0.1
            compressedData = image.jpegData(compressionQuality: quality) ?? compressedData
        }

        return compressedData
    }
}

struct ProfilePhotoPickerView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Profile image display
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(width: 120, height: 120)
                } else if let image = viewModel.profileImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.gray)
                }
            }

            // Picker button
            PhotosPicker(
                selection: $viewModel.selectedItem,
                matching: .images
            ) {
                Text("Change Photo")
                    .foregroundStyle(.blue)
            }
            .disabled(viewModel.isLoading)

            // Error display
            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .task(id: viewModel.selectedItem) {
            await viewModel.loadProfilePhoto()
        }
    }
}
```

---

## Related Documentation

- [Apple PhotosUI Documentation](https://developer.apple.com/documentation/photosui)
- [Apple Photos Framework](https://developer.apple.com/documentation/photos)
- [WWDC22: What's new in the Photos picker](https://developer.apple.com/videos/play/wwdc2022/10023/)
- [WWDC20: Meet the new Photos picker](https://developer.apple.com/videos/play/wwdc2020/10652/)

---

*Document created: 2026-02-03*
*iOS Version: iOS 16+ (PhotosPicker), iOS 14+ (PHPickerViewController)*
*Swift Version: Swift 5.9+*
