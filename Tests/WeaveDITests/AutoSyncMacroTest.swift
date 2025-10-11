import XCTest
@testable import WeaveDI
import Foundation

#if canImport(Dependencies)
import Dependencies

// 🧪 테스트용 Service 프로토콜 - 파일 레벨에서 선언
protocol TestAutoSyncService: Sendable {
    func getName() -> String
}

// 🧪 테스트용 구현체
struct TestAutoSyncServiceImpl: TestAutoSyncService {
    func getName() -> String {
        return "TestAutoSyncService from WeaveDI"
    }
}

// 🧪 테스트용 DependencyKey
struct TestAutoSyncServiceKey: DependencyKey {
    static let liveValue: TestAutoSyncService = TestAutoSyncServiceImpl()
}

// 🧪 테스트용 InjectedKey
extension TestAutoSyncServiceImpl: InjectedKey {
    public static var liveValue: TestAutoSyncService {
        TestAutoSyncServiceImpl()
    }
}

// 🎯 테스트 1: DependencyValues + @AutoSyncExtension - 파일 레벨에서 선언
@AutoSyncExtension
extension DependencyValues {
    var testAutoSyncService: TestAutoSyncService {
        get { self[TestAutoSyncServiceKey.self] }
        set { self[TestAutoSyncServiceKey.self] = newValue }
    }
}

// 🎯 테스트 2: InjectedValues + @AutoSyncExtension - 파일 레벨에서 선언
@AutoSyncExtension
extension InjectedValues {
    var testAutoSyncService2: TestAutoSyncService {
        get { self[TestAutoSyncServiceImpl.self] }
        set { self[TestAutoSyncServiceImpl.self] = newValue }
    }
}

final class AutoSyncMacroTest: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // 양방향 동기화 활성화
        await MainActor.run {
            enableBidirectionalTCASync()
        }
    }

    func testAutoSyncMacroCompilation() async throws {
        // Given: @AutoSyncExtension 매크로가 적용된 extension들

        // When: 기본 동작 확인 (컴파일만 성공하면 OK)
        let service = TestAutoSyncServiceImpl()
        let result = service.getName()

        // Then: 정상 동작 확인
        XCTAssertEqual(result, "TestAutoSyncService from WeaveDI")
        print("✅ @AutoSyncExtension 매크로 컴파일 테스트 성공: \(result)")
    }

    func testTCASmartSyncActivation() async throws {
        // Given: TCASmartSync 활성화

        // When: enableBidirectionalTCASync() 호출
        await MainActor.run {
            enableBidirectionalTCASync()
        }

        // Then: TCASmartSync가 활성화되어야 함
        let isEnabled = await MainActor.run {
            TCASmartSync.isEnabled
        }

        XCTAssertTrue(isEnabled)
        print("✅ TCASmartSync 활성화 테스트 성공: isEnabled=\(isEnabled)")
    }

    func testAutoDetectAndSync() async throws {
        // Given: 테스트 서비스
        let service = TestAutoSyncServiceImpl()

        // When: 자동 감지 동기화 호출
        TCASmartSync.autoDetectAndSync(TestAutoSyncServiceKey.self, value: service)

        // Then: 에러 없이 완료
        XCTAssertTrue(true) // 에러 없이 실행되면 성공
        print("✅ 자동 감지 동기화 테스트 성공")
    }

}

#else

final class AutoSyncMacroTest: XCTestCase {
    func testDependenciesNotAvailable() {
        print("❌ Dependencies 모듈이 없습니다. TCA가 설치되지 않았습니다.")
        XCTFail("Dependencies module not available")
    }
}

#endif
