import XCTest
@testable import WeaveDI

final class MyIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 테스트 간 정리
        DispatchQueue.main.sync {
            UnifiedDI.releaseAll()
        }
    }

    // MARK: - Test Protocols & Implementations

    protocol TestAuthInterface: Sendable {
        func authenticate() -> String
    }

    protocol TestSignUpInterface: Sendable {
        func signUp() -> String
    }

    struct TestAuthImpl: TestAuthInterface {
        func authenticate() -> String {
            return "Auth Success"
        }
    }

    struct TestSignUpImpl: TestSignUpInterface {
        func signUp() -> String {
            return "SignUp Success"
        }
    }

    // MARK: - Builder Pattern Test

    func testBuilderPattern() {
        // Builder로 등록
        WeaveDI.builder
            .register { TestAuthImpl() as TestAuthInterface }
            .register { TestSignUpImpl() as TestSignUpInterface }
            .configure()

        // 해결 테스트
        let auth = UnifiedDI.resolve(TestAuthInterface.self)
        let signUp = UnifiedDI.resolve(TestSignUpInterface.self)

        XCTAssertNotNil(auth)
        XCTAssertNotNil(signUp)
        XCTAssertEqual(auth?.authenticate(), "Auth Success")
        XCTAssertEqual(signUp?.signUp(), "SignUp Success")

        print("✅ Builder Pattern Test: Auth=\(auth?.authenticate() ?? "nil"), SignUp=\(signUp?.signUp() ?? "nil")")
    }

    // MARK: - @Injected Test

    func testInjectedPropertyWrapper() {
        // 먼저 등록
        UnifiedDI.register(TestAuthInterface.self) { TestAuthImpl() }
        UnifiedDI.register(TestSignUpInterface.self) { TestSignUpImpl() }

        struct TestUseCase {
            @Injected var auth: TestAuthInterface
            @Injected var signUp: TestSignUpInterface

            func test() -> (String, String) {
                return (auth.authenticate(), signUp.signUp())
            }
        }

        let useCase = TestUseCase()
        let (auth, signUp) = useCase.test()

        XCTAssertEqual(auth, "Auth Success")
        XCTAssertEqual(signUp, "SignUp Success")

        print("✅ @Injected Test: Auth=\(auth), SignUp=\(signUp)")
    }

    // MARK: - Basic TCA Style Test

    func testBasicTCAStyle() {
        // DependencyKey 스타일
        struct TestServiceKey: DependencyKey {
            static let liveValue: TestAuthInterface = TestAuthImpl()
            static let testValue: TestAuthInterface = TestAuthImpl()
            static let previewValue: TestAuthInterface = TestAuthImpl()
        }

        // DependencyValues extension
        extension DependencyValues {
            var testAuth: TestAuthInterface {
                get { self[TestServiceKey.self] }
                set { self[TestServiceKey.self] = newValue }
            }
        }

        // TCA 스타일로 설정
        var deps = DependencyValues()
        deps.testAuth = TestAuthImpl()
        DependencyManager.setCurrent(deps)

        // KeyPath로 사용 테스트
        struct TCATestUseCase {
            @Injected(\.testAuth) var auth: TestAuthInterface

            func test() -> String {
                return auth.authenticate()
            }
        }

        let useCase = TCATestUseCase()
        let result = useCase.test()

        XCTAssertEqual(result, "Auth Success")
        print("✅ TCA Style Test: \(result)")
    }

    // MARK: - 동기화 테스트 (간단 버전)

    func testSyncBetweenUnifiedDIAndTCA() {
        // 1. UnifiedDI로 등록
        UnifiedDI.register(TestAuthInterface.self) { TestAuthImpl() }

        // 2. @Injected로 타입 기반 해결
        struct TypeBasedUseCase {
            @Injected var auth: TestAuthInterface

            func test() -> String {
                return auth.authenticate()
            }
        }

        let useCase = TypeBasedUseCase()
        let result = useCase.test()

        XCTAssertEqual(result, "Auth Success")
        print("✅ UnifiedDI → @Injected 동기화: \(result)")
    }
}