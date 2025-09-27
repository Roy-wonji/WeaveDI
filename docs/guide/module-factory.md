# Module Factory

Systematically create modules using factories and register them in Container.

## Basic Usage
```swift
let factory = RepositoryModuleFactory()
await factory.makeAllModules().asyncForEach { await container.register($0) }
await container.build()
```

## UseCase Factory Integration
```swift
let useCaseFactory = UseCaseModuleFactory()
await useCaseFactory.makeAllModules().asyncForEach { await container.register($0) }
```