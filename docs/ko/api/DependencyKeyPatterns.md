---
title: DependencyKeyPatterns
lang: ko-KR
---

# DependencyKey Patterns

의존성 해석을 안전하게 하기 위한 DependencyKey 패턴을 정리합니다.

## 안전한 패턴 예시
```swift
// 앱 시작 시 사전 등록 + 안전한 해석
extension BookListUseCaseImpl: DependencyKey {
  public static var liveValue: BookListInterface = {
    guard let repo = WeaveDI.Container.live.resolve(BookListInterface.self) else {
      return DefaultBookListRepositoryImpl()
    }
    return BookListUseCaseImpl(repository: repo)
  }()
}
```

## Factory 지연 초기화
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

## 비동기 등록 예시
```swift
Task {
  await WeaveDI.Container.bootstrapAsync { c in
    c.register(BookListInterface.self) { BookListRepositoryImpl() }
  }
}
```
