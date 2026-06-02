# Visual Intelligence Guide for iOS 26+

A comprehensive guide for implementing camera-based visual lookup, object recognition, and Apple Intelligence visual features in iOS applications.

---

## Table of Contents

1. [Overview](#overview)
2. [Framework Architecture](#framework-architecture)
3. [Vision Framework](#vision-framework)
   - [VNImageRequestHandler](#vnimagerequesthandler)
   - [Text Recognition](#text-recognition)
   - [Barcode Detection](#barcode-detection)
   - [Object Classification](#object-classification)
   - [Face Detection](#face-detection)
   - [Body Pose Detection](#body-pose-detection)
   - [Core ML Integration](#core-ml-integration)
4. [VisionKit Framework](#visionkit-framework)
   - [ImageAnalyzer and Visual Look Up](#imageanalyzer-and-visual-look-up)
   - [Live Text Interactions](#live-text-interactions)
   - [Subject Lifting](#subject-lifting)
   - [DataScannerViewController](#datascannerviewcontroller)
5. [Visual Intelligence Framework (iOS 26+)](#visual-intelligence-framework-ios-26)
   - [App Intents Integration](#app-intents-integration)
   - [On-Screen Visual Search](#on-screen-visual-search)
6. [SwiftUI Integration](#swiftui-integration)
7. [Best Practices](#best-practices)
8. [Resources](#resources)

---

## Overview

Apple provides multiple frameworks for visual intelligence and computer vision:

| Framework | Purpose | Minimum iOS |
|-----------|---------|-------------|
| **Vision** | Low-level computer vision (text, faces, barcodes, objects) | iOS 11+ |
| **VisionKit** | High-level UI for Live Text, Visual Look Up | iOS 16+ |
| **Visual Intelligence** | App Intents integration for system-wide visual search | iOS 26+ |
| **Core ML** | Custom machine learning models | iOS 11+ |

### Key Capabilities

- **Text Recognition**: Extract text from images in 18+ languages
- **Visual Look Up**: Identify plants, animals, landmarks, art, food, and symbols
- **Object Detection**: Detect and classify objects using Core ML models
- **Barcode Scanning**: Read QR codes, barcodes, and data matrices
- **Face Detection**: Locate faces and facial landmarks
- **Pose Estimation**: Track body and hand poses in 2D and 3D
- **Subject Lifting**: Extract subjects from backgrounds
- **On-Screen Analysis**: Search and analyze content visible on screen (iOS 26+)

---

## Framework Architecture

```
+-------------------+
|  Visual Intelligence  |  <- iOS 26+ App Intents integration
+-------------------+
         |
+-------------------+
|     VisionKit     |  <- High-level UI components
+-------------------+
         |
+-------------------+
|      Vision       |  <- Core computer vision
+-------------------+
         |
+-------------------+
|      Core ML      |  <- Custom ML models
+-------------------+
```

### Imports

```swift
import Vision             // Core computer vision
import VisionKit          // High-level UI (ImageAnalyzer, DataScanner)
import CoreML             // Custom ML models
import AppIntents         // Integration plumbing for Visual Intelligence (iOS 26+)
import VisualIntelligence // SemanticContentDescriptor + result types (iOS 26+)
```

---

## Vision Framework

The Vision framework provides low-level computer vision capabilities through a request-based API.

### VNImageRequestHandler

All Vision requests are performed through `VNImageRequestHandler`:

```swift
import Vision

// From CGImage
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

// From CVPixelBuffer (camera/video)
let handler = VNImageRequestHandler(
    cvPixelBuffer: pixelBuffer,
    orientation: .up,
    options: [:]
)

// From CMSampleBuffer
let handler = VNImageRequestHandler(
    cmSampleBuffer: sampleBuffer,
    options: [:]
)

// Perform requests
do {
    try handler.perform([request1, request2])
} catch {
    print("Vision request failed: \(error)")
}
```

### Text Recognition

Recognize and extract text from images:

```swift
import Vision

func recognizeText(in image: CGImage) async throws -> String {
    let request = VNRecognizeTextRequest()

    // Configuration
    request.recognitionLevel = .accurate  // or .fast
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US", "de-DE", "zh-Hans"]

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    guard let observations = request.results else {
        return ""
    }

    let recognizedText = observations.compactMap { observation in
        observation.topCandidates(1).first?.string
    }.joined(separator: "\n")

    return recognizedText
}
```

#### Real-Time Text Recognition

For camera feeds, optimize for speed:

```swift
func processFrame(_ pixelBuffer: CVPixelBuffer) {
    let request = VNRecognizeTextRequest { request, error in
        guard let results = request.results as? [VNRecognizedTextObservation] else { return }

        for observation in results {
            if let text = observation.topCandidates(1).first?.string {
                print("Detected: \(text)")
            }
        }
    }

    // Optimize for real-time
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = false
    request.regionOfInterest = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

    DispatchQueue.global(qos: .userInteractive).async {
        try? handler.perform([request])
    }
}
```

### Barcode Detection

Detect QR codes, barcodes, and other machine-readable codes:

```swift
import Vision

func detectBarcodes(in image: CGImage) async throws -> [VNBarcodeObservation] {
    let request = VNDetectBarcodesRequest()

    // Specify symbologies (empty = all)
    request.symbologies = [.qr, .code128, .ean13, .dataMatrix]

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results ?? []
}

// Process results
func handleBarcodeResults(_ observations: [VNBarcodeObservation]) {
    for barcode in observations {
        print("Symbology: \(barcode.symbology.rawValue)")
        print("Payload: \(barcode.payloadStringValue ?? "N/A")")
        print("Bounding Box: \(barcode.boundingBox)")

        // Check if GS1 data carrier
        if barcode.isGS1DataCarrier {
            print("Contains GS1 data")
        }
    }
}
```

#### Supported Symbologies

```swift
// Common symbologies
BarcodeSymbology.qr           // QR Code
BarcodeSymbology.dataMatrix   // Data Matrix
BarcodeSymbology.aztec        // Aztec
BarcodeSymbology.code128      // Code 128
BarcodeSymbology.code39       // Code 39
BarcodeSymbology.ean13        // EAN-13
BarcodeSymbology.ean8         // EAN-8
BarcodeSymbology.upce         // UPC-E
BarcodeSymbology.pdf417       // PDF417
BarcodeSymbology.microQR      // Micro QR
```

### Object Classification

Classify the overall content of an image:

```swift
import Vision

func classifyImage(_ image: CGImage) async throws -> [(String, Float)] {
    let request = VNClassifyImageRequest()

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    guard let observations = request.results else {
        return []
    }

    // Get top 5 classifications
    let topClassifications = observations
        .sorted { $0.confidence > $1.confidence }
        .prefix(5)
        .map { ($0.identifier, $0.confidence) }

    return Array(topClassifications)
}
```

### Face Detection

Detect faces and facial landmarks:

```swift
import Vision

// Detect face rectangles
func detectFaces(in image: CGImage) async throws -> [VNFaceObservation] {
    let request = VNDetectFaceRectanglesRequest()

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results ?? []
}

// Detect facial landmarks (eyes, nose, mouth, etc.)
func detectFaceLandmarks(in image: CGImage) async throws -> [VNFaceObservation] {
    let request = VNDetectFaceLandmarksRequest()

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results ?? []
}

// Process landmarks
func processLandmarks(_ face: VNFaceObservation) {
    guard let landmarks = face.landmarks else { return }

    // Access specific features
    if let leftEye = landmarks.leftEye {
        print("Left eye points: \(leftEye.normalizedPoints)")
    }

    if let nose = landmarks.nose {
        print("Nose points: \(nose.normalizedPoints)")
    }

    // Available landmarks:
    // - faceContour, leftEye, rightEye
    // - nose, noseCrest, medianLine
    // - outerLips, innerLips
    // - leftEyebrow, rightEyebrow
    // - leftPupil, rightPupil
}
```

### Body Pose Detection

Track human body poses:

```swift
import Vision

func detectBodyPose(in image: CGImage) async throws -> [VNHumanBodyPoseObservation] {
    let request = VNDetectHumanBodyPoseRequest()

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results ?? []
}

func processPose(_ observation: VNHumanBodyPoseObservation) throws {
    // Get all recognized points
    let recognizedPoints = try observation.recognizedPoints(.all)

    // Access specific joints
    if let nose = recognizedPoints[.nose], nose.confidence > 0.5 {
        print("Nose position: \(nose.location)")
    }

    if let leftWrist = recognizedPoints[.leftWrist], leftWrist.confidence > 0.5 {
        print("Left wrist: \(leftWrist.location)")
    }

    // Joint groups
    // - .torso: neck, leftShoulder, rightShoulder, etc.
    // - .leftArm: leftShoulder, leftElbow, leftWrist
    // - .rightArm: rightShoulder, rightElbow, rightWrist
    // - .leftLeg: leftHip, leftKnee, leftAnkle
    // - .rightLeg: rightHip, rightKnee, rightAnkle
}

// Hand pose detection
func detectHandPose(in image: CGImage) async throws -> [VNHumanHandPoseObservation] {
    let request = VNDetectHumanHandPoseRequest()
    request.maximumHandCount = 2

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    return request.results ?? []
}
```

### Core ML Integration

Use custom ML models with Vision:

```swift
import Vision
import CoreML

func classifyWithModel(image: CGImage, modelURL: URL) async throws -> [(String, Float)] {
    // Load the Core ML model
    let mlModel = try MLModel(contentsOf: modelURL)
    let visionModel = try VNCoreMLModel(for: mlModel)

    // Create Vision request
    let request = VNCoreMLRequest(model: visionModel) { request, error in
        // Handle results
    }

    // Configure preprocessing
    request.imageCropAndScaleOption = .centerCrop

    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])

    guard let results = request.results as? [VNClassificationObservation] else {
        return []
    }

    return results.map { ($0.identifier, $0.confidence) }
}
```

#### Real-Time Camera Classification

```swift
import Vision
import CoreML
import AVFoundation

class CameraClassifier: NSObject {
    private var visionModel: VNCoreMLModel!
    private var requests: [VNRequest] = []

    func setup(modelURL: URL) throws {
        let mlModel = try MLModel(contentsOf: modelURL)
        visionModel = try VNCoreMLModel(for: mlModel)

        let classificationRequest = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            self?.processClassifications(request: request)
        }
        classificationRequest.imageCropAndScaleOption = .centerCrop

        requests = [classificationRequest]
    }

    private func processClassifications(request: VNRequest) {
        guard let results = request.results as? [VNClassificationObservation] else { return }

        if let topResult = results.first {
            DispatchQueue.main.async {
                print("\(topResult.identifier): \(topResult.confidence * 100)%")
            }
        }
    }
}

// AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraClassifier: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

        do {
            try handler.perform(requests)
        } catch {
            print("Vision error: \(error)")
        }
    }
}
```

---

## VisionKit Framework

VisionKit provides high-level UI components for visual features.

### ImageAnalyzer and Visual Look Up

Analyze images for text, QR codes, and subjects:

```swift
import VisionKit

class ImageAnalysisManager {
    private let analyzer = ImageAnalyzer()

    func analyzeImage(_ image: UIImage) async throws -> ImageAnalysis {
        let configuration = ImageAnalyzer.Configuration([
            .text,
            .machineReadableCode,
            .visualLookUp
        ])

        return try await analyzer.analyze(image, configuration: configuration)
    }
}
```

#### Visual Look Up Supported Subjects

VisionKit can identify and provide information about:

- **Plants and flowers**
- **Animals** (cats, dogs, birds, reptiles, insects)
- **Places** (landmarks, sculptures, natural landmarks)
- **Art and media** (paintings, books, album covers)
- **Food** (prepared dishes, desserts)
- **Symbols** (laundry care labels, dashboard indicators)

### Live Text Interactions

Add Live Text to image views:

```swift
import VisionKit
import UIKit

class LiveTextImageViewController: UIViewController {
    private let imageView = UIImageView()
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup image view
        imageView.image = UIImage(named: "document")
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)

        // Add interaction
        imageView.addInteraction(interaction)

        // Configure interaction types
        interaction.preferredInteractionTypes = [
            .textSelection,
            .dataDetectors,
            .visualLookUp,
            .imageSubject
        ]

        // Analyze image
        Task {
            await analyzeImage()
        }
    }

    private func analyzeImage() async {
        guard let image = imageView.image else { return }

        let configuration = ImageAnalyzer.Configuration([
            .text,
            .machineReadableCode,
            .visualLookUp
        ])

        do {
            let analysis = try await analyzer.analyze(image, configuration: configuration)

            // Update interaction with analysis
            await MainActor.run {
                interaction.analysis = analysis
            }
        } catch {
            print("Analysis failed: \(error)")
        }
    }
}
```

#### Interaction Types

```swift
// Available interaction types
ImageAnalysisInteraction.InteractionTypes.automatic        // All supported
ImageAnalysisInteraction.InteractionTypes.textSelection    // Select/copy text
ImageAnalysisInteraction.InteractionTypes.dataDetectors    // Links, phones, dates
ImageAnalysisInteraction.InteractionTypes.visualLookUp     // Visual Look Up button
ImageAnalysisInteraction.InteractionTypes.imageSubject     // Subject lifting
ImageAnalysisInteraction.InteractionTypes.automaticTextOnly // Text only
```

### Subject Lifting

Extract subjects from images with background removed:

```swift
import VisionKit

func extractSubject(from image: UIImage, at point: CGPoint) async throws -> UIImage? {
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()

    // Configure for subject extraction
    interaction.preferredInteractionTypes = [.imageSubject]

    let configuration = ImageAnalyzer.Configuration([.visualLookUp])
    let analysis = try await analyzer.analyze(image, configuration: configuration)
    interaction.analysis = analysis

    // Get subject at point
    guard let subject = await interaction.subject(at: point) else {
        return nil
    }

    // Extract image with background removed
    return try await interaction.image(for: [subject])
}

// Get all subjects in image
func extractAllSubjects(from image: UIImage) async throws -> UIImage? {
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()

    interaction.preferredInteractionTypes = [.imageSubject]

    let configuration = ImageAnalyzer.Configuration([.visualLookUp])
    let analysis = try await analyzer.analyze(image, configuration: configuration)
    interaction.analysis = analysis

    // Get all subjects
    let subjects = interaction.subjects

    if subjects.isEmpty {
        return nil
    }

    // Extract combined image
    return try await interaction.image(for: subjects)
}
```

### DataScannerViewController

Live camera scanning for text and barcodes:

```swift
import VisionKit
import SwiftUI

struct DataScannerView: UIViewControllerRepresentable {
    @Binding var scannedText: String
    @Binding var scannedBarcode: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .text(),
                .barcode(symbologies: [.qr, .code128, .ean13])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Check availability
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerView

        init(_ parent: DataScannerView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                parent.scannedText = text.transcript
            case .barcode(let barcode):
                parent.scannedBarcode = barcode.payloadStringValue ?? ""
            @unknown default:
                break
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                switch item {
                case .text(let text):
                    print("Found text: \(text.transcript)")
                case .barcode(let barcode):
                    print("Found barcode: \(barcode.payloadStringValue ?? "N/A")")
                @unknown default:
                    break
                }
            }
        }
    }
}

// Usage in SwiftUI
struct ScannerView: View {
    @State private var scannedText = ""
    @State private var scannedBarcode = ""
    @State private var isShowingScanner = false

    var body: some View {
        VStack {
            if DataScannerView.isSupported {
                Button("Scan") {
                    isShowingScanner = true
                }
                .fullScreenCover(isPresented: $isShowingScanner) {
                    DataScannerView(scannedText: $scannedText, scannedBarcode: $scannedBarcode)
                }
            } else {
                Text("Scanning not supported on this device")
            }

            Text("Text: \(scannedText)")
            Text("Barcode: \(scannedBarcode)")
        }
    }
}
```

#### Text Content Types

```swift
// Recognize specific content types
let scanner = DataScannerViewController(
    recognizedDataTypes: [
        .text(textContentType: .fullStreetAddress),
        .text(textContentType: .telephoneNumber),
        .text(textContentType: .emailAddress),
        .text(textContentType: .URL),
        .text(textContentType: .dateTime)
    ]
)
```

---

## Visual Intelligence Framework (iOS 26+)

iOS 26 introduces system-level Visual Intelligence. The user enters it from the Camera Control (or the equivalent system entry point), points the camera at something (or shares a screenshot/photo), and the system surfaces results — including results your app supplies. Your app participates through **App Intents** (the `VisualIntelligence` framework supplies the data types; the integration plumbing lives in `AppIntents`).

> Verified against Apple's official docs (Context7 `/websites/developer_apple`, checked 2026-06-02): `VisualIntelligence` and `AppIntents/integrating-your-app-with-visual-intelligence`. The earlier draft of this section was wrong on every key API — corrected below.

The system hands your app a **`SemanticContentDescriptor`** (a struct describing the captured scene — screenshot, camera frame, or photo). You read its `pixelBuffer` (a `CVReadOnlyPixelBuffer`), run your own matching (Core ML, an embedding lookup, a server call), and return your app's entities. There are two pieces:

1. An **`@AppIntent(schema: .visualIntelligence.semanticContentSearch)`** intent whose single `@Parameter` is a `SemanticContentDescriptor`. This is the schema-conforming entry the system invokes.
2. An **`IntentValueQuery`** whose `values(for:)` takes the `SemanticContentDescriptor` and returns your result entities. This is what actually produces the grid of results Visual Intelligence shows.

### The semanticContentSearch intent

```swift
import AppIntents
import VisualIntelligence

// `schema:` is `.visualIntelligence.semanticContentSearch`, NOT `.semanticContentSearch`.
// The parameter is a `SemanticContentDescriptor`, NOT a `String`.
@available(iOS 26.0, *)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct SemanticContentSearchIntent: AppIntent {
    @Parameter var semanticContent: SemanticContentDescriptor

    func perform() async throws -> some IntentResult {
        // The system drives the results UI via the IntentValueQuery below.
        // `perform()` returns `.result()`; you do not navigate from here.
        return .result()
    }
}
```

### The IntentValueQuery — where results come from

```swift
import AppIntents
import VisualIntelligence
import CoreVideo

// Multiple entity types? Wrap them in an @UnionValue enum.
@available(iOS 26.0, *)
@UnionValue
enum VisualSearchResult {
    case landmark(LandmarkEntity)
    case collection(CollectionEntity)
}

@available(iOS 26.0, *)
struct LandmarkIntentValueQuery: IntentValueQuery {
    @Dependency var modelData: ModelData

    // Input is the SemanticContentDescriptor the system captured.
    func values(for input: SemanticContentDescriptor) async throws -> [VisualSearchResult] {
        guard let pixelBuffer: CVReadOnlyPixelBuffer = input.pixelBuffer else {
            return []
        }
        // Run YOUR matching against the captured frame — Core ML, embeddings, server.
        return try await modelData.search(matching: pixelBuffer)
    }
}
```

The entities you return (`LandmarkEntity`, `CollectionEntity`, …) are ordinary `AppEntity` types with a `displayRepresentation` (title/subtitle/image) — that's what renders in the Visual Intelligence results grid. Define them and their `EntityQuery` the usual App Intents way.

### Onscreen content (a different feature — Visual Intelligence on what's *on screen*)

To let the system reason about content your app is *currently displaying*, associate an `NSUserActivity` with the visible entity using the SwiftUI `.userActivity(_:element:)` modifier and `activity.appEntityIdentifier`. (The older `targetContentIdentifier` / `persistentIdentifier` approach is not the App-Intents-entity path.)

```swift
MediaView(asset: asset)
    .userActivity("com.example.app.ViewingPhoto", element: asset.entity) { asset, activity in
        activity.title = "Viewing a photo"
        activity.appEntityIdentifier = EntityIdentifier(for: asset)
    }
```

---

## SwiftUI Integration

### Camera Preview with Vision

```swift
import SwiftUI
import AVFoundation
import Vision

struct CameraVisionView: View {
    @StateObject private var camera = CameraViewModel()
    @State private var detectedText: String = ""

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text(detectedText)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
        .task {
            await camera.start()
        }
        .onReceive(camera.$recognizedText) { text in
            detectedText = text
        }
    }
}

@MainActor
class CameraViewModel: ObservableObject {
    let session = AVCaptureSession()
    @Published var recognizedText = ""

    private let textRequest = VNRecognizeTextRequest()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "vision.processing")

    func start() async {
        guard await checkAuthorization() else { return }

        setupSession()
        session.startRunning()
    }

    private func setupSession() {
        session.beginConfiguration()

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
    }

    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                    didOutput sampleBuffer: CMSampleBuffer,
                                    from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }

            let text = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")

            Task { @MainActor in
                self?.recognizedText = text
            }
        }
        request.recognitionLevel = .fast

        try? handler.perform([request])
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

### Image Analysis View

```swift
import SwiftUI
import VisionKit

struct ImageAnalysisView: View {
    let image: UIImage
    @State private var analysis: ImageAnalysis?
    @State private var hasVisualLookUp = false

    private let analyzer = ImageAnalyzer()

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()

            if hasVisualLookUp {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // Show Visual Look Up
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.title)
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            await analyzeImage()
        }
    }

    private func analyzeImage() async {
        let configuration = ImageAnalyzer.Configuration([
            .text,
            .visualLookUp
        ])

        do {
            analysis = try await analyzer.analyze(image, configuration: configuration)
            hasVisualLookUp = analysis?.hasResults(for: .visualLookUp) ?? false
        } catch {
            print("Analysis error: \(error)")
        }
    }
}
```

---

## Best Practices

### 1. Optimize for Real-Time Processing

```swift
// Use .fast recognition level for camera feeds
request.recognitionLevel = .fast

// Limit region of interest
request.regionOfInterest = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)

// Disable unnecessary features
request.usesLanguageCorrection = false
```

### 2. Handle Orientation Correctly

```swift
// Get proper orientation from device
func exifOrientation(from deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
    switch deviceOrientation {
    case .portraitUpsideDown:
        return .left
    case .landscapeLeft:
        return .up
    case .landscapeRight:
        return .down
    default:
        return .right
    }
}

let handler = VNImageRequestHandler(
    cvPixelBuffer: pixelBuffer,
    orientation: exifOrientation(from: UIDevice.current.orientation)
)
```

### 3. Process on Background Threads

```swift
// Create dedicated queue
let visionQueue = DispatchQueue(label: "vision.processing", qos: .userInitiated)

visionQueue.async {
    do {
        try handler.perform(requests)
    } catch {
        print("Vision error: \(error)")
    }
}
```

### 4. Throttle Frame Processing

```swift
class FrameThrottler {
    private var lastProcessTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.1  // 10 FPS

    func shouldProcess() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastProcessTime) >= minInterval {
            lastProcessTime = now
            return true
        }
        return false
    }
}
```

### 5. Check Feature Availability

```swift
// Check DataScanner availability
if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
    // Use DataScanner
}

// Check Visual Look Up availability
if ImageAnalyzer.isSupported {
    // Use ImageAnalyzer
}

// Check specific symbologies
let supportedSymbologies = VNDetectBarcodesRequest.supportedSymbologies
```

### 6. Handle Privacy Appropriately

```swift
// Always add camera usage description to Info.plist
// NSCameraUsageDescription - "This app uses the camera to scan documents."

// Request permission before accessing camera
AVCaptureDevice.requestAccess(for: .video) { granted in
    if granted {
        // Setup camera
    } else {
        // Show permission denied message
    }
}
```

---

## Resources

### Apple Documentation

- [Vision Framework](https://developer.apple.com/documentation/vision)
- [VisionKit Framework](https://developer.apple.com/documentation/visionkit)
- [Visual Intelligence](https://developer.apple.com/documentation/VisualIntelligence)
- [Core ML](https://developer.apple.com/documentation/coreml)
- [App Intents](https://developer.apple.com/documentation/appintents)

### WWDC Sessions

- [Discover Swift enhancements in the Vision framework - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/)
- [What's new in VisionKit - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10048/)
- [Capture machine-readable codes and text with VisionKit - WWDC22](https://developer.apple.com/videos/play/wwdc2022/10025/)
- [Get to know App Intents - WWDC25](https://developer.apple.com/videos/play/wwdc2025/244/)
- [Explore new advances in App Intents - WWDC25](https://developer.apple.com/videos/play/wwdc2025/275/)

### Additional Resources

- [Vision Framework Tutorial - Kodeco](https://www.kodeco.com/ios/paths/apple-ai-models/49307523-vision-framework)
- [Apple Intelligence Apps Guide](https://mobisoftinfotech.com/resources/blog/app-development/apple-intelligence-apps-ios-26-on-device-ai-guide)
- [iOS 26 Developer Guide](https://www.index.dev/blog/ios-26-developer-guide)
- [Apple Newsroom: Visual Intelligence](https://www.apple.com/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/)
