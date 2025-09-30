# Quick Start Guide

Get up and running with WeaveDI in 5 minutes - From zero to production-ready dependency injection.

## Installation

### Swift Package Manager

Add WeaveDI to your project's Package.swift file. This configuration tells Swift Package Manager to download WeaveDI version 3.1.0 or later from the GitHub repository:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

**What this does:**
- Downloads the WeaveDI framework from the official repository
- Ensures you get version 3.1.0 or newer (with latest features and bug fixes)
- Integrates seamlessly with your Swift project's build system

**Performance Impact:**
- Zero runtime overhead for package inclusion
- Compile-time dependency resolution
- Optimized binary size with Swift Package Manager's dead code elimination

**Version Selection Strategy:**
```swift
// For stable production apps
.package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")

// For cutting-edge features (use with caution)
.package(url: "https://github.com/Roy-wonji/WeaveDI.git", .branch("main"))

// For specific version requirements
.package(url: "https://github.com/Roy-wonji/WeaveDI.git", exact: "3.1.2")
```

### Xcode Installation

For visual project management:

1. **File → Add Package Dependencies**
2. **Enter:** `https://github.com/Roy-wonji/WeaveDI.git`
3. **Select version:** Choose "Up to Next Major" for 3.1.0
4. **Add Package**

**Xcode Integration Benefits:**
- Automatic dependency updates through Xcode interface
- Visual package management
- Integrated documentation and code completion
- Built-in conflict resolution

**Troubleshooting Installation Issues:**
```swift
// If you encounter build errors, try:
// 1. Clean Build Folder (Cmd+Shift+K)
// 2. Reset Package Caches
// File → Packages → Reset Package Caches

// 3. Verify minimum deployment targets
// iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
```

## Basic Usage

### 1. Import

First, import WeaveDI into your Swift files where you need dependency injection. This gives you access to all WeaveDI features including property wrappers, registration APIs, and container management:

```swift
import WeaveDI
```

**What this enables:**
- Access to `@Inject`, `@Factory`, and `@SafeInject` property wrappers
- UnifiedDI registration and resolution APIs
- WeaveDI.Container bootstrap functionality
- All WeaveDI utility classes and protocols
- Auto DI Optimizer features for performance monitoring

**Import Best Practices:**
```swift
// ✅ Import in service files
import WeaveDI
import Foundation  // Always pair with Foundation for core functionality

// ✅ For SwiftUI apps
import WeaveDI
import SwiftUI

// ✅ For complex apps, consider creating a dedicated DI setup file
// File: DependencySetup.swift
import WeaveDI
import Foundation

// This file becomes your central DI configuration hub
```

**Module Organization Strategy:**
```swift
// Core App Module
// File: App+DI.swift
import WeaveDI

extension App {
    static func setupDependencies() {
        // All app-wide dependencies configured here
    }
}

// Feature-specific modules
// File: UserFeature+DI.swift
import WeaveDI

extension UserFeature {
    static func setupUserDependencies() {
        // User-related dependencies only
    }
}
```

### 2. Define Services

Create protocols (interfaces) and implementations for your services. This follows the dependency inversion principle - depend on abstractions, not concrete implementations:

```swift
// Define the service contract (what functionality is available)
protocol UserService {
    func fetchUser(id: String) async throws -> User?
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

// Implement the actual service logic
class UserServiceImpl: UserService {
    private let networkClient: NetworkClient
    private let database: Database
    private let cache: CacheService

    // Dependencies injected through constructor
    init(
        networkClient: NetworkClient = UnifiedDI.requireResolve(NetworkClient.self),
        database: Database = UnifiedDI.requireResolve(Database.self),
        cache: CacheService = UnifiedDI.resolve(CacheService.self, default: MemoryCache())
    ) {
        self.networkClient = networkClient
        self.database = database
        self.cache = cache
    }

    func fetchUser(id: String) async throws -> User? {
        // 1. Check cache first (performance optimization)
        if let cachedUser = cache.getUser(id: id) {
            print("✅ User found in cache: \(id)")
            return cachedUser
        }

        // 2. Try local database
        if let dbUser = try await database.fetchUser(id: id) {
            print("✅ User found in database: \(id)")
            cache.setUser(dbUser) // Cache for future requests
            return dbUser
        }

        // 3. Fetch from remote API as last resort
        print("⚠️ Fetching user from network: \(id)")
        let networkUser = try await networkClient.fetchUser(id: id)

        if let user = networkUser {
            // Save to database and cache
            try await database.saveUser(user)
            cache.setUser(user)
            print("✅ User cached from network: \(id)")
        }

        return networkUser
    }

    func updateUser(_ user: User) async throws -> User {
        // Update in all layers
        let updatedUser = try await networkClient.updateUser(user)
        try await database.saveUser(updatedUser)
        cache.setUser(updatedUser)

        print("✅ User updated across all layers: \(user.id)")
        return updatedUser
    }

    func deleteUser(id: String) async throws {
        // Remove from all layers
        try await networkClient.deleteUser(id: id)
        try await database.deleteUser(id: id)
        cache.removeUser(id: id)

        print("✅ User deleted from all layers: \(id)")
    }
}
```

**Why use protocols?**
- **Testability**: Easy to create mock implementations for testing
- **Flexibility**: Can swap implementations without changing dependent code
- **Maintainability**: Clear separation between interface and implementation
- **Best Practice**: Follows SOLID principles for clean architecture

**Advanced Protocol Design Patterns:**
```swift
// ✅ Protocol with associated types for generic operations
protocol Repository {
    associatedtype Entity
    associatedtype ID

    func find(by id: ID) async throws -> Entity?
    func save(_ entity: Entity) async throws -> Entity
    func delete(by id: ID) async throws
}

// ✅ Protocol composition for complex services
protocol UserService: UserReader, UserWriter, UserValidator {
    // Combines multiple focused protocols
}

protocol UserReader {
    func fetchUser(id: String) async throws -> User?
    func searchUsers(query: String) async throws -> [User]
}

protocol UserWriter {
    func createUser(_ user: User) async throws -> User
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

protocol UserValidator {
    func validateUser(_ user: User) throws
    func validateEmail(_ email: String) -> Bool
}

// ✅ Protocol with default implementations
extension UserValidator {
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    func validateUser(_ user: User) throws {
        guard !user.name.isEmpty else {
            throw ValidationError.emptyName
        }

        guard validateEmail(user.email) else {
            throw ValidationError.invalidEmail(user.email)
        }
    }
}

enum ValidationError: LocalizedError {
    case emptyName
    case invalidEmail(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "User name cannot be empty"
        case .invalidEmail(let email):
            return "Invalid email format: \(email)"
        }
    }
}
```

**Real-World Service Architecture Example:**
```swift
// Multi-layer service with comprehensive error handling
class ProductionUserService: UserService {
    private let repository: UserRepository
    private let validator: UserValidator
    private let eventPublisher: EventPublisher
    private let logger: Logger

    init(
        repository: UserRepository = UnifiedDI.requireResolve(UserRepository.self),
        validator: UserValidator = UnifiedDI.requireResolve(UserValidator.self),
        eventPublisher: EventPublisher = UnifiedDI.requireResolve(EventPublisher.self),
        logger: Logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
    ) {
        self.repository = repository
        self.validator = validator
        self.eventPublisher = eventPublisher
        self.logger = logger
    }

    func fetchUser(id: String) async throws -> User? {
        logger.debug("Fetching user: \(id)")

        do {
            let user = try await repository.find(by: id)

            if let user = user {
                await eventPublisher.publish(UserEvent.fetched(user))
                logger.info("Successfully fetched user: \(id)")
            } else {
                logger.warning("User not found: \(id)")
            }

            return user

        } catch {
            logger.error("Failed to fetch user \(id): \(error)")
            throw UserServiceError.fetchFailed(id: id, underlyingError: error)
        }
    }

    func updateUser(_ user: User) async throws -> User {
        logger.debug("Updating user: \(user.id)")

        // Validate before update
        try validator.validateUser(user)

        do {
            let updatedUser = try await repository.save(user)
            await eventPublisher.publish(UserEvent.updated(updatedUser))
            logger.info("Successfully updated user: \(user.id)")
            return updatedUser

        } catch {
            logger.error("Failed to update user \(user.id): \(error)")
            throw UserServiceError.updateFailed(user: user, underlyingError: error)
        }
    }
}

enum UserServiceError: LocalizedError {
    case fetchFailed(id: String, underlyingError: Error)
    case updateFailed(user: User, underlyingError: Error)
    case deleteFailed(id: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let id, let error):
            return "Failed to fetch user '\(id)': \(error.localizedDescription)"
        case .updateFailed(let user, let error):
            return "Failed to update user '\(user.id)': \(error.localizedDescription)"
        case .deleteFailed(let id, let error):
            return "Failed to delete user '\(id)': \(error.localizedDescription)"
        }
    }
}
```

### 3. Register Dependencies

Register your service implementations with WeaveDI's dependency injection container. This tells WeaveDI how to create instances when they're requested. Do this during app startup, typically in your App delegate or SwiftUI App struct:

```swift
// Register at app startup - this creates the binding between protocol and implementation
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()  // Factory closure that creates the actual implementation
}
```

**How registration works:**
- **Type Registration**: Maps the `UserService` protocol to `UserServiceImpl` class
- **Factory Closure**: The `{ UserServiceImpl() }` closure defines how to create instances
- **Lazy Creation**: Instances are only created when first requested (lazy loading)
- **Singleton by Default**: The same instance is reused across the app unless configured otherwise
- **Return Value**: Returns the created instance for immediate use if needed

**Advanced Registration Patterns:**

```swift
// ✅ Registration with dependencies
let networkService = UnifiedDI.register(NetworkService.self) {
    URLSessionNetworkService(
        session: URLSession.shared,
        decoder: JSONDecoder(),
        timeout: 30.0
    )
}

// ✅ Conditional registration based on environment
let apiService = UnifiedDI.register(APIService.self) {
    #if DEBUG
    return MockAPIService(delay: 1.0)  // Simulated delays for testing
    #elseif STAGING
    return StagingAPIService(baseURL: "https://staging-api.example.com")
    #else
    return ProductionAPIService(baseURL: "https://api.example.com")
    #endif
}

// ✅ Registration with configuration
let databaseService = UnifiedDI.register(DatabaseService.self) {
    let config = DatabaseConfiguration(
        filename: "app_database.sqlite",
        migrations: DatabaseMigrations.all,
        enableLogging: BuildConfig.isDevelopment
    )
    return SQLiteDatabaseService(configuration: config)
}

// ✅ Registration with async initialization (careful with this pattern)
let authenticatedAPIService = UnifiedDI.register(AuthenticatedAPIService.self) {
    // Note: This creates the service immediately, but authentication happens later
    let service = AuthenticatedAPIService()

    // Schedule authentication for next run loop
    Task {
        try await service.authenticate()
    }

    return service
}
```

**Registration Performance Optimization:**
```swift
// ✅ Batch registration for better performance
func registerCoreServices() {
    // Group related registrations together
    let logger = UnifiedDI.register(Logger.self) {
        OSLogLogger(category: "MyApp")
    }

    let config = UnifiedDI.register(ConfigService.self) {
        ConfigServiceImpl(logger: logger)
    }

    let network = UnifiedDI.register(NetworkService.self) {
        NetworkServiceImpl(config: config, logger: logger)
    }

    let database = UnifiedDI.register(DatabaseService.self) {
        DatabaseServiceImpl(config: config, logger: logger)
    }

    // Services that depend on infrastructure
    _ = UnifiedDI.register(UserService.self) {
        UserServiceImpl(network: network, database: database, logger: logger)
    }

    print("✅ Core services registered successfully")
}

// ✅ Performance monitoring during registration
func registerServicesWithMonitoring() {
    let startTime = CFAbsoluteTimeGetCurrent()

    registerCoreServices()

    let duration = CFAbsoluteTimeGetCurrent() - startTime
    print("⚡ Service registration completed in \(String(format: "%.2f", duration * 1000))ms")

    // Optional: Monitor memory usage
    let memoryUsage = getMemoryUsage()
    print("📊 Memory usage after registration: \(memoryUsage)MB")
}

func getMemoryUsage() -> Float {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if kerr == KERN_SUCCESS {
        return Float(taskInfo.resident_size) / (1024 * 1024)
    } else {
        return 0
    }
}
```

**Registration Error Handling:**
```swift
// ✅ Safe registration with error recovery
func registerServicesWithErrorHandling() {
    do {
        // Critical services that must succeed
        let logger = UnifiedDI.register(Logger.self) {
            guard let logger = OSLogLogger(category: "MyApp") else {
                throw DIError.serviceCreationFailed("Logger")
            }
            return logger
        }

        // Services with fallbacks
        let analyticsService = UnifiedDI.register(AnalyticsService.self) {
            do {
                return try FirebaseAnalyticsService()
            } catch {
                print("⚠️ Firebase Analytics failed, using console analytics: \(error)")
                return ConsoleAnalyticsService()
            }
        }

        print("✅ Services registered with appropriate fallbacks")

    } catch {
        print("❌ Critical service registration failed: \(error)")
        // Handle fatal errors appropriately
        fatalError("Cannot continue without critical services")
    }
}

enum DIError: LocalizedError {
    case serviceCreationFailed(String)
    case dependencyMissing(String)
    case configurationInvalid(String)

    var errorDescription: String? {
        switch self {
        case .serviceCreationFailed(let service):
            return "Failed to create service: \(service)"
        case .dependencyMissing(let dependency):
            return "Required dependency missing: \(dependency)"
        case .configurationInvalid(let detail):
            return "Invalid configuration: \(detail)"
        }
    }
}
```

### 4. Use Property Wrappers

Now inject and use your registered services in any class using WeaveDI's property wrappers. The `@Inject` wrapper automatically resolves the dependency from the container:

```swift
class UserViewController: UIViewController {
    // @Inject automatically resolves UserService from the DI container
    // The '?' makes it optional - the app won't crash if service isn't registered
    @Inject var userService: UserService?

    // Additional injected dependencies
    @Inject var analyticsService: AnalyticsService?
    @Inject var validationService: ValidationService?

    private var currentUser: User?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentUser()
    }

    private func setupUI() {
        title = "User Profile"
        view.backgroundColor = .systemBackground

        // Track analytics for screen view
        analyticsService?.trackScreenView(name: "UserProfile")
    }

    func loadUser() async {
        // Always safely unwrap injected dependencies
        guard let service = userService else {
            showErrorAlert("UserService not available")
            print("❌ UserService not available - check DI registration")
            return
        }

        // Show loading indicator
        showLoadingIndicator(true)

        do {
            // Use the injected service to perform operations
            let user = try await service.fetchUser(id: "123")

            // Validate the user data if validation service is available
            if let validator = validationService {
                try validator.validateUser(user)
            }

            // Update UI with retrieved data on main thread
            await MainActor.run {
                self.currentUser = user
                self.updateUI(with: user)
                self.showLoadingIndicator(false)
                print("✅ User loaded: \(user?.name ?? "Unknown")")
            }

            // Track successful operation
            analyticsService?.trackEvent(name: "user_loaded", parameters: [
                "user_id": user?.id ?? "unknown",
                "load_time": CFAbsoluteTimeGetCurrent()
            ])

        } catch {
            // Handle errors gracefully
            await MainActor.run {
                self.showLoadingIndicator(false)
                self.showErrorAlert("Failed to load user: \(error.localizedDescription)")
            }

            // Track error for monitoring
            analyticsService?.trackError(error: error, context: [
                "operation": "load_user",
                "user_id": "123"
            ])

            print("❌ Failed to load user: \(error)")
        }
    }

    @IBAction func updateUserTapped() {
        Task {
            await updateCurrentUser()
        }
    }

    private func updateCurrentUser() async {
        guard let service = userService,
              let user = currentUser else {
            showErrorAlert("Unable to update user")
            return
        }

        showLoadingIndicator(true)

        do {
            let updatedUser = try await service.updateUser(user)

            await MainActor.run {
                self.currentUser = updatedUser
                self.updateUI(with: updatedUser)
                self.showLoadingIndicator(false)
                self.showSuccessMessage("User updated successfully")
            }

            analyticsService?.trackEvent(name: "user_updated", parameters: [
                "user_id": updatedUser.id
            ])

        } catch {
            await MainActor.run {
                self.showLoadingIndicator(false)
                self.showErrorAlert("Failed to update user: \(error.localizedDescription)")
            }

            analyticsService?.trackError(error: error, context: [
                "operation": "update_user",
                "user_id": user.id
            ])
        }
    }

    // UI Helper Methods
    private func updateUI(with user: User?) {
        // Update your UI elements here
        // e.g., nameLabel.text = user?.name
        // e.g., emailLabel.text = user?.email
    }

    private func showLoadingIndicator(_ show: Bool) {
        if show {
            // Show loading spinner
        } else {
            // Hide loading spinner
        }
    }

    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

**How @Inject works:**
- **Automatic Resolution**: WeaveDI automatically finds and injects the registered implementation
- **Optional Safety**: Returns `nil` if the service isn't registered (prevents crashes)
- **Lazy Loading**: The service is only resolved when first accessed
- **Thread Safe**: Safe to use across different threads and actors

**Advanced @Inject Usage Patterns:**
```swift
// ✅ Multiple related services
class OrderProcessingService {
    @Inject var paymentService: PaymentService?
    @Inject var inventoryService: InventoryService?
    @Inject var emailService: EmailService?
    @Inject var auditService: AuditService?

    func processOrder(_ order: Order) async throws {
        // All services available as optionals - handle gracefully
        guard let payment = paymentService,
              let inventory = inventoryService else {
            throw OrderError.requiredServicesUnavailable
        }

        // Optional services degrade gracefully
        let email = emailService
        let audit = auditService

        try await payment.processPayment(order.paymentInfo)
        try await inventory.reserveItems(order.items)

        // Optional operations
        await email?.sendOrderConfirmation(order)
        await audit?.logOrderProcessed(order)
    }
}

// ✅ Conditional service usage
class NotificationManager {
    @Inject var pushNotificationService: PushNotificationService?
    @Inject var emailNotificationService: EmailNotificationService?
    @Inject var smsNotificationService: SMSNotificationService?

    func sendNotification(_ notification: Notification) async {
        var deliveredVia: [String] = []

        // Try push notifications first (fastest)
        if let pushService = pushNotificationService {
            do {
                try await pushService.send(notification)
                deliveredVia.append("push")
            } catch {
                print("Push notification failed: \(error)")
            }
        }

        // Fallback to email
        if let emailService = emailNotificationService {
            do {
                try await emailService.send(notification)
                deliveredVia.append("email")
            } catch {
                print("Email notification failed: \(error)")
            }
        }

        // Last resort: SMS (if critical notification)
        if notification.isCritical, let smsService = smsNotificationService {
            do {
                try await smsService.send(notification)
                deliveredVia.append("sms")
            } catch {
                print("SMS notification failed: \(error)")
            }
        }

        print("✅ Notification delivered via: \(deliveredVia.joined(separator: ", "))")
    }
}
```

## Property Wrappers

### @Inject - Optional Dependencies

Use `@Inject` for most dependency injection scenarios. It provides safe, optional injection that won't crash your app if a dependency isn't registered:

```swift
class ViewController: UIViewController {
    // Standard dependency injection - safe and optional
    @Inject var userService: UserService?
    @Inject var analyticsService: AnalyticsService?
    @Inject var configService: ConfigService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Safe optional chaining - won't crash if service is nil
        userService?.fetchUser(id: "current") { [weak self] result in
            switch result {
            case .success(let user):
                DispatchQueue.main.async {
                    self?.displayUser(user)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showErrorMessage("Failed to load user: \(error.localizedDescription)")
                }
            }
        }

        // Alternative: Explicit nil checking for better error handling
        guard let service = userService else {
            showErrorMessage("User service unavailable")
            return
        }

        // Now we know the service is available
        Task {
            do {
                let user = try await service.fetchUser(id: "current")
                await MainActor.run {
                    displayUser(user)
                }
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to load user: \(error.localizedDescription)")
                }
            }
        }
    }

    private func displayUser(_ user: User?) {
        // Update UI with user data
    }

    private func showErrorMessage(_ message: String) {
        // Display error to user
    }
}
```

**When to use @Inject:**
- **Most scenarios**: Your primary choice for dependency injection
- **Optional dependencies**: Services that are nice-to-have but not critical
- **Safe injection**: When you want to prevent crashes from missing dependencies
- **Testing**: Easy to mock by not registering the real service

**@Inject Performance Characteristics:**
```swift
class PerformanceOptimizedViewController: UIViewController {
    // These are resolved lazily - no performance impact at initialization
    @Inject var heavyService: HeavyComputationService?
    @Inject var networkService: NetworkService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // First access triggers resolution (one-time cost)
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = heavyService // Resolution happens here
        let resolutionTime = CFAbsoluteTimeGetCurrent() - startTime

        print("Service resolution took: \(resolutionTime * 1000)ms")
        // Subsequent accesses are instant (cached)
        _ = heavyService // No resolution cost
    }

    func performNetworkOperation() async {
        // Resolution cost only paid when actually needed
        guard let network = networkService else {
            print("Network unavailable - graceful degradation")
            return
        }

        // Use the service
        do {
            let data = try await network.fetchData()
            processData(data)
        } catch {
            print("Network operation failed: \(error)")
        }
    }

    private func processData(_ data: Data) {
        // Process the received data
    }
}
```

### @Factory - New Instance Each Time

Use `@Factory` when you need fresh instances rather than shared singletons. Perfect for stateless operations or when you need isolated instances:

```swift
class DocumentProcessor {
    // @Factory creates a new PDFGenerator instance every time it's accessed
    // Each document gets its own generator to avoid state conflicts
    @Factory var pdfGenerator: PDFGenerator
    @Factory var imageProcessor: ImageProcessor
    @Factory var templateEngine: TemplateEngine

    func createDocument(content: String) async {
        // Each access to pdfGenerator returns a brand new instance
        let generator = pdfGenerator // New instance created here

        // Configure this specific generator
        generator.setContent(content)
        generator.setFormat(.A4)
        generator.setMargins(top: 20, bottom: 20, left: 15, right: 15)

        // Generate the PDF
        do {
            let pdfData = try await generator.generate()
            try await savePDF(pdfData, name: "document_\(UUID().uuidString)")
            print("✅ Document created successfully")
        } catch {
            print("❌ Document generation failed: \(error)")
        }
    }

    func createMultipleDocuments(contents: [String]) async {
        // Process documents concurrently, each with its own generator
        await withTaskGroup(of: Void.self) { group in
            for (index, content) in contents.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { return }

                    // Each task gets a completely new PDFGenerator
                    let generator = self.pdfGenerator // Fresh instance for each document

                    generator.setContent(content)
                    generator.setTemplate(.standard)

                    do {
                        let pdf = try await generator.generate()
                        try await self.savePDF(pdf, name: "batch_document_\(index)")
                        print("✅ Batch document \(index) created")
                    } catch {
                        print("❌ Batch document \(index) failed: \(error)")
                    }

                    // No need to reset or clean up - each generator is independent
                }
            }
        }
    }

    func createDocumentWithImages(content: String, images: [UIImage]) async {
        let generator = pdfGenerator
        let processor = imageProcessor

        // Process images independently
        var processedImages: [ProcessedImage] = []

        for image in images {
            // Each image gets its own processor instance
            let imageProc = imageProcessor  // New instance

            imageProc.setCompressionQuality(0.8)
            imageProc.setMaxSize(CGSize(width: 1200, height: 800))

            do {
                let processed = try await imageProc.process(image)
                processedImages.append(processed)
            } catch {
                print("⚠️ Image processing failed, skipping: \(error)")
            }
        }

        // Generate PDF with processed images
        generator.setContent(content)
        generator.setImages(processedImages)

        do {
            let pdfData = try await generator.generate()
            try await savePDF(pdfData, name: "document_with_images_\(UUID().uuidString)")
            print("✅ Document with \(processedImages.count) images created")
        } catch {
            print("❌ Document with images generation failed: \(error)")
        }
    }

    private func savePDF(_ data: Data, name: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(name).pdf")

        try data.write(to: fileURL)
        print("📄 PDF saved to: \(fileURL.path)")
    }
}
```

**When to use @Factory:**
- **Stateless operations**: PDF generation, image processing, data transformation
- **Concurrent processing**: Each thread/task needs its own instance
- **Avoiding shared state**: Prevent one operation from affecting another
- **Builder patterns**: Fresh builder for each construction
- **Short-lived objects**: Objects that don't need to persist

**@Factory Advanced Patterns:**
```swift
class ReportGenerationService {
    @Factory var reportBuilder: ReportBuilder
    @Factory var dataAnalyzer: DataAnalyzer
    @Factory var chartGenerator: ChartGenerator

    func generateMonthlyReport(data: [MonthlyData]) async -> Report? {
        // Each report gets its own set of fresh processors
        let builder = reportBuilder
        let analyzer = dataAnalyzer
        let chartGen = chartGenerator

        // Configure for monthly analysis
        analyzer.setAnalysisType(.monthly)
        analyzer.setDataPoints(data)

        // Generate analysis
        guard let analysis = try? await analyzer.performAnalysis() else {
            print("❌ Monthly analysis failed")
            return nil
        }

        // Generate charts
        chartGen.setTheme(.corporate)
        chartGen.setSize(.large)

        let charts = await withTaskGroup(of: ChartResult?.self, returning: [Chart].self) { group in
            // Generate multiple charts concurrently
            group.addTask { try? await chartGen.generateTrendChart(analysis.trends) }
            group.addTask { try? await chartGen.generatePieChart(analysis.distribution) }
            group.addTask { try? await chartGen.generateBarChart(analysis.comparisons) }

            var results: [Chart] = []
            for await result in group {
                if let chart = result?.chart {
                    results.append(chart)
                }
            }
            return results
        }

        // Build final report
        builder.setTitle("Monthly Report - \(Date().formatted(.dateTime.month(.wide).year()))")
        builder.setAnalysis(analysis)
        builder.setCharts(charts)
        builder.setMetadata(["generated_at": Date(), "data_points": data.count])

        return try? await builder.build()
    }
}

// Factory with complex initialization
class DatabaseConnectionFactory {
    @Factory var connectionPool: DatabaseConnectionPool

    func performBulkOperation(_ operations: [DatabaseOperation]) async {
        // Each bulk operation gets its own connection pool
        let pool = connectionPool

        // Configure for bulk operations
        pool.setMaxConnections(10)
        pool.setBatchSize(100)
        pool.setTimeout(30)

        do {
            try await pool.executeBulk(operations)
            print("✅ Bulk operation completed with \(operations.count) operations")
        } catch {
            print("❌ Bulk operation failed: \(error)")
        }

        // Pool is automatically cleaned up when it goes out of scope
        // No shared state between different bulk operations
    }
}
```

### @SafeInject - Error Handling

Use `@SafeInject` when you need explicit error handling for missing dependencies. This wrapper provides more control over dependency resolution failures:

```swift
class DataManager {
    // @SafeInject provides explicit error information when resolution fails
    @SafeInject var database: Database?
    @SafeInject var backupStorage: BackupStorage?
    @SafeInject var encryptionService: EncryptionService?

    private let logger = Logger(category: "DataManager")

    func save(_ data: Data) throws {
        // Check if dependency injection succeeded
        guard let db = database else {
            // Log the specific error for debugging
            logger.error("Database dependency not found - check your DI registration")

            // Throw a descriptive error for the caller
            throw DIError.dependencyNotFound(type: "Database")
        }

        do {
            // Encrypt data if encryption service is available
            let dataToSave: Data
            if let encryption = encryptionService {
                logger.debug("Encrypting data before save")
                dataToSave = try encryption.encrypt(data)
            } else {
                logger.warning("No encryption service available - saving data in plain text")
                dataToSave = data
            }

            // Save to primary database
            try db.save(dataToSave)
            logger.info("Data saved successfully to primary database")

            // Create backup if backup storage is available
            if let backup = backupStorage {
                Task {
                    do {
                        try await backup.save(dataToSave)
                        logger.info("Data backed up successfully")
                    } catch {
                        logger.error("Backup failed: \(error) - continuing with primary save")
                        // Don't fail the main operation due to backup issues
                    }
                }
            } else {
                logger.warning("No backup storage available - skipping backup")
            }

        } catch {
            logger.error("Database save failed: \(error)")
            throw DataManagerError.saveFailed(underlyingError: error)
        }
    }

    func safeSave(_ data: Data) async -> Result<Void, Error> {
        do {
            guard let db = database else {
                return .failure(DIError.dependencyNotFound(type: "Database"))
            }

            // Perform save operation
            try db.save(data)
            logger.info("Safe save completed successfully")
            return .success(())

        } catch {
            logger.error("Safe save failed: \(error)")
            return .failure(DataManagerError.saveFailed(underlyingError: error))
        }
    }

    func loadData(id: String) async throws -> Data {
        guard let db = database else {
            logger.error("Cannot load data - database dependency missing")
            throw DIError.dependencyNotFound(type: "Database")
        }

        do {
            let rawData = try await db.load(id: id)

            // Decrypt if encryption service is available
            if let encryption = encryptionService {
                logger.debug("Decrypting loaded data")
                return try encryption.decrypt(rawData)
            } else {
                logger.debug("No encryption service - returning raw data")
                return rawData
            }

        } catch {
            logger.error("Failed to load data for id \(id): \(error)")

            // Try backup storage as fallback
            if let backup = backupStorage {
                logger.info("Trying backup storage for id \(id)")
                do {
                    let backupData = try await backup.load(id: id)

                    // Decrypt backup data if needed
                    let finalData: Data
                    if let encryption = encryptionService {
                        finalData = try encryption.decrypt(backupData)
                    } else {
                        finalData = backupData
                    }

                    logger.info("Data recovered from backup for id \(id)")
                    return finalData

                } catch {
                    logger.error("Backup recovery also failed for id \(id): \(error)")
                }
            }

            throw DataManagerError.loadFailed(id: id, underlyingError: error)
        }
    }

    func healthCheck() -> DataManagerHealth {
        var health = DataManagerHealth()

        // Check each dependency
        if database != nil {
            health.databaseAvailable = true
            health.issues.append("✅ Database service available")
        } else {
            health.databaseAvailable = false
            health.issues.append("❌ Database service missing")
        }

        if backupStorage != nil {
            health.backupAvailable = true
            health.issues.append("✅ Backup storage available")
        } else {
            health.backupAvailable = false
            health.issues.append("⚠️ Backup storage missing (optional)")
        }

        if encryptionService != nil {
            health.encryptionAvailable = true
            health.issues.append("✅ Encryption service available")
        } else {
            health.encryptionAvailable = false
            health.issues.append("⚠️ Encryption service missing (optional)")
        }

        health.overallHealth = health.databaseAvailable ? .healthy : .critical

        logger.info("Health check completed: \(health.overallHealth)")
        return health
    }
}

// Custom error types for better error handling
enum DIError: LocalizedError {
    case dependencyNotFound(type: String)
    case dependencyInitializationFailed(type: String, reason: String)
    case circularDependency(types: [String])

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let type):
            return "Required dependency '\(type)' was not found. Please register it in your DI container."
        case .dependencyInitializationFailed(let type, let reason):
            return "Failed to initialize dependency '\(type)': \(reason)"
        case .circularDependency(let types):
            return "Circular dependency detected: \(types.joined(separator: " -> "))"
        }
    }
}

enum DataManagerError: LocalizedError {
    case saveFailed(underlyingError: Error)
    case loadFailed(id: String, underlyingError: Error)
    case encryptionFailed(reason: String)
    case backupFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .loadFailed(let id, let error):
            return "Failed to load data for '\(id)': \(error.localizedDescription)"
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .backupFailed(let reason):
            return "Backup operation failed: \(reason)"
        }
    }
}

struct DataManagerHealth {
    var databaseAvailable = false
    var backupAvailable = false
    var encryptionAvailable = false
    var overallHealth: HealthStatus = .unknown
    var issues: [String] = []
}

enum HealthStatus {
    case healthy
    case degraded  // Some optional services missing
    case critical  // Required services missing
    case unknown
}
```

**When to use @SafeInject:**
- **Critical dependencies**: Services that are absolutely required for operation
- **Error reporting**: When you need detailed error information about missing dependencies
- **Explicit failure handling**: When `nil` isn't descriptive enough
- **Production debugging**: To get better diagnostic information in logs
- **Health monitoring**: Services that need to report on their dependency status

## Advanced Features

### Runtime Optimization

WeaveDI includes built-in performance optimizations that can significantly improve dependency resolution speed in production apps:

```swift
// Enable automatic runtime optimization
// This should be called early in your app lifecycle, typically in AppDelegate or App.swift
UnifiedRegistry.shared.enableOptimization()

// The optimization system will:
// 1. Cache frequently resolved dependencies for faster access
// 2. Optimize dependency graphs for minimal resolution overhead
// 3. Use lazy loading strategies for better memory management
// 4. Monitor performance and auto-tune based on usage patterns

print("🚀 WeaveDI optimization enabled - expect better performance!")
```

**What optimization does:**
- **Hot Path Caching**: Frequently accessed dependencies are cached for instant resolution
- **Graph Optimization**: Dependency resolution paths are optimized for minimal overhead
- **Memory Management**: Automatic cleanup of unused dependencies under memory pressure
- **Performance Monitoring**: Real-time analysis of resolution patterns for continuous improvement

**When to enable:**
- **Production builds**: Always enable in release builds for best performance
- **Large applications**: Essential for apps with many dependencies
- **Performance-critical apps**: Games, real-time apps, or apps with strict performance requirements

**Advanced Optimization Configuration:**
```swift
// Configure optimization parameters
UnifiedRegistry.shared.configureOptimization(
    cacheSize: 100,              // Maximum number of cached instances
    cacheTTL: 300,               // Cache time-to-live in seconds
    optimizationThreshold: 10,   // Minimum usage count before optimization
    memoryPressureHandling: true // Enable automatic cleanup under memory pressure
)

// Monitor optimization effectiveness
let stats = UnifiedRegistry.shared.getOptimizationStats()
print("""
Optimization Statistics:
- Cache hit rate: \(stats.cacheHitRate)%
- Average resolution time: \(stats.averageResolutionTime)ms
- Memory savings: \(stats.memorySavings)MB
- Total optimized types: \(stats.optimizedTypeCount)
""")

// Real-time performance monitoring
UnifiedRegistry.shared.setPerformanceMonitoring(enabled: true) { event in
    switch event {
    case .slowResolution(let type, let time):
        print("⚠️ Slow resolution detected: \(type) took \(time)ms")
    case .memoryPressure(let severity):
        print("📊 Memory pressure: \(severity)")
    case .optimizationApplied(let type):
        print("⚡ Optimization applied to: \(type)")
    }
}
```

### Bootstrap Pattern

The bootstrap pattern is the recommended way to set up all your dependencies in one place. This ensures proper initialization order and makes dependency management more organized:

```swift
// Bootstrap all dependencies at app startup
// This is typically called in your App.swift or AppDelegate
await WeaveDI.Container.bootstrap { container in
    // Register services in logical order

    // 1. Core infrastructure services first
    container.register(LoggerProtocol.self) {
        OSLogLogger(category: "MyApp", level: .info)
    }

    container.register(ConfigService.self) {
        let config = ConfigServiceImpl()
        config.loadConfiguration()
        return config
    }

    // 2. Data layer services
    container.register(DatabaseService.self) {
        let dbConfig = DatabaseConfiguration(
            filename: "app_database.sqlite",
            version: 3,
            migrations: DatabaseMigrations.all
        )
        return SQLiteDatabaseService(configuration: dbConfig)
    }

    // 3. Network services
    container.register(NetworkService.self) {
        let session = URLSession(configuration: .default)
        return URLSessionNetworkService(session: session, timeout: 30.0)
    }

    container.register(APIClient.self) {
        let baseURL = URL(string: "https://api.example.com")!
        let networkService = container.resolve(NetworkService.self)!
        return APIClientImpl(baseURL: baseURL, networkService: networkService)
    }

    // 4. Business logic services (depend on infrastructure)
    container.register(UserService.self) {
        let database = container.resolve(DatabaseService.self)!
        let apiClient = container.resolve(APIClient.self)!
        let logger = container.resolve(LoggerProtocol.self)!

        return UserServiceImpl(
            database: database,
            apiClient: apiClient,
            logger: logger
        )
    }

    container.register(AuthenticationService.self) {
        let userService = container.resolve(UserService.self)!
        let apiClient = container.resolve(APIClient.self)!

        return AuthenticationServiceImpl(
            userService: userService,
            apiClient: apiClient
        )
    }

    // 5. Presentation layer services
    container.register(AnalyticsService.self) {
        #if DEBUG
        return ConsoleAnalyticsService()
        #else
        return FirebaseAnalyticsService()
        #endif
    }

    container.register(NavigationService.self) {
        NavigationServiceImpl()
    }

    print("✅ All dependencies registered successfully")
}

// Alternative: Environment-specific bootstrap
#if DEBUG
await WeaveDI.Container.bootstrap { container in
    // Use mock services for development
    container.register(UserService.self) { MockUserService() }
    container.register(NetworkService.self) { MockNetworkService() }
    container.register(DatabaseService.self) { InMemoryDatabase() }
}
#else
await WeaveDI.Container.bootstrap { container in
    // Use real services for production
    container.register(UserService.self) { UserServiceImpl() }
    container.register(NetworkService.self) { URLSessionNetworkService() }
    container.register(DatabaseService.self) { SQLiteDatabaseService() }
}
#endif
```

**Benefits of Bootstrap Pattern:**
- **Centralized Setup**: All dependency registration in one place
- **Proper Ordering**: Dependencies are registered in logical order
- **Environment Awareness**: Different setups for debug/release builds
- **Error Detection**: Easy to spot missing or incorrectly configured dependencies
- **Documentation**: Serves as a clear map of your app's dependencies

**Advanced Bootstrap Patterns:**
```swift
// Modular bootstrap with error handling
class AppBootstrapper {
    private var isBootstrapped = false
    private let logger = Logger(category: "Bootstrap")

    func bootstrap() async throws {
        guard !isBootstrapped else {
            logger.warning("Bootstrap already completed")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            try await bootstrapCore()
            try await bootstrapServices()
            try await bootstrapPresentationLayer()

            isBootstrapped = true

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Bootstrap completed in \(String(format: "%.2f", duration))s")

        } catch {
            logger.error("Bootstrap failed: \(error)")
            throw BootstrapError.initializationFailed(error)
        }
    }

    private func bootstrapCore() async throws {
        await WeaveDI.Container.bootstrap { container in
            // Core services that everything else depends on
            container.register(LoggerProtocol.self) {
                OSLogLogger(category: "MyApp")
            }

            container.register(ConfigService.self) {
                let config = ConfigServiceImpl()
                try! config.loadFromBundle("Config.plist")
                return config
            }
        }

        logger.info("✅ Core services bootstrapped")
    }

    private func bootstrapServices() async throws {
        let container = WeaveDI.Container.shared

        // Register data services
        container.register(DatabaseService.self) {
            try! SQLiteDatabaseService()
        }

        container.register(NetworkService.self) {
            URLSessionNetworkService()
        }

        // Register business logic
        container.register(UserService.self) {
            UserServiceImpl()
        }

        logger.info("✅ Business services bootstrapped")
    }

    private func bootstrapPresentationLayer() async throws {
        let container = WeaveDI.Container.shared

        container.register(NavigationService.self) {
            NavigationServiceImpl()
        }

        container.register(AnalyticsService.self) {
            FirebaseAnalyticsService()
        }

        logger.info("✅ Presentation layer bootstrapped")
    }
}

enum BootstrapError: LocalizedError {
    case initializationFailed(Error)
    case dependencyMissing(String)
    case configurationInvalid

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Bootstrap initialization failed: \(error.localizedDescription)"
        case .dependencyMissing(let dependency):
            return "Required dependency missing during bootstrap: \(dependency)"
        case .configurationInvalid:
            return "Invalid configuration detected during bootstrap"
        }
    }
}

// Usage in App.swift
@main
struct MyApp: App {
    @State private var isBootstrapped = false

    var body: some Scene {
        WindowGroup {
            if isBootstrapped {
                ContentView()
            } else {
                SplashView()
                    .task {
                        await performBootstrap()
                    }
            }
        }
    }

    private func performBootstrap() async {
        do {
            let bootstrapper = AppBootstrapper()
            try await bootstrapper.bootstrap()
            isBootstrapped = true
        } catch {
            print("Failed to bootstrap app: \(error)")
            // Handle bootstrap failure appropriately
        }
    }
}
```

## Performance Considerations

### Resolution Performance

```swift
// Measure dependency resolution performance
func measureResolutionPerformance() {
    let iterations = 1000
    var totalTime: CFAbsoluteTime = 0

    for _ in 0..<iterations {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = UnifiedDI.resolve(UserService.self)
        totalTime += CFAbsoluteTimeGetCurrent() - startTime
    }

    let averageTime = totalTime / Double(iterations) * 1000 // Convert to milliseconds
    print("Average resolution time: \(String(format: "%.4f", averageTime))ms")
}

// Optimize frequent resolutions with caching
class PerformanceOptimizedManager {
    // Cache frequently used services
    private lazy var userService: UserService? = UnifiedDI.resolve(UserService.self)
    private lazy var analyticsService: AnalyticsService? = UnifiedDI.resolve(AnalyticsService.self)

    func performFrequentOperation() {
        // Use cached services - no resolution overhead
        userService?.performOperation()
        analyticsService?.trackEvent("operation_performed")
    }
}
```

### Memory Management

```swift
// Monitor memory usage of injected services
class MemoryAwareService {
    @Inject var heavyService: HeavyService?

    deinit {
        print("MemoryAwareService deallocated")
    }

    func performOperationWithMemoryMonitoring() {
        let memoryBefore = getMemoryUsage()

        heavyService?.performHeavyOperation()

        let memoryAfter = getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore

        if memoryDelta > 10 { // More than 10MB increase
            print("⚠️ High memory usage detected: \(memoryDelta)MB")
        }
    }

    private func getMemoryUsage() -> Float {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Float(taskInfo.resident_size) / (1024 * 1024) : 0
    }
}
```

## Common Pitfalls and Troubleshooting

### 1. Circular Dependencies

```swift
// ❌ BAD: Circular dependency
class ServiceA {
    @Inject var serviceB: ServiceB?

    init() {
        serviceB?.doSomething()
    }
}

class ServiceB {
    @Inject var serviceA: ServiceA?  // Creates circular dependency

    func doSomething() {
        serviceA?.performAction()
    }
}

// ✅ GOOD: Break circular dependency with protocol
protocol ServiceAProtocol {
    func performAction()
}

protocol ServiceBProtocol {
    func doSomething()
}

class ServiceA: ServiceAProtocol {
    private let serviceB: ServiceBProtocol

    init(serviceB: ServiceBProtocol = UnifiedDI.requireResolve(ServiceBProtocol.self)) {
        self.serviceB = serviceB
    }

    func performAction() {
        // Implementation
    }
}

class ServiceB: ServiceBProtocol {
    func doSomething() {
        // Use event-driven communication instead of direct reference
        NotificationCenter.default.post(name: .serviceBAction, object: nil)
    }
}
```

### 2. Missing Dependencies at Runtime

```swift
// ✅ GOOD: Defensive programming with dependency checking
class RobustService {
    @SafeInject var criticalService: CriticalService?
    @Inject var optionalService: OptionalService?

    func performCriticalOperation() throws {
        guard let critical = criticalService else {
            throw ServiceError.criticalDependencyMissing("CriticalService not registered")
        }

        try critical.performCriticalTask()

        // Optional service used with fallback
        if let optional = optionalService {
            optional.performOptionalTask()
        } else {
            performFallbackTask()
        }
    }

    private func performFallbackTask() {
        print("Using fallback implementation for optional service")
    }
}

enum ServiceError: LocalizedError {
    case criticalDependencyMissing(String)

    var errorDescription: String? {
        switch self {
        case .criticalDependencyMissing(let service):
            return "Critical dependency missing: \(service)"
        }
    }
}
```

### 3. Thread Safety Issues

```swift
// ✅ GOOD: Thread-safe service usage
class ThreadSafeService {
    @Inject var networkService: NetworkService?
    private let queue = DispatchQueue(label: "service.queue", qos: .utility)

    func performConcurrentOperations() async {
        // Services are thread-safe for resolution, but usage may need synchronization
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { [weak self] in
                    await self?.performNetworkOperation(id: i)
                }
            }
        }
    }

    private func performNetworkOperation(id: Int) async {
        guard let network = networkService else {
            print("Network service not available for operation \(id)")
            return
        }

        do {
            let result = try await network.fetchData(id: "operation_\(id)")
            print("Operation \(id) completed: \(result)")
        } catch {
            print("Operation \(id) failed: \(error)")
        }
    }
}
```

### 4. Testing Best Practices

```swift
// ✅ GOOD: Testable service design
class TestableUserService {
    private let repository: UserRepository
    private let validator: UserValidator

    // Dependency injection through initializer for easy testing
    init(
        repository: UserRepository = UnifiedDI.requireResolve(UserRepository.self),
        validator: UserValidator = UnifiedDI.requireResolve(UserValidator.self)
    ) {
        self.repository = repository
        self.validator = validator
    }

    func createUser(_ userData: UserData) async throws -> User {
        try validator.validate(userData)
        return try await repository.create(from: userData)
    }
}

// Test implementation
class UserServiceTests: XCTestCase {
    func testCreateUser() async throws {
        // Arrange
        let mockRepository = MockUserRepository()
        let mockValidator = MockUserValidator()

        let service = TestableUserService(
            repository: mockRepository,
            validator: mockValidator
        )

        let userData = UserData(name: "Test User", email: "test@example.com")

        // Act
        let user = try await service.createUser(userData)

        // Assert
        XCTAssertEqual(user.name, "Test User")
        XCTAssertTrue(mockValidator.validateCalled)
        XCTAssertTrue(mockRepository.createCalled)
    }
}
```

## Next Steps

- [Property Wrappers](/guide/propertyWrappers) - Detailed injection patterns and advanced usage
- [Core APIs](/api/coreApis) - Complete API reference with examples
- [Runtime Optimization](/guide/runtimeOptimization) - Performance tuning and monitoring
- [Module System](/guide/moduleSystem) - Organizing large-scale applications
- [Testing Strategies](/guide/testing) - Comprehensive testing approaches for DI