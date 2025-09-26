# Container Usage

WeaveDI의 Container는 모듈을 수집한 뒤 한 번에 병렬 등록하여 Actor hop을 최소화합니다.

## 개요
- `Module`은 등록 작업의 최소 단위입니다.
- `Container.register(_:)`로 모듈을 수집하고, `build()`에서 병렬 등록합니다.

## 기본 사용
```swift
let repoModule = Module(RepositoryProtocol.self) { DefaultRepository() }
let useCaseModule = Module(UseCaseProtocol.self) { DefaultUseCase(repo: DefaultRepository()) }

let container = Container()
container.register(repoModule)
container.register(useCaseModule)

await container.build()
```

## 팩토리와 함께 사용
```swift
let container = Container()
let repositoryFactory = RepositoryModuleFactory()
let useCaseFactory = UseCaseModuleFactory()

await repositoryFactory.makeAllModules().asyncForEach { await container.register($0) }
await useCaseFactory.makeAllModules().asyncForEach { await container.register($0) }
await container.build()
```

## 조건부/체이닝 예시
```swift
let container = Container()
#if DEBUG
container.register(debugModule)
#else
container.register(prodModule)
#endif
await container.build()
```

