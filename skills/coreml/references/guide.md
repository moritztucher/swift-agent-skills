# CoreML Framework Guide

A comprehensive guide for integrating machine learning models into iOS applications using Apple's CoreML framework. This guide covers on-device ML inference, image classification, natural language processing, and Vision framework integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Model Integration](#model-integration)
4. [MLModel API](#mlmodel-api)
5. [MLFeatureProvider](#mlfeatureprovider)
6. [Async Predictions](#async-predictions)
7. [Vision Framework Integration](#vision-framework-integration)
8. [Image Classification](#image-classification)
9. [Object Detection](#object-detection)
10. [Natural Language Processing](#natural-language-processing)
11. [Model Configuration & Optimization](#model-configuration--optimization)
12. [SwiftUI Integration](#swiftui-integration)
13. [Best Practices](#best-practices)
14. [Common Pitfalls](#common-pitfalls)
15. [iOS Version Compatibility](#ios-version-compatibility)

---

## Overview

CoreML is Apple's framework for integrating machine learning models into iOS, iPadOS, macOS, tvOS, watchOS, and visionOS applications. It provides a unified representation for all models and enables on-device predictions, training, and fine-tuning.

### Key Benefits

- **Privacy**: All processing happens on-device; user data never leaves the device
- **Performance**: Optimized to leverage CPU, GPU, and Neural Engine
- **Offline**: No network connection required for predictions
- **Low Power**: Minimizes memory footprint and power consumption
- **Unified API**: Single framework for all ML model types

### Supported Use Cases

| Use Case | Description | Related Framework |
|----------|-------------|-------------------|
| Image Classification | Categorize images into predefined classes | Vision |
| Object Detection | Detect and locate objects within images | Vision |
| Text Classification | Categorize text into sentiment, topics, etc. | Natural Language |
| Named Entity Recognition | Identify entities in text (names, places) | Natural Language |
| Sound Classification | Identify sounds in audio | Sound Analysis |
| Speech Recognition | Convert audio to text | Speech |
| Custom ML Tasks | Any model trained with Create ML or converted | CoreML |

### Requirements

- iOS 11.0+, iPadOS 11.0+, macOS 10.13+, tvOS 11.0+, watchOS 4.0+, visionOS 1.0+
- For async predictions: iOS 17.0+
- Xcode with CoreML model support

### Import

```swift
import CoreML
import Vision      // For image-related tasks
import NaturalLanguage  // For text-related tasks
```

---

## Getting Started

### Minimal Example

```swift
import CoreML

// Load a pre-bundled model (Xcode generates the class automatically)
let model = try MyImageClassifier()

// Make a prediction
let prediction = try model.prediction(image: inputImage)
print(prediction.classLabel)
```

### Model Sources

1. **Create ML**: Apple's app bundled with Xcode for training models
2. **Core ML Tools**: Python package for converting models from TensorFlow, PyTorch, scikit-learn
3. **Pre-trained Models**: Apple's model gallery and third-party sources

---

## Model Integration

### Adding a Model to Your Project

1. Drag the `.mlmodel` file into your Xcode project
2. Xcode automatically generates a Swift class for the model
3. Access the generated class using the model's filename

### Model File Types

| Extension | Description |
|-----------|-------------|
| `.mlmodel` | Uncompiled model (Xcode compiles at build time) |
| `.mlmodelc` | Compiled model (ready for runtime) |
| `.mlpackage` | Model package with additional resources |

### Generated Model Class

When you add a model file, Xcode generates a class with:

```swift
// For a model named "ImageClassifier.mlmodel"
class ImageClassifier {
    // The underlying MLModel
    var model: MLModel

    // Initializers
    init(configuration: MLModelConfiguration = MLModelConfiguration()) throws

    // Prediction methods (input/output types depend on model)
    func prediction(image: CVPixelBuffer) throws -> ImageClassifierOutput
}
```

### Loading Models at Runtime

```swift
// Load from bundle
let modelURL = Bundle.main.url(forResource: "MyModel", withExtension: "mlmodelc")!
let model = try MLModel(contentsOf: modelURL)

// Load with configuration
let config = MLModelConfiguration()
config.computeUnits = .all
let model = try MLModel(contentsOf: modelURL, configuration: config)
```

---

## MLModel API

### MLModel Class

The `MLModel` class represents a compiled machine learning model.

```swift
// Properties
model.modelDescription  // MLModelDescription with input/output info
model.configuration     // MLModelConfiguration used to load

// Synchronous prediction
let output = try model.prediction(from: inputFeatures)

// Async prediction (iOS 17+)
let output = try await model.prediction(from: inputFeatures, options: options)
```

### MLModelDescription

Access model metadata and input/output specifications:

```swift
let description = model.modelDescription

// Input features
for (name, feature) in description.inputDescriptionsByName {
    print("Input: \(name), Type: \(feature.type)")
}

// Output features
for (name, feature) in description.outputDescriptionsByName {
    print("Output: \(name), Type: \(feature.type)")
}

// Model metadata
print("Author: \(description.metadata[.author] ?? "Unknown")")
print("Description: \(description.metadata[.description] ?? "None")")
```

### MLModelConfiguration

Configure how the model runs:

```swift
let config = MLModelConfiguration()

// Compute units
config.computeUnits = .all          // CPU, GPU, and Neural Engine
config.computeUnits = .cpuAndGPU    // CPU and GPU only
config.computeUnits = .cpuOnly      // CPU only
config.computeUnits = .cpuAndNeuralEngine  // CPU and Neural Engine

// Allow low-precision computation for better performance
config.allowLowPrecisionAccumulationOnGPU = true

// Set preferred Metal device (macOS)
// config.preferredMetalDevice = MTLCreateSystemDefaultDevice()
```

---

## MLFeatureProvider

`MLFeatureProvider` is a protocol for providing input features to a model and receiving output features.

### Creating Custom Feature Providers

```swift
class ImageInputFeatures: MLFeatureProvider {
    let image: CVPixelBuffer

    var featureNames: Set<String> {
        return ["image"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "image" {
            return MLFeatureValue(pixelBuffer: image)
        }
        return nil
    }

    init(image: CVPixelBuffer) {
        self.image = image
    }
}
```

### Using MLDictionaryFeatureProvider

For simple cases, use the built-in dictionary provider:

```swift
let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
    "input1": MLFeatureValue(double: 1.5),
    "input2": MLFeatureValue(string: "hello"),
    "input3": MLFeatureValue(pixelBuffer: imageBuffer)
])

let output = try model.prediction(from: inputFeatures)
```

### MLFeatureValue Types

```swift
// Numeric
MLFeatureValue(double: 3.14)
MLFeatureValue(int64: 42)

// String
MLFeatureValue(string: "category")

// Image/Pixel Buffer
MLFeatureValue(pixelBuffer: cvPixelBuffer)
MLFeatureValue(cgImage: cgImage, pixelsWide: 224, pixelsHigh: 224)

// Multi-array (tensors)
MLFeatureValue(multiArray: mlMultiArray)

// Dictionary
MLFeatureValue(dictionary: ["key": 1.0])

// Sequence
MLFeatureValue(sequence: mlSequence)
```

---

## Async Predictions

### iOS 17+ Async API

Starting with iOS 17, CoreML supports native async/await predictions:

```swift
// Async model loading
let model = try await MLModel.load(contentsOf: modelURL, configuration: config)

// Async prediction
let output = try await model.prediction(from: inputFeatures)

// Async prediction with options
let options = MLPredictionOptions()
let output = try await model.prediction(from: inputFeatures, options: options)
```

### Pre-iOS 17 Async Pattern

For iOS 16 and earlier, wrap synchronous calls:

```swift
func makePrediction(input: MyModelInput) async throws -> MyModelOutput {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let output = try self.model.prediction(input: input)
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### MLPredictionOptions

Configure prediction behavior:

```swift
let options = MLPredictionOptions()

// outputBackings: reuse client-allocated buffers for output features
// options.outputBackings = ["output": myPixelBuffer]
```

> **Deprecated:** `MLPredictionOptions.usesCPUOnly` is deprecated. To pin compute units, set
> `MLModelConfiguration.computeUnits = .cpuOnly` when loading the model instead of per-prediction.

---

## Vision Framework Integration

The Vision framework provides high-level APIs for image analysis that integrate seamlessly with CoreML models.

### VNCoreMLModel

Wrap a CoreML model for use with Vision:

```swift
import Vision

// Create VNCoreMLModel from generated class
let coreMLModel = try MyImageClassifier(configuration: config).model
let visionModel = try VNCoreMLModel(for: coreMLModel)

// Or from MLModel directly
let visionModel = try VNCoreMLModel(for: mlModel)
```

### VNCoreMLRequest

Create a Vision request using a CoreML model:

```swift
let request = VNCoreMLRequest(model: visionModel) { request, error in
    guard let results = request.results else {
        print("No results: \(error?.localizedDescription ?? "Unknown error")")
        return
    }
    // Process results
}

// Configure image preprocessing
request.imageCropAndScaleOption = .centerCrop  // or .scaleFill, .scaleFit
```

### VNImageRequestHandler

Execute Vision requests on images:

```swift
// From CGImage
let handler = VNImageRequestHandler(
    cgImage: cgImage,
    orientation: .up,
    options: [:]
)

// From CVPixelBuffer (camera frames)
let handler = VNImageRequestHandler(
    cvPixelBuffer: pixelBuffer,
    orientation: .right,
    options: [:]
)

// From URL
let handler = VNImageRequestHandler(
    url: imageURL,
    options: [:]
)

// Perform requests
try handler.perform([request])
```

---

## Image Classification

### Complete Image Classification Example

```swift
import CoreML
import Vision
import SwiftUI

@Observable
class ImageClassifier {
    var classifications: [Classification] = []
    var isProcessing = false
    var errorMessage: String?

    private var visionModel: VNCoreMLModel?

    struct Classification: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
    }

    init() {
        setupModel()
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all

            let model = try MobileNetV2(configuration: config)
            visionModel = try VNCoreMLModel(for: model.model)
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    func classify(image: CGImage) async {
        guard let visionModel = visionModel else {
            errorMessage = "Model not loaded"
            return
        }

        await MainActor.run {
            isProcessing = true
            classifications = []
            errorMessage = nil
        }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results as? [VNClassificationObservation] else {
                throw ClassificationError.noResults
            }

            let topResults = results
                .prefix(5)
                .map { Classification(label: $0.identifier, confidence: $0.confidence) }

            await MainActor.run {
                self.classifications = topResults
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    enum ClassificationError: LocalizedError {
        case noResults

        var errorDescription: String? {
            switch self {
            case .noResults:
                return "No classification results returned"
            }
        }
    }
}
```

### SwiftUI View for Classification

```swift
struct ImageClassificationView: View {
    @State private var classifier = ImageClassifier()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Select Image") {
                    showImagePicker = true
                }
                .buttonStyle(.borderedProminent)

                if classifier.isProcessing {
                    ProgressView("Classifying...")
                }

                if let error = classifier.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }

                if !classifier.classifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Results")
                            .font(.headline)

                        ForEach(classifier.classifications) { classification in
                            HStack {
                                Text(classification.label)
                                Spacer()
                                Text("\(Int(classification.confidence * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Image Classifier")
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            guard let image = newImage, let cgImage = image.cgImage else { return }
            Task {
                await classifier.classify(image: cgImage)
            }
        }
    }
}
```

---

## Object Detection

### Object Detection with Bounding Boxes

```swift
import CoreML
import Vision

@Observable
class ObjectDetector {
    var detections: [Detection] = []
    var isProcessing = false

    struct Detection: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
        let boundingBox: CGRect  // Normalized coordinates (0-1)
    }

    private var visionModel: VNCoreMLModel?

    init() {
        setupModel()
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all

            // Use your object detection model
            let model = try YOLOv3(configuration: config)
            visionModel = try VNCoreMLModel(for: model.model)
        } catch {
            print("Failed to load model: \(error)")
        }
    }

    func detect(in image: CGImage) async {
        guard let visionModel = visionModel else { return }

        await MainActor.run {
            isProcessing = true
            detections = []
        }

        let request = VNCoreMLRequest(model: visionModel)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                return
            }

            let detected = results.compactMap { observation -> Detection? in
                guard let topLabel = observation.labels.first else { return nil }
                return Detection(
                    label: topLabel.identifier,
                    confidence: topLabel.confidence,
                    boundingBox: observation.boundingBox
                )
            }

            await MainActor.run {
                self.detections = detected
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }
}
```

### Drawing Bounding Boxes

```swift
struct BoundingBoxOverlay: View {
    let detections: [ObjectDetector.Detection]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ForEach(detections) { detection in
                let rect = convertBoundingBox(
                    detection.boundingBox,
                    to: geometry.size
                )

                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(alignment: .topLeading) {
                        Text("\(detection.label) \(Int(detection.confidence * 100))%")
                            .font(.caption)
                            .padding(4)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .position(x: rect.minX + 40, y: rect.minY - 10)
                    }
            }
        }
    }

    private func convertBoundingBox(_ box: CGRect, to size: CGSize) -> CGRect {
        // Vision coordinates: origin at bottom-left, normalized 0-1
        // SwiftUI coordinates: origin at top-left
        CGRect(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,  // Flip Y axis
            width: box.width * size.width,
            height: box.height * size.height
        )
    }
}
```

---

## Natural Language Processing

### Text Classification

```swift
import CoreML
import NaturalLanguage

@Observable
class SentimentAnalyzer {
    var sentiment: String = ""
    var confidence: Double = 0

    private var model: NLModel?

    init() {
        setupModel()
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            let mlModel = try SentimentClassifier(configuration: config).model
            model = try NLModel(mlModel: mlModel)
        } catch {
            print("Failed to load model: \(error)")
        }
    }

    func analyze(text: String) async {
        guard let model = model else { return }

        let result = model.predictedLabel(for: text)
        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: 1)

        await MainActor.run {
            self.sentiment = result ?? "Unknown"
            self.confidence = hypotheses[result ?? ""] ?? 0
        }
    }
}
```

### Using Apple's Built-in NLP

For common NLP tasks, use Natural Language framework directly (no custom model needed):

```swift
import NaturalLanguage

@Observable
class TextAnalyzer {
    var language: String = ""
    var sentiment: Double = 0  // -1 (negative) to 1 (positive)
    var entities: [NamedEntity] = []

    struct NamedEntity: Identifiable {
        let id = UUID()
        let text: String
        let type: NLTag
        let range: Range<String.Index>
    }

    // Language detection
    func detectLanguage(text: String) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage {
            self.language = language.rawValue
        }
    }

    // Sentiment analysis (built-in)
    func analyzeSentiment(text: String) {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(
            at: text.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )

        self.sentiment = Double(sentiment?.rawValue ?? "0") ?? 0
    }

    // Named entity recognition
    func extractEntities(text: String) {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        let tags: [NLTag] = [.personalName, .placeName, .organizationName]

        var foundEntities: [NamedEntity] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag, tags.contains(tag) {
                foundEntities.append(NamedEntity(
                    text: String(text[range]),
                    type: tag,
                    range: range
                ))
            }
            return true
        }

        self.entities = foundEntities
    }
}
```

---

## Model Configuration & Optimization

### Compute Unit Selection

Choose the appropriate compute units based on your use case:

```swift
let config = MLModelConfiguration()

// Maximum performance - uses all available hardware
config.computeUnits = .all

// Battery-sensitive - avoids Neural Engine when on battery
config.computeUnits = .cpuAndGPU

// Background tasks - minimal power consumption
config.computeUnits = .cpuOnly

// Neural Engine focus (where available)
config.computeUnits = .cpuAndNeuralEngine
```

### Performance Guidelines

| Compute Unit | Best For | Considerations |
|--------------|----------|----------------|
| `.all` | Real-time inference, user-facing features | Maximum performance, higher power |
| `.cpuAndGPU` | General ML tasks | Good balance of performance and power |
| `.cpuOnly` | Background processing, testing | Lowest power, predictable timing |
| `.cpuAndNeuralEngine` | Neural network models | Optimized for deep learning |

### Model Compilation

Compile models at runtime for dynamic model loading:

```swift
// Compile model at runtime
let compiledURL = try await MLModel.compileModel(at: sourceModelURL)

// Load compiled model
let model = try await MLModel.load(contentsOf: compiledURL)

// Clean up temporary compiled model
try FileManager.default.removeItem(at: compiledURL)
```

> **Deprecated:** `MLModelCollection` (the old "deploy models from a cloud collection" API) is
> deprecated — use **Background Assets** or a plain `URLSession` download, then `compileModel(at:)` +
> `load(contentsOf:)` as above. Don't reach for `MLModelCollection.beginAccessingModelCollection`.

### Quantization Benefits

Quantized models (8-bit instead of 32-bit) offer:
- 4x smaller file size
- Faster inference on Neural Engine
- Lower memory usage
- Slight accuracy trade-off

Use Core ML Tools to quantize:
```bash
# Python
import coremltools as ct
model = ct.models.MLModel('model.mlmodel')
quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(model, nbits=8)
quantized_model.save('model_quantized.mlmodel')
```

---

## SwiftUI Integration

### Complete ML Manager Pattern

```swift
import CoreML
import Vision
import SwiftUI

@Observable
class MLManager {
    // MARK: - State
    var isModelLoaded = false
    var isProcessing = false
    var predictions: [Prediction] = []
    var errorMessage: String?

    // MARK: - Types
    struct Prediction: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
    }

    // MARK: - Private Properties
    private var visionModel: VNCoreMLModel?
    private let modelLoadingTask = Task<Void, Never> {}

    // MARK: - Initialization
    init() {
        Task {
            await loadModel()
        }
    }

    // MARK: - Model Loading
    @MainActor
    func loadModel() async {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all

            // iOS 17+ async loading
            if #available(iOS 17.0, *) {
                let modelURL = Bundle.main.url(
                    forResource: "MobileNetV2",
                    withExtension: "mlmodelc"
                )!
                let mlModel = try await MLModel.load(
                    contentsOf: modelURL,
                    configuration: config
                )
                visionModel = try VNCoreMLModel(for: mlModel)
            } else {
                // iOS 16 and earlier
                let mlModel = try MobileNetV2(configuration: config).model
                visionModel = try VNCoreMLModel(for: mlModel)
            }

            isModelLoaded = true
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    // MARK: - Prediction
    func classify(image: CGImage) async {
        guard let visionModel = visionModel else {
            errorMessage = "Model not loaded"
            return
        }

        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }

        do {
            let predictions = try await performClassification(
                image: image,
                model: visionModel
            )

            await MainActor.run {
                self.predictions = predictions
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    private func performClassification(
        image: CGImage,
        model: VNCoreMLModel
    ) async throws -> [Prediction] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let predictions = results.prefix(5).map {
                    Prediction(label: $0.identifier, confidence: $0.confidence)
                }
                continuation.resume(returning: predictions)
            }

            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Environment Integration

```swift
@main
struct MyApp: App {
    @State private var mlManager = MLManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(mlManager)
        }
    }
}

struct ContentView: View {
    @Environment(MLManager.self) var mlManager

    var body: some View {
        VStack {
            if mlManager.isModelLoaded {
                Text("Model Ready")
            } else {
                ProgressView("Loading Model...")
            }
        }
    }
}
```

---

## Best Practices

### 1. Load Models Asynchronously

Never block the main thread when loading models:

```swift
// Good - async loading
Task {
    await loadModel()
}

// Bad - blocking main thread
let model = try MLModel(contentsOf: url)  // Don't do this on main thread
```

### 2. Reuse Model Instances

Create model instances once and reuse them:

```swift
// Good - single instance
class ImageService {
    private let model: VNCoreMLModel

    init() throws {
        let mlModel = try MyModel()
        model = try VNCoreMLModel(for: mlModel.model)
    }

    func classify(_ image: CGImage) async throws -> [Result] {
        // Use self.model
    }
}

// Bad - creating new instance per prediction
func classify(_ image: CGImage) async throws {
    let model = try MyModel()  // Expensive!
    // ...
}
```

### 3. Choose Appropriate Compute Units

```swift
// Real-time camera processing
config.computeUnits = .all

// Background batch processing
config.computeUnits = .cpuOnly

// General use
config.computeUnits = .cpuAndGPU
```

### 4. Handle Model Updates Gracefully

```swift
@Observable
class ModelManager {
    private var currentModel: MLModel?

    func updateModel(from url: URL) async throws {
        // Load new model
        let newModel = try await MLModel.load(contentsOf: url)

        // Atomic swap
        await MainActor.run {
            self.currentModel = newModel
        }
    }
}
```

### 5. Use Vision for Image Processing

Let Vision handle image preprocessing:

```swift
// Good - Vision handles resizing, color space conversion
let request = VNCoreMLRequest(model: visionModel)
request.imageCropAndScaleOption = .centerCrop

// Avoid manual preprocessing when possible
```

### 6. Batch Predictions When Possible

```swift
// Process multiple inputs efficiently
func classifyBatch(images: [CGImage]) async throws -> [[Prediction]] {
    try await withThrowingTaskGroup(of: (Int, [Prediction]).self) { group in
        for (index, image) in images.enumerated() {
            group.addTask {
                let predictions = try await self.classify(image)
                return (index, predictions)
            }
        }

        var results: [(Int, [Prediction])] = []
        for try await result in group {
            results.append(result)
        }

        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
}
```

---

## Common Pitfalls

### 1. Model Size Issues

**Problem**: Large models increase app size and memory usage.

**Solutions**:
- Use quantized models (8-bit vs 32-bit weights)
- Consider on-demand model downloads
- Use smaller model architectures (MobileNet vs ResNet)

```swift
// Download model on-demand
func downloadModel() async throws -> URL {
    let modelURL = URL(string: "https://example.com/model.mlmodelc.zip")!
    let (localURL, _) = try await URLSession.shared.download(from: modelURL)

    // Unzip and return compiled model URL
    return try unzipModel(from: localURL)
}
```

### 2. Memory Management

**Problem**: Models can consume significant memory.

**Solutions**:
- Release models when not needed
- Use `.cpuOnly` for background tasks
- Monitor memory with Instruments

```swift
@Observable
class MLService {
    private var model: MLModel?

    func loadModel() async throws {
        model = try await MLModel.load(contentsOf: modelURL)
    }

    func unloadModel() {
        model = nil  // Release memory
    }
}
```

### 3. Thread Safety

**Problem**: CoreML models are not thread-safe.

**Solutions**:
- Use actors for thread-safe access
- Create separate model instances per concurrent task
- Use serial queues for predictions

```swift
actor MLPredictor {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    func predict(input: MLFeatureProvider) throws -> MLFeatureProvider {
        try model.prediction(from: input)
    }
}
```

### 4. Input Preprocessing Errors

**Problem**: Incorrect image format or size causes prediction failures.

**Solutions**:
- Use Vision framework for automatic preprocessing
- Validate input dimensions match model requirements
- Handle orientation correctly

```swift
// Check model input requirements
let inputDesc = model.modelDescription.inputDescriptionsByName["image"]
if let imageConstraint = inputDesc?.imageConstraint {
    print("Expected size: \(imageConstraint.pixelsWide) x \(imageConstraint.pixelsHigh)")
}
```

### 5. Ignoring Model Metadata

**Problem**: Not checking model compatibility or requirements.

**Solution**: Always validate model metadata:

```swift
func validateModel(_ model: MLModel) -> Bool {
    let description = model.modelDescription

    // Check for required inputs
    guard description.inputDescriptionsByName["image"] != nil else {
        print("Model missing required 'image' input")
        return false
    }

    // Check iOS version requirements
    // (handled by MLModel loading, but good to verify)

    return true
}
```

---

## Stateful Models (iOS 18+)

Models that carry state between predictions (e.g. KV-cache in transformer decoders, recurrent
generators) avoid re-passing the full history each call. Core ML manages the state buffers for you.

```swift
// Create a state object once, reuse it across the generation loop.
let state = model.makeState()

for step in 0..<maxTokens {
    let output = try model.prediction(from: input, using: state, options: options)
    // ...feed output back as next input; `state` accumulates the KV-cache.
}
```

Do **not** issue a second prediction that shares the same `state` while the first is in-flight —
behavior is undefined. One `MLState` per concurrent generation stream.

---

## Model Encryption (iOS 13+)

Protect a bundled model's weights at rest. You generate an encryption key in Xcode (Core ML model
editor → encrypt), and the `.mlmodelc` ships encrypted. At runtime nothing changes in your call
site — the generated class's `load(configuration:completionHandler:)` (or
`MLModel.load(contentsOf:configuration:)`) decrypts transparently using the key, which is fetched
once from Apple's servers and cached. Handle `MLModelError.Code.modelDecryption` for the
offline-first-launch failure case.

```swift
MyModel.load { result in
    switch result {
    case .success(let model): // use model
    case .failure(let error): // e.g. modelDecryption when key can't be fetched
    }
}
```

---

## iOS Version Compatibility

### API Availability Matrix

| Feature | iOS 11 | iOS 12 | iOS 14 | iOS 16 | iOS 17 |
|---------|--------|--------|--------|--------|--------|
| Basic MLModel | Yes | Yes | Yes | Yes | Yes |
| MLComputeUnits.all | - | Yes | Yes | Yes | Yes |
| VNCoreMLRequest | Yes | Yes | Yes | Yes | Yes |
| On-device training | - | - | Yes | Yes | Yes |
| Async model loading | - | - | - | - | Yes |
| Async predictions | - | - | - | - | Yes |

### Version-Specific Code

```swift
// iOS 17+ async APIs
if #available(iOS 17.0, *) {
    let model = try await MLModel.load(contentsOf: url)
    let output = try await model.prediction(from: input)
} else {
    // iOS 16 and earlier - use background queue
    let model = try MLModel(contentsOf: url)
    let output = try model.prediction(from: input)
}
```

### Minimum Deployment Considerations

```swift
// Check runtime availability
func isNeuralEngineAvailable() -> Bool {
    if #available(iOS 12.0, *) {
        // Neural Engine available on A12+ chips
        // No direct API to check, but .all compute units will use it if available
        return true
    }
    return false
}
```

---

## Additional Resources

- [Apple CoreML Documentation](https://developer.apple.com/documentation/coreml)
- [Create ML](https://developer.apple.com/documentation/createml)
- [Core ML Tools (Python)](https://coremltools.readme.io/)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [Natural Language Framework](https://developer.apple.com/documentation/naturallanguage)
- [Apple Machine Learning Research](https://machinelearning.apple.com/)

---

**Document Information**
- Created: 2026-02-03
- iOS Versions: iOS 11.0+ (basic), iOS 17.0+ (async APIs)
- Frameworks: CoreML, Vision, NaturalLanguage
- Swift Version: 5.9+
