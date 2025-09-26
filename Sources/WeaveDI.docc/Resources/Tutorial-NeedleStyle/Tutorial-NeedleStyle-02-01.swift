// Needle 수준 성능 활성화: 빌드 플래그 설정

/*
 WeaveDI에서 Needle과 동일한 제로 코스트 성능을 활성화하는 방법

 🚀 목표: 런타임 오버헤드 완전 제거 (Needle과 동등한 성능)
*/

/*
 Step 1: 빌드 플래그 설정

 📱 Xcode 설정:
 1. Target 선택
 2. Build Settings 탭
 3. "Other Swift Flags" 검색
 4. Debug/Release에 다음 추가: -DUSE_STATIC_FACTORY

 💻 Swift Package Manager:
 터미널에서 실행:
 ```bash
 swift build -c release -Xswiftc -DUSE_STATIC_FACTORY
 swift test -c release -Xswiftc -DUSE_STATIC_FACTORY
 ```

 🏗️ Package.swift에서 설정:
 ```swift
 let package = Package(
     name: "MyApp",
     targets: [
         .target(
             name: "MyApp",
             dependencies: ["WeaveDI"],
             swiftSettings: [
                 .define("USE_STATIC_FACTORY", .when(configuration: .release))
             ]
         )
     ]
 )
 ```
*/

import WeaveDI

// 빌드 플래그 확인
func checkBuildFlags() {
    #if USE_STATIC_FACTORY
    print("✅ USE_STATIC_FACTORY 활성화됨!")
    print("🚀 Needle 수준 제로 코스트 성능 사용 가능")
    #else
    print("⚠️  USE_STATIC_FACTORY 비활성화됨")
    print("📖 빌드 플래그를 설정하여 최고 성능을 얻으세요")
    print("   Xcode: Other Swift Flags에 -DUSE_STATIC_FACTORY 추가")
    print("   SPM: swift build -c release -Xswiftc -DUSE_STATIC_FACTORY")
    #endif
}

// 성능 차이 시연
class PerformanceDemo {
    func demonstratePerformanceDifference() {
        // 일반 해결 (약간의 런타임 오버헤드)
        let normalService = UnifiedDI.resolve(UserServiceProtocol.self)

        // 정적 해결 (제로 코스트, Needle과 동등)
        let fastService = UnifiedDI.staticResolve(UserServiceProtocol.self)

        #if USE_STATIC_FACTORY
        print("🚀 정적 해결 활성화: 제로 런타임 코스트")
        // fastService는 컴파일 타임에 최적화된 코드 사용
        #else
        print("⚡ 정적 해결 비활성화: 일반 해결과 동일")
        // fastService도 일반 해결로 폴백
        #endif

        // 성능 크리티컬한 루프에서의 차이
        performanceHotPath()
    }

    func performanceHotPath() {
        // 🔥 핫 패스: 성능이 중요한 부분
        for _ in 0..<10000 {
            #if USE_STATIC_FACTORY
            // Needle 수준 성능: 런타임 오버헤드 없음
            let service = UnifiedDI.staticResolve(UserServiceProtocol.self)
            #else
            // 일반 성능: 약간의 런타임 비용
            let service = UnifiedDI.resolve(UserServiceProtocol.self)
            #endif

            // 서비스 사용
            _ = service?.getUser(id: "fast_user")
        }

        print("✅ 핫 패스 실행 완료")
    }
}

// 컴파일 타임 최적화 확인
func checkCompileTimeOptimization() {
    // WeaveDI의 컴파일 타임 최적화 상태 확인
    print("🔍 컴파일 타임 최적화 상태:")

    #if USE_STATIC_FACTORY
    print("  ✅ 정적 팩토리 생성: 활성화")
    print("  ✅ 런타임 해결 비용: 제로")
    print("  ✅ Needle 동등 성능: 달성")
    #else
    print("  ⚠️  정적 팩토리 생성: 비활성화")
    print("  ⚠️  런타임 해결 비용: 최소")
    print("  📈 성능 개선 가능: USE_STATIC_FACTORY 플래그 추가")
    #endif

    // 성능 비교 출력
    print(UnifiedDI.performanceComparison())
}

// 실제 사용 예시
protocol UserServiceProtocol: Sendable {
    func getUser(id: String) async -> String?
}

class UserServiceImpl: UserServiceProtocol {
    func getUser(id: String) async -> String? {
        return "User: \(id)"
    }
}

// 서비스 등록
func setupServices() {
    _ = UnifiedDI.register(UserServiceProtocol.self) { UserServiceImpl() }

    // 정적 최적화 활성화 (다음 단계에서 설명)
    UnifiedDI.enableStaticOptimization()
}