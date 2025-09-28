# DependencyKey Patterns

Organize DependencyKey patterns for safe dependency resolution.

## Safe Pattern Examples
```swift
// Pre-registration at app startup + safe resolution
extension BookListUseCaseImpl: DependencyKey {
  public static var liveValue: BookListInterface = {
    guard let repo = WeaveDI.Container.live.resolve(BookListInterface.self) else {
      return DefaultBookListRepositoryImpl()
    }
    return BookListUseCaseImpl(repository: repo)
  }()
}
```

## Factory Lazy Initialization
```swift
extension BookListUseCaseImpl: DependencyKey {
  public static var liveValue: BookListInterface = BookListUseCaseFactory.create()
}

enum BookListUseCaseFactory {
  static func create() -> BookListInterface {
    @Inject(\.bookListInterface) var repo: BookListInterface?
    return repo ?? DefaultBookListRepositoryImpl()
  }
}
```

## Async Registration Example
```swift
Task {
  await WeaveDI.Container.bootstrapAsync { c in
    c.register(BookListInterface.self) { BookListRepositoryImpl() }
  }
}
```

---

📖 **Documentation**: [한국어](../ko.lproj/DependencyKeyPatterns) | [English](DependencyKeyPatterns)
