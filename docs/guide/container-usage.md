# Container Usage

WeaveDI's Container collects modules and then registers them in parallel at once to minimize Actor hops.

## Overview
- `Module` is the minimum unit of registration work.
- Collect modules with `Container.register(_:)` and register in parallel with `build()`.

## Basic Usage
```swift
let repoModule = Module(RepositoryProtocol.self) { DefaultRepository() }
let useCaseModule = Module(UseCaseProtocol.self) { DefaultUseCase(repo: DefaultRepository()) }

let container = Container()
container.register(repoModule)
container.register(useCaseModule)

await container.build()
```

## Usage with Factories
```swift
let container = Container()
let repositoryFactory = RepositoryModuleFactory()
let useCaseFactory = UseCaseModuleFactory()

await repositoryFactory.makeAllModules().asyncForEach { await container.register($0) }
await useCaseFactory.makeAllModules().asyncForEach { await container.register($0) }
await container.build()
```

## Conditional/Chaining Examples
```swift
let container = Container()
#if DEBUG
container.register(debugModule)
#else
container.register(prodModule)
#endif
await container.build()
```