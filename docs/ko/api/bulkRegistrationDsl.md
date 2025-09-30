---
title: BulkRegistrationDSL
lang: ko-KR
---

# Bulk Registration & DSL

대량 등록과 DSL을 사용하여 간결하게 의존성을 구성할 수 있습니다.

## 인터페이스 패턴 한번에 등록
```swift
let entries = registerModule.registerInterfacePattern(
  BookListInterface.self,
  repositoryFactory: { BookListRepositoryImpl() },
  useCaseFactory: { BookListUseCaseImpl(repository: $0) },
  repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

## Bulk DSL
```swift
let modules = registerModule.bulkInterfaces {
  BookListInterface.self => (
    repository: { BookListRepositoryImpl() },
    useCase: { BookListUseCaseImpl(repository: $0) },
    fallback: { DefaultBookListRepositoryImpl() }
  )
}
```

## Easy Scope
```swift
let modules = registerModule.easyScopes {
  register(UserService.self) { UserServiceImpl() }
  register(NetworkService.self) { NetworkServiceImpl() }
}
```
