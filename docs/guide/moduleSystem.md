# Module System

Learn how to systematically manage dependencies in large-scale applications using WeaveDI 2.0's module system.

## Overview

The module system is a core feature of WeaveDI that allows you to logically group and systematically manage related dependencies. By organizing each layer of Clean Architecture as modules, you can significantly improve maintainability and scalability.

## Basic Module Structure

### Module Protocol

All modules must implement the `Module` protocol:

```swift
protocol Module {
    func registerDependencies() async
}
```

### Basic Module Implementation

```swift
struct UserModule: Module {
    func registerDependencies() async {
        // Repository Layer
        DI.register(UserRepository.self) {
            CoreDataUserRepository()
        }

        // UseCase Layer
        DI.register(UserUseCase.self) {
            UserUseCaseImpl()
        }

        // Service Layer
        DI.register(UserService.self) {
            UserServiceImpl()
        }
    }
}
```

## Module Management through AppDIContainer

### Repository Module Factory

Systematically manages Repository layer modules:

```swift
extension RepositoryModuleFactory {
    public mutating func registerDefaultDefinitions() {
        let registerModuleCopy = registerModule

        repositoryDefinitions = [
            // User Repository
            registerModuleCopy.makeDependency(UserRepositoryProtocol.self) {
                CoreDataUserRepository()
            },

            // Auth Repository
            registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
                KeychainAuthRepository()
            },

            // Network Repository
            registerModuleCopy.makeDependency(NetworkRepositoryProtocol.self) {
                URLSessionNetworkRepository()
            },

            // Cache Repository
            registerModuleCopy.makeDependency(CacheRepositoryProtocol.self) {
                UserDefaultsCacheRepository()
            }
        ]
    }
}
```

### UseCase Module Factory

UseCase layer automatically connects with Repository:

```swift
extension UseCaseModuleFactory {
    public var useCaseDefinitions: [() -> Module] {
        [
            // User UseCase - Repository auto injection
            registerModule.makeUseCaseWithRepository(
                UserUseCaseProtocol.self,
                repositoryProtocol: UserRepositoryProtocol.self,
                repositoryFallback: CoreDataUserRepository()
            ) { repository in
                UserUseCaseImpl(userRepository: repository)
            },

            // Auth UseCase - Repository auto injection
            registerModule.makeUseCaseWithRepository(
                AuthUseCaseProtocol.self,
                repositoryProtocol: AuthRepositoryProtocol.self,
                repositoryFallback: KeychainAuthRepository()
            ) { repository in
                AuthUseCaseImpl(authRepository: repository)
            },

            // Complex UseCase - Multiple Repository usage
            registerModule.makeComplexUseCase(
                UserProfileUseCaseProtocol.self
            ) {
                let userRepo = DI.resolve(UserRepositoryProtocol.self)
                let authRepo = DI.resolve(AuthRepositoryProtocol.self)
                return UserProfileUseCaseImpl(
                    userRepository: userRepo,
                    authRepository: authRepo
                )
            }
        ]
    }
}
```

### Complete Module Registration

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupModules()
        }
    }

    private func setupModules() async {
        await AppDIContainer.shared.registerDependencies { container in
            // 1. Register Repository modules
            var repositoryFactory = AppDIContainer.shared.repositoryFactory
            repositoryFactory.registerDefaultDefinitions()

            await repositoryFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // 2. Register UseCase modules (Repository dependencies auto-resolved)
            let useCaseFactory = AppDIContainer.shared.useCaseFactory
            await useCaseFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // 3. Register Scope modules
            let scopeFactory = AppDIContainer.shared.scopeFactory
            await scopeFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
        }
    }
}
```

## Layer-based Module Configuration

### Repository Layer Module

Handles data access and external system integration:

```swift
struct DataModule: Module {
    func registerDependencies() async {
        // Core Data Stack
        DI.register(CoreDataStack.self) {
            CoreDataStack(modelName: "DataModel")
        }

        // Repository implementations
        DI.register(UserRepository.self) {
            CoreDataUserRepository()
        }

        DI.register(PostRepository.self) {
            CoreDataPostRepository()
        }

        // Network related
        DI.register(NetworkRepository.self) {
            URLSessionNetworkRepository()
        }

        DI.register(APIClient.self) {
            RESTAPIClient(baseURL: "https://api.example.com")
        }
    }
}
```

### UseCase Layer Module

Encapsulates business logic:

```swift
struct BusinessModule: Module {
    func registerDependencies() async {
        // User related UseCases
        DI.register(GetUserProfileUseCase.self) {
            GetUserProfileUseCaseImpl()
        }

        DI.register(UpdateUserProfileUseCase.self) {
            UpdateUserProfileUseCaseImpl()
        }

        // Post related UseCases
        DI.register(CreatePostUseCase.self) {
            CreatePostUseCaseImpl()
        }

        DI.register(GetPostListUseCase.self) {
            GetPostListUseCaseImpl()
        }

        // Complex business logic
        DI.register(UserPostCoordinator.self) {
            UserPostCoordinatorImpl()
        }
    }
}
```

### Service Layer Module

Handles application services and UI support:

```swift
struct ServiceModule: Module {
    func registerDependencies() async {
        // UI related services
        DI.register(NavigationService.self) {
            NavigationServiceImpl()
        }

        DI.register(AlertService.self) {
            AlertServiceImpl()
        }

        // System services
        DI.register(NotificationService.self) {
            UserNotificationService()
        }

        DI.register(AnalyticsService.self) {
            FirebaseAnalyticsService()
        }

        // Utility services
        DI.register(ValidationService.self) {
            ValidationServiceImpl()
        }

        DI.register(FormatterService.self) {
            FormatterServiceImpl()
        }
    }
}
```

## Environment-based Module Configuration

### Development/Test/Production Separation

```swift
protocol EnvironmentModule: Module {
    var environment: Environment { get }
}

struct DevelopmentModule: EnvironmentModule {
    let environment = Environment.development

    func registerDependencies() async {
        // Development Mock services
        DI.register(NetworkService.self) {
            MockNetworkService()
        }

        DI.register(AnalyticsService.self) {
            ConsoleAnalyticsService() // Console logging only
        }

        DI.register(DatabaseService.self) {
            InMemoryDatabaseService() // Memory DB
        }
    }
}

struct ProductionModule: EnvironmentModule {
    let environment = Environment.production

    func registerDependencies() async {
        // Production real services
        DI.register(NetworkService.self) {
            URLSessionNetworkService()
        }

        DI.register(AnalyticsService.self) {
            FirebaseAnalyticsService()
        }

        DI.register(DatabaseService.self) {
            CoreDataService()
        }
    }
}

// Environment-based module selection
struct EnvironmentModuleFactory {
    static func createModule() -> EnvironmentModule {
        #if DEBUG
        return DevelopmentModule()
        #elseif STAGING
        return StagingModule()
        #else
        return ProductionModule()
        #endif
    }
}
```

### Platform-specific Modules

```swift
struct iOSModule: Module {
    func registerDependencies() async {
        DI.register(HapticService.self) {
            UIImpactFeedbackService()
        }

        DI.register(PhotoService.self) {
            UIImagePickerService()
        }

        DI.register(BiometricService.self) {
            TouchIDService()
        }
    }
}

struct macOSModule: Module {
    func registerDependencies() async {
        DI.register(MenuService.self) {
            NSMenuService()
        }

        DI.register(WindowService.self) {
            NSWindowService()
        }

        DI.register(FileService.self) {
            NSOpenPanelService()
        }
    }
}

// Platform detection and module registration
struct PlatformModuleLoader {
    static func loadPlatformModules() async {
        let container = DependencyContainer.live

        #if os(iOS)
        await container.register(iOSModule())
        #elseif os(macOS)
        await container.register(macOSModule())
        #endif
    }
}
```

## Module Dependency Management

### Inter-module Dependencies

```swift
struct NetworkModule: Module {
    func registerDependencies() async {
        DI.register(HTTPClient.self) {
            URLSessionHTTPClient()
        }

        DI.register(JSONDecoder.self) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }
    }
}

struct APIModule: Module {
    // Depends on NetworkModule
    func registerDependencies() async {
        DI.register(UserAPI.self) {
            UserAPIImpl() // HTTPClient auto injection
        }

        DI.register(PostAPI.self) {
            PostAPIImpl() // HTTPClient auto injection
        }
    }
}

// Registration considering dependency order
await DependencyContainer.bootstrap { container in
    // Base modules first
    await container.register(NetworkModule())

    // Dependent modules later
    await container.register(APIModule())
}
```

## Best Practices

### 1. Single Responsibility Principle

```swift
// ✅ Good: Each module has clear responsibility
struct AuthModule: Module {
    func registerDependencies() async {
        // Register only auth-related dependencies
    }
}

struct NetworkModule: Module {
    func registerDependencies() async {
        // Register only network-related dependencies
    }
}

// ❌ Bad: Multiple concerns mixed
struct MixedModule: Module {
    func registerDependencies() async {
        // Auth, network, UI mixed together
    }
}
```

### 2. Dependency Direction Management

```swift
// ✅ Good dependency direction: Service → UseCase → Repository
struct LayeredArchitectureModules {
    static func register() async {
        await DependencyContainer.bootstrap { container in
            await container.register(RepositoryModule()) // Lower layer
            await container.register(UseCaseModule())    // Middle layer
            await container.register(ServiceModule())    // Upper layer
        }
    }
}
```

### 3. Environment Separation

```swift
struct EnvironmentAwareModule: Module {
    func registerDependencies() async {
        #if DEBUG
        DI.register(LoggerService.self) {
            ConsoleLogger(level: .debug)
        }
        #else
        DI.register(LoggerService.self) {
            FileLogger(level: .warning)
        }
        #endif
    }
}
```

## Next Steps

- [Core APIs](/api/coreApis)
- [Property Wrappers](/guide/propertyWrappers)
- [Auto DI Optimizer](/guide/autoDiOptimizer)
- [Module Factory](/guide/moduleFactory)
