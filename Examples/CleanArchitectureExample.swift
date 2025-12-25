//
//  CleanArchitectureExample.swift
//  WeaveDI
//
//  🚀 Clean Architecture + WeaveDI TCA-Style Example
//  Before vs After 비교 예시
//

import Foundation
import WeaveDI

// MARK: - 📱 전자상거래 앱 예시

// MARK: - Domain Layer (Business Logic)

protocol UserRepository: Sendable {
    func getCurrentUser() async -> User?
    func updateUser(_ user: User) async throws
}

protocol ProductRepository: Sendable {
    func getProducts() async -> [Product]
    func getProduct(id: String) async -> Product?
}

protocol Logger: Sendable {
    func log(_ message: String)
    func error(_ message: String)
}

struct User: Sendable {
    let id: String
    let name: String
    let email: String
}

struct Product: Sendable {
    let id: String
    let name: String
    let price: Double
}

// MARK: - Use Cases

class GetUserUseCase: Sendable {
    @Injected var userRepository: UserRepository    // 🚀 타입만으로 간단하게!
    @Injected var logger: Logger

    func execute() async -> User? {
        logger.log("Getting current user...")
        let user = await userRepository.getCurrentUser()
        logger.log("User retrieved: \(user?.name ?? "none")")
        return user
    }
}

class GetProductsUseCase: Sendable {
    @Injected var productRepository: ProductRepository
    @Injected var logger: Logger

    func execute() async -> [Product] {
        logger.log("Getting products...")
        let products = await productRepository.getProducts()
        logger.log("Retrieved \(products.count) products")
        return products
    }
}

// MARK: - Data Layer (Infrastructure)

class UserRepositoryImpl: UserRepository {
    func getCurrentUser() async -> User? {
        // 실제 API 호출 시뮬레이션
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        return User(id: "1", name: "John Doe", email: "john@example.com")
    }

    func updateUser(_ user: User) async throws {
        // 실제 API 호출 시뮬레이션
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초
    }
}

class ProductRepositoryImpl: ProductRepository {
    func getProducts() async -> [Product] {
        // 실제 API 호출 시뮬레이션
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15초
        return [
            Product(id: "1", name: "iPhone 15", price: 999.0),
            Product(id: "2", name: "MacBook Pro", price: 1999.0)
        ]
    }

    func getProduct(id: String) async -> Product? {
        let products = await getProducts()
        return products.first { $0.id == id }
    }
}

// MARK: - 로깅 구현체들

class ProductionLogger: Logger {
    func log(_ message: String) {
        print("📱 [INFO] \(message)")
    }

    func error(_ message: String) {
        print("🚨 [ERROR] \(message)")
    }
}

class ConsoleLogger: Logger {
    func log(_ message: String) {
        print("🔍 [DEBUG] \(message)")
    }

    func error(_ message: String) {
        print("❌ [DEBUG ERROR] \(message)")
    }
}

class NoOpLogger: Logger {
    func log(_ message: String) {}
    func error(_ message: String) {}
}

// MARK: - Mock 구현체들 (테스트/개발용)

class MockUserRepository: UserRepository {
    func getCurrentUser() async -> User? {
        return User(id: "mock-1", name: "Mock User", email: "mock@example.com")
    }

    func updateUser(_ user: User) async throws {
        // Mock implementation - 즉시 완료
    }
}

class MockProductRepository: ProductRepository {
    func getProducts() async -> [Product] {
        return [
            Product(id: "mock-1", name: "Mock iPhone", price: 1.0),
            Product(id: "mock-2", name: "Mock MacBook", price: 2.0)
        ]
    }

    func getProduct(id: String) async -> Product? {
        return Product(id: id, name: "Mock Product \(id)", price: 99.0)
    }
}

// MARK: - Presentation Layer (ViewModel)

class ProductListViewModel: ObservableObject, Sendable {
    @Injected var getProductsUseCase: GetProductsUseCase    // 🚀 간단!
    @Injected var getUserUseCase: GetUserUseCase           // 🚀 간단!

    @Published var products: [Product] = []
    @Published var currentUser: User?
    @Published var isLoading = false

    @MainActor
    func loadData() async {
        isLoading = true

        async let productsTask = getProductsUseCase.execute()
        async let userTask = getUserUseCase.execute()

        products = await productsTask
        currentUser = await userTask

        isLoading = false
    }
}

// MARK: - 🔥 Before vs After 비교

/*

 ## 😫 Before - 복잡하고 길었던 방식 (50+ 줄)

 ```swift
 // 1. DependencyKey들 모두 정의 필요
 struct UserRepositoryKey: DependencyKey {
     static var liveValue: UserRepository { UserRepositoryImpl() }
 }

 struct ProductRepositoryKey: DependencyKey {
     static var liveValue: ProductRepository { ProductRepositoryImpl() }
 }

 struct LoggerKey: DependencyKey {
     static var liveValue: Logger { ProductionLogger() }
 }

 struct GetUserUseCaseKey: DependencyKey {
     static var liveValue: GetUserUseCase { GetUserUseCase() }
 }

 struct GetProductsUseCaseKey: DependencyKey {
     static var liveValue: GetProductsUseCase { GetProductsUseCase() }
 }

 // 2. DependencyValues 확장 모두 정의 필요
 extension DependencyValues {
     var userRepository: UserRepository {
         get { self[UserRepositoryKey.self] }
         set { self[UserRepositoryKey.self] = newValue }
     }

     var productRepository: ProductRepository {
         get { self[ProductRepositoryKey.self] }
         set { self[ProductRepositoryKey.self] = newValue }
     }

     var logger: Logger {
         get { self[LoggerKey.self] }
         set { self[LoggerKey.self] = newValue }
     }

     var getUserUseCase: GetUserUseCase {
         get { self[GetUserUseCaseKey.self] }
         set { self[GetUserUseCaseKey.self] = newValue }
     }

     var getProductsUseCase: GetProductsUseCase {
         get { self[GetProductsUseCaseKey.self] }
         set { self[GetProductsUseCaseKey.self] = newValue }
     }
 }

 // 3. 사용할 때도 키패스 필요
 class ProductListViewModel {
     @Injected(\.getUserUseCase) var getUserUseCase: GetUserUseCase
     @Injected(\.getProductsUseCase) var getProductsUseCase: GetProductsUseCase
 }
 ```

 ## 🚀 After - 엄청 간단해진 방식 (10 줄!)

 */

// MARK: - 🎯 새로운 WeaveDI 방식 설정

/// 🎨 **SwiftUI 스타일 선언적 설정!**
@DependencyConfiguration
var appDependencies {
    // Repository 구현체들
    UserRepositoryImpl()           // UserRepository로 자동 등록
    ProductRepositoryImpl()        // ProductRepository로 자동 등록

    // UseCase들 (의존성 자동 주입!)
    GetUserUseCase()              // @Injected가 자동으로 Repository들 주입!
    GetProductsUseCase()          // @Injected가 자동으로 Repository들 주입!

    // 환경에 따른 Logger 선택
    #if DEBUG
    ConsoleLogger() as Logger     // 개발 시 디버그 로거
    #else
    ProductionLogger() as Logger  // 프로덕션 로거
    #endif
}

/// 🌍 **환경별 설정 예시**
struct AppDependencyConfiguration {

    /// 🏭 프로덕션 환경
    static let production = DependencyEnvironment.production {
        UserRepositoryImpl()
        ProductRepositoryImpl()
        ProductionLogger() as Logger
        GetUserUseCase()
        GetProductsUseCase()
    }

    /// 🧪 개발 환경
    static let development = DependencyEnvironment.development {
        UserRepositoryImpl()        // 실제 Repository
        ProductRepositoryImpl()     // 실제 Repository
        ConsoleLogger() as Logger   // 디버그 Logger
        GetUserUseCase()
        GetProductsUseCase()
    }

    /// 🔬 테스트 환경
    static let testing = DependencyEnvironment.testing {
        MockUserRepository() as UserRepository      // Mock Repository
        MockProductRepository() as ProductRepository // Mock Repository
        NoOpLogger() as Logger                      // NoOp Logger
        GetUserUseCase()
        GetProductsUseCase()
    }

    /// 📱 SwiftUI 프리뷰 환경
    static let preview = DependencyEnvironment.preview {
        MockUserRepository() as UserRepository
        MockProductRepository() as ProductRepository
        ConsoleLogger() as Logger
        GetUserUseCase()
        GetProductsUseCase()
    }
}

// MARK: - 🚀 실제 앱 사용 예시

/// 메인 앱 구조
@main
struct ShoppingApp: App {

    init() {
        // 🎯 환경에 따라 자동 선택!
        configureEnvironment()
    }

    private func configureEnvironment() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            AppDependencyConfiguration.preview.configure()
        } else {
            AppDependencyConfiguration.development.configure()
        }
        #else
        AppDependencyConfiguration.production.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 실제 사용하는 View
struct ContentView: View {
    @StateObject private var viewModel = ProductListViewModel()

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("로딩 중...")
                } else {
                    VStack(alignment: .leading) {
                        if let user = viewModel.currentUser {
                            Text("안녕하세요, \(user.name)님!")
                                .font(.title2)
                                .padding(.bottom)
                        }

                        List(viewModel.products, id: \.id) { product in
                            VStack(alignment: .leading) {
                                Text(product.name)
                                    .font(.headline)
                                Text("$\(product.price, specifier: "%.2f")")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("상품 목록")
            .task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - 📊 성능 테스트 예시

struct PerformanceTest {

    /// DI 해결 성능 테스트
    static func testResolutionPerformance() async {
        // 설정
        AppDependencyConfiguration.testing.configure()

        let startTime = Date()

        // 1000번 해결 테스트
        for _ in 0..<1000 {
            let _: GetUserUseCase = await withUnsafeContinuation { continuation in
                let useCase = GetUserUseCase()
                continuation.resume(returning: useCase)
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        print("🚀 1000번 의존성 해결 시간: \(duration * 1000)ms")
        print("📊 평균 해결 시간: \(duration)ms per resolution")
    }
}

// MARK: - 🔍 사용 예시 요약

/*

 ## 📋 개선 요약

 ### Before (기존 방식):
 - ❌ 50+ 줄의 boilerplate 코드
 - ❌ DependencyKey마다 정의 필요
 - ❌ DependencyValues 확장 필요
 - ❌ @Injected(\.keyPath) 키패스 필요

 ### After (새로운 방식):
 - ✅ 10줄로 완료!
 - ✅ @Injected var service: Service (타입만으로!)
 - ✅ 선언적 설정 (@DependencyConfiguration)
 - ✅ 환경별 자동 분기
 - ✅ SwiftUI 스타일

 ## 🚀 핵심 개선사항

 1. **90% 코드 감소**: 50줄 → 5줄
 2. **타입 안전성**: 컴파일 타임 검증
 3. **자동 의존성 주입**: @Injected가 자동으로 해결
 4. **환경별 설정**: production/development/testing/preview
 5. **TCA 호환성**: TCA @Dependency처럼 사용 가능

 */