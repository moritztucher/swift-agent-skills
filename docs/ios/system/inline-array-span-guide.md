# Swift InlineArray and Span Guide

> New types in Swift 6.2 (iOS 26+) for stack-allocated fixed-size arrays and memory-safe contiguous access.

## Overview

Swift 6.2 introduces two powerful types for performance-critical code:

- **InlineArray**: Fixed-size arrays stored inline (stack-allocated) without heap allocation
- **Span**: Safe, zero-overhead view into contiguous memory

Both types enable systems-level programming while maintaining Swift's memory safety guarantees.

---

## InlineArray

### What is InlineArray?

`InlineArray` is a fixed-size collection type that stores elements directly inline rather than allocating an out-of-line region of memory. This means elements are stored on the stack (or inline with heap objects when used as class properties), eliminating heap allocation overhead.

**Swift Evolution Proposals:**
- [SE-0452: Integer Generic Parameters](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md)
- [SE-0453: InlineArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md)
- [SE-0483: InlineArray Type Sugar](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0483-inline-array-sugar.md)

### Declaration

```swift
@frozen
public struct InlineArray<let count: Int, Element: ~Copyable>: ~Copyable {}
```

The `count` parameter is a compile-time constant using value generics, making the size part of the type itself.

### Key Characteristics

| Feature | InlineArray | Standard Array |
|---------|-------------|----------------|
| Size | Fixed at compile time | Dynamic |
| Storage | Inline (stack/struct) | Heap-allocated buffer |
| Copy semantics | Eager copy | Copy-on-write |
| Reference counting | None | Required |
| Heap allocation | Never (for storage) | Always |
| Sequence/Collection | No | Yes |

### Initialization

**Array literal (preferred):**
```swift
let numbers: InlineArray<3, Int> = [1, 2, 3]
```

**Type inference:**
```swift
let a: InlineArray<_, Int> = [1, 2, 3, 4]  // count inferred as 4
let b: InlineArray<4, _> = [1, 2, 3, 4]    // element type inferred
let c = InlineArray<4, Int>(repeating: 0)  // explicit
```

**Index-based closure:**
```swift
let squares = InlineArray<5, Int> { index in
    index * index
}
// [0, 1, 4, 9, 16]
```

**Sequential closure:**
```swift
let fibonacci = InlineArray<8, Int>(first: 1) { previous in
    previous <= 1 ? 1 : previous * 2  // Simplified example
}
```

**Repeating value:**
```swift
let zeros = InlineArray<10, Int>(repeating: 0)
```

### Type Sugar Syntax (SE-0483)

Swift 6.2 introduces shorthand syntax using `[N of Element]`:

```swift
// These are equivalent:
let verbose: InlineArray<5, Int> = .init(repeating: 99)
let sugar: [5 of Int] = .init(repeating: 99)
```

**Nesting:**
```swift
let matrix: [3 of [3 of Double]] = .init(repeating: .init(repeating: 0.0))
```

**Type inference with placeholders:**
```swift
let inferred: [5 of _] = .init(repeating: 99)      // Element inferred
let counted: [_ of Int8] = [1, 2, 3, 4]            // Count inferred
```

**In expressions:**
```swift
let doubles = [5 of Double](repeating: 1.23)
MemoryLayout<[5 of Int]>.size  // 40 on 64-bit
```

### Properties and Methods

**Properties:**
```swift
var array: InlineArray<4, Int> = [1, 2, 3, 4]

array.count        // 4 (also available as static property)
array.isEmpty      // false
array.indices      // 0..<4
array.startIndex   // 0
array.endIndex     // 4
```

**Subscript access:**
```swift
let value = array[0]           // Bounds-checked
array[1] = 10                  // Mutation

let unsafe = array[unchecked: 0]  // No bounds check (performance)
```

**Index navigation:**
```swift
let next = array.index(after: 0)    // 1
let prev = array.index(before: 2)   // 1
```

**Mutation:**
```swift
array.swapAt(0, 3)  // Swap elements at indices 0 and 3
```

### Memory Layout

InlineArray has predictable memory layout:
- **Size**: `Element.stride * count`
- **Alignment**: Same as `Element.alignment`

```swift
MemoryLayout<InlineArray<4, UInt8>>.size       // 4
MemoryLayout<InlineArray<4, UInt8>>.alignment  // 1

MemoryLayout<InlineArray<4, Int>>.size         // 32 (on 64-bit)
MemoryLayout<InlineArray<4, Int>>.alignment    // 8
```

### Protocol Conformances

```swift
extension InlineArray: Copyable where Element: Copyable {}
extension InlineArray: BitwiseCopyable where Element: BitwiseCopyable {}
extension InlineArray: Sendable where Element: Sendable {}
```

**Important:** InlineArray intentionally does NOT conform to `Sequence` or `Collection` to avoid implicit copies. Use explicit iteration:

```swift
var array: [3 of Int] = [1, 2, 3]

// Manual iteration
for i in array.indices {
    print(array[i])
}

// Or get a span for safe iteration
let span = array.span
for i in 0..<span.count {
    print(span[i])
}
```

### Use Cases

**1. Performance-critical fixed-size data:**
```swift
struct Color {
    var components: [4 of Float]  // RGBA, always 4 components

    var red: Float { components[0] }
    var green: Float { components[1] }
    var blue: Float { components[2] }
    var alpha: Float { components[3] }
}
```

**2. Geometric primitives:**
```swift
struct Triangle {
    var vertices: [3 of SIMD3<Float>]
}

struct Matrix4x4 {
    var columns: [4 of SIMD4<Float>]
}
```

**3. Buffer pools and ring buffers:**
```swift
struct AudioBuffer {
    var samples: [1024 of Float]
}
```

**4. Replacing C arrays in interop:**
```swift
// Instead of importing C array as tuple:
// var data: (UInt8, UInt8, UInt8, UInt8)

// Use InlineArray:
var data: [4 of UInt8] = [0, 0, 0, 0]
```

---

## Span

### What is Span?

`Span` provides safe, direct access to contiguous memory without compromising memory safety. It serves as a safe alternative to unsafe pointers, offering zero-overhead memory views with compile-time safety guarantees.

**Swift Evolution Proposal:**
- [SE-0447: Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)

### Declaration

```swift
@frozen
public struct Span<Element: ~Copyable>: Copyable, ~Escapable {
    internal var _start: UnsafeRawPointer?
    internal var _count: Int
}

extension Span: Sendable where Element: Sendable & ~Copyable {}
```

The `~Escapable` marker is critical: spans cannot escape their defining scope, ensuring temporal safety.

### Span Family Types

| Type | Purpose |
|------|---------|
| `Span<Element>` | Read-only typed access |
| `MutableSpan<Element>` | Mutable typed access |
| `RawSpan` | Read-only untyped byte access |
| `MutableRawSpan` | Mutable untyped byte access |
| `OutputSpan<Element>` | For initializing new collections |
| `UTF8Span` | Specialized for Unicode processing |

### Safety Guarantees

Span maintains four core Swift safety properties:

1. **Temporal Safety**: Non-escapable constraint prevents use-after-free
2. **Spatial Safety**: All subscript operations are bounds-checked
3. **Definite Initialization**: Spans only represent initialized memory
4. **Type Safety**: Generic `Element` enforces type consistency

**Compile-time constraints:**
- Cannot escape scope (cannot be returned from functions)
- Cannot be captured by closures
- Invalidated on mutation of the original container

### Getting a Span

```swift
// From Array
let array = [1, 2, 3, 4, 5]
let span = array.span  // Span<Int>

// From InlineArray
var inlineArray: [4 of Int] = [1, 2, 3, 4]
let inlineSpan = inlineArray.span

// From Data
let data = Data([0x01, 0x02, 0x03])
let dataSpan = data.span  // Span<UInt8>

// From String
let string = "Hello"
let utf8Span = string.utf8.span
```

### Properties and Methods

**Basic API:**
```swift
let span = array.span

span.count        // Number of elements
span.isEmpty      // Emptiness check
span.indices      // Range<Index>

let value = span[0]              // Bounds-checked access
let unsafe = span[unchecked: 0]  // Unchecked (performance)
```

**Slicing:**
```swift
let subspan = span[1..<3]  // Get subsequence
```

**Identity and relationship:**
```swift
let span1 = array.span
let span2 = array.span

span1.isIdentical(to: span2)      // Check if same memory
span1.indices(of: subspan)        // Get indices of subspan within parent
```

### Unsafe Interoperability

When you need to interface with C APIs or unsafe code:

```swift
let array = [1, 2, 3, 4]
let span = array.span

// Access underlying buffer
span.withUnsafeBufferPointer { buffer in
    // buffer is UnsafeBufferPointer<Int>
    someCFunction(buffer.baseAddress!, buffer.count)
}

// Access raw bytes
span.withUnsafeBytes { rawBuffer in
    // rawBuffer is UnsafeRawBufferPointer
    processBytes(rawBuffer)
}
```

### RawSpan for Byte-Level Access

`RawSpan` provides untyped memory access for parsing and binary data:

```swift
let data = Data([0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00])
let rawSpan = data.bytes  // RawSpan

// Load typed values from raw bytes
let value1: Int32 = rawSpan.unsafeLoad(fromByteOffset: 0, as: Int32.self)
let value2: Int32 = rawSpan.unsafeLoad(fromByteOffset: 4, as: Int32.self)

// Unaligned loads for packed data
let unaligned: UInt16 = rawSpan.unsafeLoadUnaligned(
    fromByteOffset: 1,
    as: UInt16.self
)
```

### Use Cases

**1. Efficient iteration without copying:**
```swift
func sum(_ values: borrowing Span<Int>) -> Int {
    var result = 0
    for i in values.indices {
        result += values[i]
    }
    return result
}

let array = [1, 2, 3, 4, 5]
let total = sum(array.span)
```

**2. Safe binary parsing:**
```swift
func parseHeader(_ data: RawSpan) -> Header? {
    guard data.count >= 16 else { return nil }

    let magic: UInt32 = data.unsafeLoad(fromByteOffset: 0, as: UInt32.self)
    let version: UInt32 = data.unsafeLoad(fromByteOffset: 4, as: UInt32.self)
    let length: UInt64 = data.unsafeLoad(fromByteOffset: 8, as: UInt64.self)

    return Header(magic: magic, version: version, length: length)
}
```

**3. Interoperating with C/C++:**
```swift
// Swift can pass spans to annotated C++ functions
// that expect std::span-like parameters
```

---

## Performance Comparison

### InlineArray vs Array

```swift
// Standard Array - heap allocation
var dynamicArray = [Int](repeating: 0, count: 4)
// - Heap allocation for buffer
// - Reference counting
// - Copy-on-write checks
// - Uniqueness checks on mutation

// InlineArray - stack allocation
var inlineArray: [4 of Int] = [0, 0, 0, 0]
// - No heap allocation
// - No reference counting
// - Eager copies (no COW overhead)
// - No uniqueness checks
```

### When to Use Each

**Use `Array` when:**
- Size is unknown or varies at runtime
- You need `Sequence`/`Collection` protocol conformance
- Copy-on-write semantics benefit your use case
- Interoperating with APIs that expect `Array`

**Use `InlineArray` when:**
- Size is fixed and known at compile time
- Performance is critical (games, audio, graphics)
- Avoiding heap allocation is important
- Working with embedded systems or constrained environments
- You need to embed fixed-size data in structs

**Use `Span` when:**
- Processing data without ownership transfer
- Implementing algorithms that work on any contiguous storage
- Interfacing with low-level or C APIs safely
- Avoiding unnecessary copies in hot paths

---

## Best Practices

### InlineArray

```swift
// DO: Use for fixed-size data structures
struct Pixel {
    var channels: [4 of UInt8]  // RGBA
}

// DO: Use type sugar for readability
let buffer: [1024 of Float] = .init(repeating: 0)

// DO: Access via indices when iterating
for i in buffer.indices {
    process(buffer[i])
}

// DON'T: Use for variable-size data
// DON'T: Expect Sequence/Collection conformance
// DON'T: Create very large inline arrays (stack overflow risk)
```

### Span

```swift
// DO: Use for read-only access to existing data
func process(_ data: borrowing Span<Int>) -> Int {
    data.reduce(0, +)
}

// DO: Use RawSpan for binary parsing
func decode(_ bytes: RawSpan) throws -> Message { ... }

// DON'T: Try to store spans beyond their scope
// DON'T: Try to capture spans in closures
// DON'T: Modify the original container while using its span
```

---

## Migration Guide

### From C Arrays (Tuples)

```swift
// Before: C array imported as tuple
var cStyle: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
cStyle.0 = 1
cStyle.1 = 2

// After: Use InlineArray
var modern: [4 of UInt8] = [0, 0, 0, 0]
modern[0] = 1
modern[1] = 2
```

### From UnsafeBufferPointer

```swift
// Before: Unsafe
array.withUnsafeBufferPointer { ptr in
    for i in 0..<ptr.count {
        process(ptr[i])
    }
}

// After: Safe with Span
let span = array.span
for i in span.indices {
    process(span[i])
}
```

---

## Platform Availability

- **Minimum Deployment**: iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26
- **Swift Version**: 6.2+
- **Xcode Version**: Xcode 26+

---

## References

### Official Documentation
- [Apple Developer: Span](https://developer.apple.com/documentation/swift/span)
- [Apple Developer: InlineArray](https://developer.apple.com/documentation/swift/inlinearray)

### Swift Evolution Proposals
- [SE-0447: Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [SE-0452: Integer Generic Parameters](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md)
- [SE-0453: InlineArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md)
- [SE-0483: InlineArray Type Sugar](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0483-inline-array-sugar.md)

### Community Resources
- [Swift Forums: SE-0453 Acceptance](https://forums.swift.org/t/accepted-with-modifications-se-0453-inlinearray-formerly-vector-a-fixed-size-array/77678)
- [Swift Forums: SE-0447 Acceptance](https://forums.swift.org/t/accepted-se-0447-span-safe-access-to-contiguous-storage/75508)
- [Hacking with Swift: What's New in Swift 6.2](https://www.hackingwithswift.com/articles/277/whats-new-in-swift-6-2)
