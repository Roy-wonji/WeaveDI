# Bulk Registration & DSL

Configure dependencies concisely using bulk registration and DSL.

## Interface Pattern Batch Registration
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