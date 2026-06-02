# RealmSwift Guide for iOS Development

A comprehensive guide for using RealmSwift in iOS apps with SwiftUI and async/await patterns.

> **Maintenance status (verified 2026-06-02).** Realm Swift is a third-party SDK (originally Realm, then MongoDB). After MongoDB wound down Atlas Device Sync, the SDK moved to **community-maintained mode** — its docs and README now live on the `community/` branch of `realm/realm-swift`. The local on-device database (this guide) still works and ships in production apps, but it no longer receives active feature investment from MongoDB, and Atlas Device Sync (the cloud sync layer) is end-of-life. **For a brand-new Apple-only app, prefer SwiftData** (Apple-native, first-party — see the `swiftdata` skill). Reach for Realm when maintaining an existing Realm app, when you need cross-platform parity (Kotlin/.NET/Dart), or for features SwiftData lacks.

---

## Table of Contents

1. [Installation](#installation)
2. [Defining Models](#defining-models)
3. [Basic Configuration](#basic-configuration)
4. [CRUD Operations](#crud-operations)
5. [Queries and Filtering](#queries-and-filtering)
6. [SwiftUI Integration](#swiftui-integration)
7. [Async Operations](#async-operations)
8. [Observing Changes](#observing-changes)
9. [Schema Migrations](#schema-migrations)
10. [Threading and Thread Safety](#threading-and-thread-safety)
11. [Best Practices](#best-practices)

---

## Installation

Add RealmSwift via Swift Package Manager:

```
https://github.com/realm/realm-swift
```

Import in your Swift files:

```swift
import RealmSwift
```

---

## Defining Models

### Basic Model

Subclass `Object` and use `@Persisted` for all properties you want to store:

```swift
import RealmSwift

class Dog: Object {
    @Persisted var name: String
    @Persisted var age: Int
    @Persisted var breed: String
}
```

### Model with Primary Key

Use `@Persisted(primaryKey: true)` for unique identifiers:

```swift
class Person: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var age: Int
}
```

### Relationships

```swift
class Person: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var dogs: List<Dog>        // One-to-many
    @Persisted var spouse: Person?         // Optional one-to-one
}

class Dog: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var age: Int

    // Inverse relationship (backlink)
    @Persisted(originProperty: "dogs") var owners: LinkingObjects<Person>
}
```

### Supported Property Types

| Type | Usage |
|------|-------|
| `String` | Text data |
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | Integer numbers |
| `Float`, `Double` | Decimal numbers |
| `Bool` | Boolean values |
| `Date` | Date and time |
| `Data` | Binary data |
| `ObjectId` | Unique identifier (recommended for primary keys) |
| `UUID` | UUID values |
| `List<T>` | One-to-many relationship |
| `Map<String, T>` | Dictionary with String keys |
| `MutableSet<T>` | Unordered collection of unique values |
| `Optional<T>` / `T?` | Optional values |

---

## Basic Configuration

### Default Realm

```swift
let realm = try! Realm()
```

### Custom Configuration

```swift
let config = Realm.Configuration(
    schemaVersion: 1,
    migrationBlock: { migration, oldSchemaVersion in
        // Handle migrations
    }
)

Realm.Configuration.defaultConfiguration = config
let realm = try! Realm(configuration: config)
```

### In-Memory Realm (for testing)

```swift
let config = Realm.Configuration(inMemoryIdentifier: "TestRealm")
let realm = try! Realm(configuration: config)
```

### Encrypted Realm

```swift
var key = Data(count: 64)
_ = key.withUnsafeMutableBytes { bytes in
    SecRandomCopyBytes(kSecRandomDefault, 64, bytes.baseAddress!)
}

let config = Realm.Configuration(encryptionKey: key)
let realm = try! Realm(configuration: config)
```

---

## CRUD Operations

### Create

```swift
let realm = try! Realm()

// Simple add
try! realm.write {
    let dog = Dog()
    dog.name = "Max"
    dog.age = 3
    dog.breed = "Labrador"
    realm.add(dog)
}

// Create from dictionary
try! realm.write {
    realm.create(Person.self, value: [
        "_id": ObjectId.generate(),
        "name": "Alice",
        "age": 28
    ])
}

// Batch insert
try! realm.write {
    let dogs = [
        Dog(value: ["name": "Buddy", "age": 2, "breed": "Beagle"]),
        Dog(value: ["name": "Charlie", "age": 4, "breed": "Poodle"])
    ]
    realm.add(dogs)
}
```

### Read

```swift
let realm = try! Realm()

// Fetch all objects of a type
let allDogs = realm.objects(Dog.self)

// Fetch by primary key
if let person = realm.object(ofType: Person.self, forPrimaryKey: objectId) {
    print("Found: \(person.name)")
}

// Get first/last
let firstDog = realm.objects(Dog.self).first
let lastDog = realm.objects(Dog.self).last
```

### Update

```swift
let realm = try! Realm()

// Update existing object
if let dog = realm.objects(Dog.self).filter("name == %@", "Max").first {
    try! realm.write {
        dog.age += 1
        dog.breed = "Mixed Breed"
    }
}

// Upsert (update or insert) with primary key
try! realm.write {
    realm.create(Person.self, value: [
        "_id": existingId,
        "name": "Updated Name",
        "age": 31
    ], update: .modified)  // Only updates changed fields
}
```

### Delete

```swift
let realm = try! Realm()

// Delete single object
if let dog = realm.objects(Dog.self).filter("name == %@", "Max").first {
    try! realm.write {
        realm.delete(dog)
    }
}

// Delete filtered objects
let oldDogs = realm.objects(Dog.self).filter("age > 10")
try! realm.write {
    realm.delete(oldDogs)
}

// Delete all objects of a type
try! realm.write {
    realm.delete(realm.objects(Dog.self))
}

// Delete everything
try! realm.write {
    realm.deleteAll()
}
```

---

## Queries and Filtering

### Type-Safe Queries (preferred)

Realm's `where` API gives compile-checked, autocompleting predicates via key paths — prefer it over the string-based `filter` for new code:

```swift
let realm = try! Realm()

// Single condition
let youngDogs = realm.objects(Dog.self).where { $0.age < 3 }

// Compound conditions
let results = realm.objects(Dog.self).where {
    $0.age > 2 && $0.breed == "Beagle"
}

// String operators, collection counts, IN
let matches = realm.objects(Dog.self).where {
    $0.name.contains("max", options: .caseInsensitive)
}
let busyOwners = realm.objects(Person.self).where { $0.dogs.count > 2 }
let favorites = realm.objects(Dog.self).where { $0.name.in(["Rex", "Max", "Buddy"]) }
```

The string-based `filter("...")` API below still works and is needed for `@ObservedResults`/`NSPredicate` call sites, but `where` is the modern default.

### Basic Filtering

```swift
let realm = try! Realm()

// Simple filter
let youngDogs = realm.objects(Dog.self).filter("age < 3")
let labradors = realm.objects(Dog.self).filter("breed == %@", "Labrador")

// Multiple conditions
let results = realm.objects(Dog.self)
    .filter("age > 2 AND breed == %@", "Beagle")
```

### Sorting

```swift
let sortedDogs = realm.objects(Dog.self)
    .sorted(byKeyPath: "age", ascending: true)

// Multiple sort descriptors
let sorted = realm.objects(Dog.self)
    .sorted(by: [
        SortDescriptor(keyPath: "breed", ascending: true),
        SortDescriptor(keyPath: "age", ascending: false)
    ])
```

### Advanced Queries

```swift
// IN operator
let favorites = ["Rex", "Max", "Buddy"]
let favoriteDogs = realm.objects(Dog.self)
    .filter("name IN %@", favorites)

// CONTAINS (case-insensitive)
let searchResults = realm.objects(Dog.self)
    .filter("name CONTAINS[c] %@", "max")

// BEGINSWITH / ENDSWITH
let startsWithM = realm.objects(Dog.self)
    .filter("name BEGINSWITH %@", "M")

// Relationship queries
let peopleWithManyDogs = realm.objects(Person.self)
    .filter("dogs.@count > 2")

// Subquery
let peopleWithYoungDogs = realm.objects(Person.self)
    .filter("SUBQUERY(dogs, $dog, $dog.age < 3).@count > 0")
```

### Aggregate Operations

```swift
let dogs = realm.objects(Dog.self)

let count = dogs.count
let averageAge = dogs.average(ofProperty: "age") ?? 0
let maxAge = dogs.max(ofProperty: "age") ?? 0
let minAge = dogs.min(ofProperty: "age") ?? 0
let totalAge = dogs.sum(ofProperty: "age")
```

---

## SwiftUI Integration

### @ObservedResults

Automatically updates the view when Realm data changes:

```swift
import SwiftUI
import RealmSwift

struct TaskListView: View {
    @ObservedResults(Task.self) var tasks

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
            .onDelete(perform: $tasks.remove)
            .onMove(perform: $tasks.move)
        }
        .toolbar {
            Button("Add") {
                $tasks.append(Task())
            }
        }
    }
}
```

### @ObservedResults with Filtering and Sorting

```swift
struct FilteredTasksView: View {
    @ObservedResults(
        Task.self,
        filter: NSPredicate(format: "isComplete == false"),
        sortDescriptor: SortDescriptor(keyPath: "priority", ascending: false)
    ) var incompleteTasks

    var body: some View {
        List(incompleteTasks) { task in
            Text(task.title)
        }
    }
}
```

### @ObservedRealmObject

For observing and editing a single object:

```swift
struct TaskDetailView: View {
    @ObservedRealmObject var task: Task

    var body: some View {
        Form {
            TextField("Title", text: $task.title)
            Toggle("Complete", isOn: $task.isComplete)
            Stepper("Priority: \(task.priority)", value: $task.priority, in: 1...5)
        }
    }
}
```

### Environment Injection

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.realmConfiguration, Realm.Configuration(
                    schemaVersion: 1
                ))
        }
    }
}
```

---

## Async Operations

### Async Write

```swift
let realm = try! Realm()

// Simple async write
realm.writeAsync {
    let dog = Dog()
    dog.name = "Async Dog"
    dog.age = 3
    realm.add(dog)
} onComplete: { error in
    if let error = error {
        print("Failed: \(error)")
    } else {
        print("Success")
    }
}
```

### Async/Await Pattern

For use with Swift concurrency:

```swift
@MainActor
class DogManager {
    private var realm: Realm {
        try! Realm()
    }

    func addDog(name: String, age: Int) async throws {
        let realm = realm
        try await realm.asyncWrite {
            let dog = Dog()
            dog.name = name
            dog.age = age
            realm.add(dog)
        }
    }

    func fetchDogs() -> Results<Dog> {
        return realm.objects(Dog.self)
    }
}
```

---

## Observing Changes

### Object Observer

```swift
var token: NotificationToken?

func observeDog(_ dog: Dog) {
    token = dog.observe { change in
        switch change {
        case .change(let properties):
            for property in properties {
                print("\(property.name) changed to \(property.newValue ?? "nil")")
            }
        case .deleted:
            print("Object was deleted")
        case .error(let error):
            print("Error: \(error)")
        }
    }
}

// Always invalidate when done
deinit {
    token?.invalidate()
}
```

### Collection Observer

```swift
var collectionToken: NotificationToken?

func observeDogs() {
    let dogs = realm.objects(Dog.self)

    collectionToken = dogs.observe { changes in
        switch changes {
        case .initial(let collection):
            print("Initial count: \(collection.count)")

        case .update(let collection, let deletions, let insertions, let modifications):
            print("Updated - Deleted: \(deletions.count), Inserted: \(insertions.count), Modified: \(modifications.count)")

        case .error(let error):
            print("Error: \(error)")
        }
    }
}
```

---

## Schema Migrations

### Basic Migration

```swift
let config = Realm.Configuration(
    schemaVersion: 2,  // Increment when schema changes
    migrationBlock: { migration, oldSchemaVersion in

        // Migration from version 0 to 1: Add new property
        if oldSchemaVersion < 1 {
            migration.enumerateObjects(ofType: Dog.className()) { oldObject, newObject in
                newObject?["breed"] = "Unknown"
            }
        }

        // Migration from version 1 to 2: Rename property
        if oldSchemaVersion < 2 {
            migration.renameProperty(
                onType: Dog.className(),
                from: "name",
                to: "fullName"
            )
        }
    }
)

Realm.Configuration.defaultConfiguration = config
```

### Data Transformation

```swift
let config = Realm.Configuration(
    schemaVersion: 3,
    migrationBlock: { migration, oldSchemaVersion in
        if oldSchemaVersion < 3 {
            migration.enumerateObjects(ofType: Person.className()) { oldObject, newObject in
                // Combine firstName + lastName into fullName
                let firstName = oldObject?["firstName"] as? String ?? ""
                let lastName = oldObject?["lastName"] as? String ?? ""
                newObject?["fullName"] = "\(firstName) \(lastName)"
            }
        }
    }
)
```

### Delete and Recreate (Development Only)

```swift
let config = Realm.Configuration(
    schemaVersion: 1,
    deleteRealmIfMigrationNeeded: true  // WARNING: Deletes all data
)
```

---

## Threading and Thread Safety

### Key Rules

1. **Realm instances are thread-confined** - Create a new Realm instance on each thread
2. **Objects cannot cross threads** - Use primary keys or frozen objects
3. **Write transactions block the thread** - Use async writes for large operations

### Accessing Objects Across Threads

```swift
// WRONG - Don't pass live objects between threads
let dog = realm.objects(Dog.self).first!
DispatchQueue.global().async {
    print(dog.name)  // CRASH - accessing from wrong thread
}

// CORRECT - Use primary key
let dogId = dog._id
DispatchQueue.global().async {
    let realm = try! Realm()
    if let dog = realm.object(ofType: Dog.self, forPrimaryKey: dogId) {
        print(dog.name)
    }
}

// CORRECT - Use frozen object
let frozenDog = dog.freeze()
DispatchQueue.global().async {
    print(frozenDog.name)  // OK - frozen objects are thread-safe
}
```

### Frozen Objects

```swift
// Freeze a single object
let frozenDog = dog.freeze()

// Freeze a collection
let frozenDogs = realm.objects(Dog.self).freeze()

// Check if frozen
if dog.isFrozen {
    print("This object is frozen")
}

// Thaw to get live object (on appropriate thread)
if let thawedDog = frozenDog.thaw() {
    try! thawedDog.realm?.write {
        thawedDog.age += 1
    }
}
```

### Background Operations

```swift
// Perform heavy work on background thread
DispatchQueue.global(qos: .background).async {
    autoreleasepool {
        let realm = try! Realm()

        try! realm.write {
            for i in 0..<10000 {
                let dog = Dog()
                dog.name = "Dog \(i)"
                dog.age = i % 15
                realm.add(dog)
            }
        }
    }
}
```

---

## Best Practices

### 1. Use ObjectKeyIdentifiable for SwiftUI

```swift
class Task: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId
    // ...
}
```

### 2. Create a RealmManager

Centralize Realm access in a manager class:

```swift
import RealmSwift

@Observable
@MainActor
class RealmManager {
    private(set) var realm: Realm

    init() {
        let config = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // Handle migrations
            }
        )
        Realm.Configuration.defaultConfiguration = config
        self.realm = try! Realm(configuration: config)
    }

    func add<T: Object>(_ object: T) {
        try? realm.write {
            realm.add(object)
        }
    }

    func delete<T: Object>(_ object: T) {
        try? realm.write {
            realm.delete(object)
        }
    }
}
```

### 3. Always Use Write Transactions

```swift
// WRONG
dog.name = "New Name"  // Changes won't persist

// CORRECT
try! realm.write {
    dog.name = "New Name"
}
```

### 4. Invalidate Notification Tokens

```swift
class MyViewModel {
    private var token: NotificationToken?

    deinit {
        token?.invalidate()
    }
}
```

### 5. Use autoreleasepool for Batch Operations

```swift
DispatchQueue.global().async {
    autoreleasepool {
        let realm = try! Realm()
        // Heavy operations
    }
}
```

### 6. Prefer ObjectId for Primary Keys

```swift
// Recommended
@Persisted(primaryKey: true) var _id: ObjectId

// Also valid but less efficient for queries
@Persisted(primaryKey: true) var _id: String
```

### 7. Handle Realm Errors Gracefully

```swift
do {
    let realm = try Realm()
    try realm.write {
        realm.add(object)
    }
} catch let error as NSError {
    print("Realm error: \(error.localizedDescription)")
    // Handle error appropriately
}
```

### 8. Use Frozen Objects for Async Operations

```swift
func processDogsAsync() {
    let frozenDogs = realm.objects(Dog.self).freeze()

    Task.detached {
        for dog in frozenDogs {
            // Process safely on background thread
            print(dog.name)
        }
    }
}
```

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Accessing objects from wrong thread | Use frozen objects or fetch by primary key |
| Forgetting write transaction | Always wrap modifications in `realm.write {}` |
| Not invalidating tokens | Store tokens and invalidate in `deinit` |
| Using `try!` in production | Use proper error handling with `do-catch` |
| Passing live objects to SwiftUI | Use `@ObservedResults` or `@ObservedRealmObject` |
| Blocking main thread with large writes | Use `writeAsync` or background threads |

---

## Quick Reference

### Property Wrappers

| Wrapper | Usage |
|---------|-------|
| `@Persisted` | Mark property for Realm storage |
| `@Persisted(primaryKey: true)` | Primary key property |
| `@ObservedResults` | SwiftUI: Observe collection |
| `@ObservedRealmObject` | SwiftUI: Observe single object |

### Common Operations

```swift
// Get Realm
let realm = try! Realm()

// Add object
try! realm.write { realm.add(object) }

// Update object
try! realm.write { object.property = newValue }

// Delete object
try! realm.write { realm.delete(object) }

// Query objects
let results = realm.objects(MyObject.self).filter("condition")

// Fetch by primary key
let object = realm.object(ofType: MyObject.self, forPrimaryKey: id)
```
