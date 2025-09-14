# Module Factory

팩토리로 모듈을 체계적으로 생성하고 Container에 등록합니다.

## 기본
```swift
let factory = RepositoryModuleFactory()
await factory.makeAllModules().asyncForEach { await container.register($0) }
await container.build()
```

## UseCase Factory 연동
```swift
let useCaseFactory = UseCaseModuleFactory()
await useCaseFactory.makeAllModules().asyncForEach { await container.register($0) }
```

