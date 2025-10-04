import WeaveDI
import Foundation

#if canImport(Dependencies)
import Dependencies

// 🧪 테스트용 Service 프로토콜
protocol TestService: Sendable {
    func getName() -> String
}

// 🧪 테스트용 구현체
struct TestServiceImpl: TestService {
    func getName() -> String {
        return "TestService from WeaveDI"
    }
}

// 🧪 테스트용 DependencyKey
struct TestServiceKey: DependencyKey {
    static let liveValue: TestService = TestServiceImpl()
}

// 🧪 테스트용 InjectedKey
extension TestServiceImpl: InjectedKey {
    public static var liveValue: TestService {
        TestServiceImpl()
    }
}

// 🎯 테스트 1: DependencyValues + @AutoSync
@AutoSync
extension DependencyValues {
    var testService: TestService {
        get { self[TestServiceKey.self] }
        set { self[TestServiceKey.self] = newValue }
    }
}

// 🎯 테스트 2: InjectedValues + @AutoSync
@AutoSync
extension InjectedValues {
    var testService2: TestService {
        get { self[TestServiceImpl.self] }
        set { self[TestServiceImpl.self] = newValue }
    }
}

// 🧪 테스트 실행 함수
@MainActor
func runAutoSyncTest() {
    print("🧪 @AutoSync 매크로 테스트 시작...")

    // 1. 양방향 동기화 활성화
    enableBidirectionalTCASync()

    // 2. DependencyValues 테스트
    print("📋 DependencyValues 테스트:")
    @Dependency(\.testService) var service1
    print("   - service1.getName(): \(service1.getName())")

    // 3. InjectedValues 테스트
    print("📋 InjectedValues 테스트:")
    @Injected var service2: TestService
    print("   - service2.getName(): \(service2.getName())")

    print("🎉 @AutoSync 매크로 테스트 완료!")
}

#else
@MainActor
func runAutoSyncTest() {
    print("❌ Dependencies 모듈이 없습니다. TCA가 설치되지 않았습니다.")
}
#endif