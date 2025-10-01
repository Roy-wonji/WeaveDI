# SwiftUI 통합

SwiftUI 뷰, 프로퍼티 래퍼, 그리고 프리뷰에서 WeaveDI를 효과적으로 사용하는 방법을 학습합니다.

## SwiftUI 뷰에서 DI 사용하기

### 기본 뷰 주입

```swift
struct UserProfileView: View {
    @Injected(\.userService) var userService
    @Injected(\.imageLoader) var imageLoader

    @State private var user: User?
    @State private var isLoading = false

    var body: some View {
        VStack {
            if let user = user {
                AsyncImage(url: user.avatarURL)
                Text(user.name)
                Text(user.email)
            } else if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadUser()
        }
    }

    private func loadUser() async {
        isLoading = true
        defer { isLoading = false }

        do {
            user = try await userService.fetchCurrentUser()
        } catch {
            print("사용자 로드 실패: \(error)")
        }
    }
}
```

## ObservableObject와의 통합

### DI를 포함한 ViewModel

```swift
@MainActor
final class UserProfileViewModel: ObservableObject {
    @Injected(\.userService) var userService
    @Injected(\.authService) var authService

    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await userService.fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await authService.logout()
            user = nil
        } catch {
            errorMessage = "로그아웃 실패"
        }
    }
}

// 뷰에서 사용
struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text(user.name)
                Button("로그아웃") {
                    Task { await viewModel.logout() }
                }
            } else if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .task {
            await viewModel.loadUser()
        }
    }
}
```

## DI를 포함한 SwiftUI 프리뷰

### 기본 프리뷰 구성

```swift
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // 방법 1: withInjectedValues 사용
        UserProfileView()
            .task {
                await withInjectedValues { values in
                    values.userService = MockUserService()
                    values.authService = MockAuthService()
                } operation: {}
            }
    }
}
```

### 사용자 정의 의존성을 포함한 고급 프리뷰

```swift
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 프리뷰 1: 로딩 상태
            PreviewWithDependencies(
                userService: LoadingUserService()
            ) {
                UserProfileView()
            }
            .previewDisplayName("로딩")

            // 프리뷰 2: 성공 상태
            PreviewWithDependencies(
                userService: MockUserService(user: .preview)
            ) {
                UserProfileView()
            }
            .previewDisplayName("성공")

            // 프리뷰 3: 에러 상태
            PreviewWithDependencies(
                userService: ErrorUserService()
            ) {
                UserProfileView()
            }
            .previewDisplayName("에러")
        }
    }
}

// 프리뷰 DI를 위한 헬퍼
struct PreviewWithDependencies<Content: View>: View {
    let userService: UserService
    let content: Content

    init(
        userService: UserService,
        @ViewBuilder content: () -> Content
    ) {
        self.userService = userService
        self.content = content()
    }

    var body: some View {
        content
            .task {
                await withInjectedValues { values in
                    values.userService = userService
                } operation: {}
            }
    }
}
```

## Environment vs @Injected

### Environment를 사용해야 하는 경우

**SwiftUI Environment 사용 시기:**
- 뷰 계층 구조를 통해 값을 전달해야 할 때
- 값이 UI에 특화된 경우 (색상, 폰트, 레이아웃)
- 특정 뷰 서브트리의 값을 오버라이드하고 싶을 때

```swift
// Environment 접근 방식
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            ThemedButton()
        }
        .environment(\.theme, .dark)
    }
}

struct ThemedButton: View {
    @Environment(\.theme) var theme

    var body: some View {
        Button("눌러주세요") {}
            .foregroundColor(theme.primaryColor)
    }
}
```

### @Injected를 사용해야 하는 경우

**@Injected 사용 시기:**
- 비즈니스 로직 서비스가 필요할 때
- 의존성이 앱 전체적일 때 (뷰 특화가 아닌)
- KeyPath와 함께 컴파일 타임 타입 안전성이 필요할 때
- 다른 구현으로 테스트해야 할 때

```swift
// @Injected 접근 방식
struct OrderListView: View {
    @Injected(\.orderService) var orderService
    @State private var orders: [Order] = []

    var body: some View {
        List(orders) { order in
            OrderRow(order: order)
        }
        .task {
            orders = try await orderService.fetchOrders()
        }
    }
}
```

### 비교 표

| 기능 | Environment | @Injected |
|------|-------------|-----------|
| 범위 | 뷰 계층 구조 | 앱 전체 |
| 타입 안전성 | 런타임 | 컴파일 타임 (KeyPath) |
| 오버라이드 | 뷰 서브트리별 | 전역 또는 스코프별 |
| 사용 사례 | UI 구성 | 비즈니스 로직 |
| 테스트 | `.environment()`로 전달 | `withInjectedValues` |
| 성능 | 뷰별 | 싱글톤/스코프별 |

## @Injected와 @State, @Binding 결합하기

### 부모-자식 데이터 플로우

```swift
// 부모 뷰
struct OrderManagementView: View {
    @Injected(\.orderService) var orderService
    @State private var orders: [Order] = []
    @State private var selectedOrder: Order?

    var body: some View {
        NavigationView {
            List(orders) { order in
                Button(order.title) {
                    selectedOrder = order
                }
            }
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
            }
            .task {
                await loadOrders()
            }
        }
    }

    private func loadOrders() async {
        do {
            orders = try await orderService.fetchOrders()
        } catch {
            print("주문 로드 실패")
        }
    }
}

// 자식 뷰
struct OrderDetailView: View {
    @Injected(\.orderService) var orderService
    let order: Order

    @State private var isProcessing = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text(order.title)
            Text("총액: \(order.total)")

            Button("주문 처리") {
                Task { await processOrder() }
            }
            .disabled(isProcessing)
        }
    }

    private func processOrder() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await orderService.processOrder(order)
            dismiss()
        } catch {
            print("주문 처리 실패")
        }
    }
}
```

## 고급 패턴

### DI를 위한 뷰 모디파이어

```swift
struct WithMockData: ViewModifier {
    func body(content: Content) -> some View {
        content
            .task {
                await withInjectedValues { values in
                    values.userService = MockUserService()
                    values.orderService = MockOrderService()
                } operation: {}
            }
    }
}

extension View {
    func withMockData() -> some View {
        modifier(WithMockData())
    }
}

// 프리뷰에서 사용
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .withMockData()
    }
}
```

### DI 컨테이너 뷰

```swift
struct DIContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        setupDependencies()
    }

    private func setupDependencies() {
        // 프로덕션 의존성 설정
        Task {
            await withInjectedValues { values in
                values.userService = ProductionUserService()
                values.orderService = ProductionOrderService()
            } operation: {}
        }
    }

    var body: some View {
        content
    }
}

// 사용법
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            DIContainer {
                ContentView()
            }
        }
    }
}
```

### Observable 매크로 통합 (iOS 17+)

```swift
import Observation

@Observable
final class UserProfileViewModel {
    @Injected(\.userService) var userService

    var user: User?
    var isLoading = false
    var errorMessage: String?

    @MainActor
    func loadUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await userService.fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// 뷰 (iOS 17+)
struct UserProfileView: View {
    @State private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text(user.name)
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadUser()
        }
    }
}
```

## SwiftUI 뷰 테스트

### ViewModel 단위 테스트

```swift
import XCTest
@testable import MyApp

final class UserProfileViewModelTests: XCTestCase {
    func testLoadUser() async throws {
        await withInjectedValues { values in
            values.userService = MockUserService(user: .testUser)
        } operation: {
            let viewModel = UserProfileViewModel()

            await viewModel.loadUser()

            XCTAssertNotNil(viewModel.user)
            XCTAssertEqual(viewModel.user?.name, "Test User")
            XCTAssertFalse(viewModel.isLoading)
        }
    }

    func testLoadUserError() async throws {
        await withInjectedValues { values in
            values.userService = ErrorUserService()
        } operation: {
            let viewModel = UserProfileViewModel()

            await viewModel.loadUser()

            XCTAssertNil(viewModel.user)
            XCTAssertNotNil(viewModel.errorMessage)
        }
    }
}
```

### 의존성을 포함한 스냅샷 테스트

```swift
import SnapshotTesting
@testable import MyApp

final class UserProfileViewSnapshotTests: XCTestCase {
    func testUserProfileViewSuccess() async {
        await withInjectedValues { values in
            values.userService = MockUserService(user: .preview)
        } operation: {
            let view = UserProfileView()
            assertSnapshot(matching: view, as: .image)
        }
    }

    func testUserProfileViewLoading() async {
        await withInjectedValues { values in
            values.userService = LoadingUserService()
        } operation: {
            let view = UserProfileView()
            assertSnapshot(matching: view, as: .image)
        }
    }
}
```

## 모범 사례

### ✅ 할 것들

```swift
// ✅ 비즈니스 로직에 @Injected 사용
struct ProductListView: View {
    @Injected(\.productService) var productService
}

// ✅ ViewModel에 @StateObject 사용
struct ProductListView: View {
    @StateObject private var viewModel = ProductListViewModel()
}

// ✅ 프리뷰에서 의존성 구성
struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        ProductListView()
            .task {
                await withInjectedValues { values in
                    values.productService = MockProductService()
                } operation: {}
            }
    }
}

// ✅ 뷰는 프레젠테이션에 집중
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack {
            Text(product.name)
            Spacer()
            Text("$\(product.price)")
        }
    }
}
```

### ❌ 하지 말 것들

```swift
// ❌ 작은 뷰에 무거운 서비스 직접 주입 금지
struct ProductPriceLabel: View {
    @Injected(\.productService) var productService  // 너무 세분화됨
    let productId: String
}

// ❌ View body에서 의존성 생성 금지
struct ProductListView: View {
    var body: some View {
        let service = ProductService()  // 잘못됨!
        // ...
    }
}

// ❌ 같은 의존성에 Environment와 @Injected 혼용 금지
struct ProductView: View {
    @Environment(\.productService) var envService
    @Injected(\.productService) var injectedService  // 혼란스러움
}
```

## Environment에서 @Injected로 마이그레이션

### 이전 (Environment)

```swift
// 기존 Environment 접근 방식
struct ProductServiceKey: EnvironmentKey {
    static let defaultValue: ProductService = ProductServiceImpl()
}

extension EnvironmentValues {
    var productService: ProductService {
        get { self[ProductServiceKey.self] }
        set { self[ProductServiceKey.self] = newValue }
    }
}

struct ProductListView: View {
    @Environment(\.productService) var productService
}

// 부모에서 설정
ContentView()
    .environment(\.productService, MockProductService())
```

### 이후 (@Injected)

```swift
// 새로운 @Injected 접근 방식
struct ProductServiceKey: InjectedKey {
    static var liveValue: ProductService = ProductServiceImpl()
    static var testValue: ProductService = MockProductService()
}

extension InjectedValues {
    var productService: ProductService {
        get { self[ProductServiceKey.self] }
        set { self[ProductServiceKey.self] = newValue }
    }
}

struct ProductListView: View {
    @Injected(\.productService) var productService
}

// 테스트 구성
await withInjectedValues { values in
    values.productService = MockProductService()
} operation: {
    // 테스트 코드
}
```

## 다음 단계

- [테스트 가이드](../tutorial/testing) - DI와 함께 SwiftUI 뷰를 테스트하는 방법 학습
- [TCA 통합](./tcaIntegration) - The Composable Architecture와 WeaveDI 사용하기
- [모범 사례](./bestPractices) - 일반적인 DI 모범 사례
- [실무 가이드](./practicalGuide) - 실제 사용 패턴