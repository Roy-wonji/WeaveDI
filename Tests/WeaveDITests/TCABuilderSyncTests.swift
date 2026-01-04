import XCTest
@testable import WeaveDI

// MARK: - Test Protocols
protocol AuthInterface: Sendable {
    func authenticate() -> String
}

protocol SignUpInterface: Sendable {
    func signUp() -> String
}

protocol AttendanceInterface: Sendable {
    func getAttendance() -> String
}

// MARK: - Test Implementations
struct AuthRepositoryImpl: AuthInterface {
    func authenticate() -> String {
        return "Auth Success"
    }
}

struct SignUpRepositoryImpl: SignUpInterface {
    func signUp() -> String {
        return "SignUp Success"
    }
}

struct AttendanceRepositoryImpl: AttendanceInterface {
    func getAttendance() -> String {
        return "Attendance Data"
    }
}

// MARK: - TCA DependencyKey 정의
struct AuthServiceKey: DependencyKey {
    static var liveValue: AuthInterface = AuthRepositoryImpl()
    static var testValue: AuthInterface = AuthRepositoryImpl()
    static var previewValue: AuthInterface = AuthRepositoryImpl()
}

extension DependencyValues {
    var authService: AuthInterface {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// MARK: - 실제 테스트
final class TCABuilderSyncTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 각 테스트 전에 컨테이너 초기화
        UnifiedDI.releaseAll()
    }

    // MARK: - Builder 패턴 테스트
    func testBuilderPattern() {
        print("🚀 Builder Pattern Test 시작...")

        // Builder로 등록
        WeaveDI.builder
            .register { AuthRepositoryImpl() as AuthInterface }
            .register { SignUpRepositoryImpl() as SignUpInterface }
            .register { AttendanceRepositoryImpl() as AttendanceInterface }
            .configure()

        print("✅ Builder 등록 완료")

        // 해결 테스트
        let auth = UnifiedDI.resolve(AuthInterface.self)
        let signUp = UnifiedDI.resolve(SignUpInterface.self)
        let attendance = UnifiedDI.resolve(AttendanceInterface.self)

        XCTAssertNotNil(auth, "Auth should be resolved")
        XCTAssertNotNil(signUp, "SignUp should be resolved")
        XCTAssertNotNil(attendance, "Attendance should be resolved")

        XCTAssertEqual(auth?.authenticate(), "Auth Success")
        XCTAssertEqual(signUp?.signUp(), "SignUp Success")
        XCTAssertEqual(attendance?.getAttendance(), "Attendance Data")

        print("🎉 Builder Pattern Test 성공!")
    }

    // MARK: - @Injected 사용 테스트
    func testInjectedWithBuilder() {
        print("🚀 @Injected Test 시작...")

        // Builder로 등록
        WeaveDI.builder
            .register { AuthRepositoryImpl() as AuthInterface }
            .configure()

        struct TestUseCase {
            @Injected var auth: AuthInterface

            func test() -> String {
                return auth.authenticate()
            }
        }

        let useCase = TestUseCase()
        let result = useCase.test()

        XCTAssertEqual(result, "Auth Success", "@Injected should work with builder registration")
        print("✅ @Injected Test 성공: \(result)")
    }

    // MARK: - TCA 동기화 테스트
    func testTCASync() {
        print("🚀 TCA Sync Test 시작...")

        // 1. TCA 방식으로 등록
        var deps = DependencyValues()
        deps.authService = AuthRepositoryImpl()
        DependencyManager.setCurrent(deps)
        print("✅ TCA 방식으로 등록 완료")

        // 2. WeaveDI 방식으로 등록
        UnifiedDI.register(SignUpInterface.self) { SignUpRepositoryImpl() }
        print("✅ WeaveDI 방식으로 등록 완료")

        struct SyncTestUseCase {
            // TCA 등록 → @Injected 사용
            @Injected var authFromTCA: AuthInterface

            // WeaveDI 등록 → @Injected 사용
            @Injected var signUpFromWeaveDI: SignUpInterface

            // KeyPath 방식으로 TCA 사용
            @Injected(\.authService) var authKeyPath: AuthInterface

            func testSync() -> (String, String, String) {
                return (
                    authFromTCA.authenticate(),
                    signUpFromWeaveDI.signUp(),
                    authKeyPath.authenticate()
                )
            }
        }

        let useCase = SyncTestUseCase()
        let (auth1, signUp, auth2) = useCase.testSync()

        XCTAssertEqual(auth1, "Auth Success", "TCA → @Injected sync should work")
        XCTAssertEqual(signUp, "SignUp Success", "WeaveDI → @Injected should work")
        XCTAssertEqual(auth2, "Auth Success", "KeyPath → @Injected should work")

        print("✅ TCA Sync Test 성공!")
        print("   TCA → @Injected: \(auth1)")
        print("   WeaveDI → @Injected: \(signUp)")
        print("   KeyPath → @Injected: \(auth2)")
    }

    // MARK: - 혼합 사용 테스트
    func testMixedUsage() {
        print("🚀 Mixed Usage Test 시작...")

        // Builder + UnifiedDI + TCA 혼합 등록
        WeaveDI.builder
            .register { AuthRepositoryImpl() as AuthInterface }
            .configure()

        UnifiedDI.register(SignUpInterface.self) { SignUpRepositoryImpl() }

        var deps = DependencyValues()
        deps[AttendanceInterface.self] = AttendanceRepositoryImpl()
        DependencyManager.setCurrent(deps)

        struct MixedUseCase {
            @Injected var auth: AuthInterface
            @Injected var signUp: SignUpInterface
            @Injected var attendance: AttendanceInterface

            func testAll() -> (String, String, String) {
                return (
                    auth.authenticate(),
                    signUp.signUp(),
                    attendance.getAttendance()
                )
            }
        }

        let useCase = MixedUseCase()
        let (auth, signUp, attendance) = useCase.testAll()

        XCTAssertEqual(auth, "Auth Success")
        XCTAssertEqual(signUp, "SignUp Success")
        XCTAssertEqual(attendance, "Attendance Data")

        print("✅ Mixed Usage Test 성공!")
        print("   Builder: \(auth)")
        print("   UnifiedDI: \(signUp)")
        print("   TCA: \(attendance)")
    }
}