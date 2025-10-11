import WeaveDI
import Foundation

#if canImport(Dependencies)
import Dependencies

// 🧪 테스트용 Service 프로토콜
protocol AutoSyncDemoService: Sendable {
    func getName() -> String
}

// 🧪 테스트용 구현체
struct AutoSyncDemoServiceImpl: AutoSyncDemoService {
    func getName() -> String {
        return "AutoSyncDemoService from WeaveDI"
    }
}

// 🧪 테스트용 DependencyKey
struct AutoSyncDemoServiceKey: DependencyKey {
    static let liveValue: AutoSyncDemoService = AutoSyncDemoServiceImpl()
}

// 🧪 테스트용 InjectedKey
extension AutoSyncDemoServiceImpl: InjectedKey {
    public static var liveValue: AutoSyncDemoService {
        AutoSyncDemoServiceImpl()
    }
}

// 🎯 테스트 1: DependencyValues + @AutoSyncExtension
@AutoSyncExtension
extension DependencyValues {
    var autoSyncDemoService: AutoSyncDemoService {
        get { self[AutoSyncDemoServiceKey.self] }
        set { self[AutoSyncDemoServiceKey.self] = newValue }
    }
}

// 🎯 테스트 2: InjectedValues + @AutoSyncExtension
@AutoSyncExtension
extension InjectedValues {
    var autoSyncDemoService: AutoSyncDemoService {
        get { self[AutoSyncDemoServiceImpl.self] }
        set { self[AutoSyncDemoServiceImpl.self] = newValue }
    }
}

// 🧪 테스트 실행 함수
@MainActor
func runAutoSyncTest() {
    print("🧪 @AutoSyncExtension 매크로 테스트 시작...")

    // 1. 양방향 동기화 활성화
    enableBidirectionalTCASync()

    // 2. DependencyValues 테스트
    print("📋 DependencyValues 테스트:")
    @Dependency(\.autoSyncDemoService) var service1
    print("   - service1.getName(): \(service1.getName())")

    // 3. InjectedValues 테스트
    print("📋 InjectedValues 테스트:")
    @Injected(\.autoSyncDemoService) var service2: AutoSyncDemoService
    print("   - service2.getName(): \(service2.getName())")

    print("🎉 @AutoSyncExtension 매크로 테스트 완료!")
}

#else
@MainActor
func runAutoSyncTest() {
    print("❌ Dependencies 모듈이 없습니다. TCA가 설치되지 않았습니다.")
}
#endif
