# WeaveDI로 첫 번째 앱 만들기

WeaveDI를 사용하여 간단하면서도 완전한 iOS 카운터 앱을 만들어보세요. 이 튜토리얼은 실용적인 예제를 통해 의존성 주입의 기본 개념을 보여줍니다.

## 🎯 프로젝트 개요

카운터 앱을 통해 다음을 학습합니다:
- **기본 의존성 주입**: `@Injected` 프로퍼티 래퍼 사용
- **서비스 레이어 패턴**: 비즈니스 로직과 UI 분리
- **프로토콜 기반 설계**: 테스트 가능하고 유연한 코드 작성
- **SwiftUI 통합**: 의존성 주입을 포함한 모던 UI

## 📱 앱 기능

카운터 앱의 기능:
- 증가 및 감소 버튼
- 리셋 기능
- 의존성 주입 상태 표시기
- 로깅 서비스 통합
- 깔끔한 SwiftUI 인터페이스

## 🔗 완전한 소스 코드

이 튜토리얼은 WeaveDI.docc 리소스에서 제공하는 공식 WeaveDI 문서 튜토리얼을 기반으로 합니다.

## 🏗️ 단계별 구현

### 1단계: 프로젝트 설정

새로운 iOS 프로젝트를 생성하고 WeaveDI 의존성을 추가합니다:

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeaveDICounterApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(
            url: "https://github.com/Roy-wonji/WeaveDI.git",
            from: "3.0.0"
        )
    ],
    targets: [
        .target(
            name: "WeaveDICounterApp",
            dependencies: ["WeaveDI"]
        )
    ]
)
```

### 2단계: 서비스 레이어 정의

CounterService 프로토콜과 구현을 만듭니다:

```swift
// CounterService.swift
import Foundation

// MARK: - CounterService Protocol

/// 카운터 비즈니스 로직 작업을 정의하는 프로토콜
/// 비동기 컨텍스트에서의 스레드 안전성을 위해 Sendable 사용
protocol CounterService: Sendable {
    /// 카운터 값 증가
    /// - Parameter value: 현재 카운터 값
    /// - Returns: 새로운 증가된 값
    func increment(_ value: Int) -> Int

    /// 카운터 값 감소
    /// - Parameter value: 현재 카운터 값
    /// - Returns: 새로운 감소된 값
    func decrement(_ value: Int) -> Int

    /// 카운터를 0으로 리셋
    /// - Returns: 리셋된 값 (0)
    func reset() -> Int
}

// MARK: - CounterService Implementation

/// CounterService의 기본 구현
/// 로깅과 함께 기본적인 산술 연산 제공
final class DefaultCounterService: CounterService {

    func increment(_ value: Int) -> Int {
        let newValue = value + 1
        print("🔢 [CounterService] 증가: \(value) → \(newValue)")
        return newValue
    }

    func decrement(_ value: Int) -> Int {
        let newValue = value - 1
        print("🔢 [CounterService] 감소: \(value) → \(newValue)")
        return newValue
    }

    func reset() -> Int {
        print("🔢 [CounterService] 0으로 리셋")
        return 0
    }
}
```

### 3단계: 의존성 등록 설정

App 파일에서 WeaveDI 컨테이너를 구성합니다:

```swift
// App.swift
import SwiftUI
import WeaveDI

@main
struct CounterApp: App {

    init() {
        // 앱 시작 시 의존성 등록
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// 모든 앱 의존성 구성
    private func setupDependencies() {
        // CounterService를 기본 구현으로 등록
        // 재사용될 싱글톤 인스턴스 생성
        UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }

        print("✅ 의존성이 성공적으로 등록되었습니다")
    }
}
```

### 4단계: 의존성 주입이 포함된 SwiftUI 뷰 생성

`@Injected` 프로퍼티 래퍼로 메인 인터페이스를 구축합니다:

```swift
// ContentView.swift
import SwiftUI
import WeaveDI

struct ContentView: View {
    // 카운터 값을 위한 상태
    @State private var count = 0

    // 🔥 WeaveDI의 @Injected 프로퍼티 래퍼
    // DI 컨테이너에서 CounterService를 자동으로 해결
    @Injected private var counterService: CounterService?

    var body: some View {
        VStack(spacing: 20) {
            // 앱 제목
            Text("WeaveDI 카운터")
                .font(.largeTitle)
                .fontWeight(.bold)

            // 카운터 표시
            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)

            // 컨트롤 버튼
            HStack(spacing: 20) {
                // 감소 버튼
                Button("-") {
                    if let service = counterService {
                        count = service.decrement(count)
                    }
                }
                .buttonStyle(CounterButtonStyle(color: .red))

                // 증가 버튼
                Button("+") {
                    if let service = counterService {
                        count = service.increment(count)
                    }
                }
                .buttonStyle(CounterButtonStyle(color: .green))

                // 리셋 버튼
                Button("리셋") {
                    if let service = counterService {
                        count = service.reset()
                    }
                }
                .font(.title2)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            // 의존성 주입 상태 표시기
            DependencyStatusView(isInjected: counterService != nil)
        }
        .padding()
    }
}

// MARK: - 지원 뷰

/// 카운터 버튼을 위한 커스텀 버튼 스타일
struct CounterButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title)
            .frame(width: 50, height: 50)
            .background(color)
            .foregroundColor(.white)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 의존성 주입 상태를 보여주는 뷰
struct DependencyStatusView: View {
    let isInjected: Bool

    var body: some View {
        HStack {
            Image(systemName: isInjected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isInjected ? .green : .red)
            Text("CounterService: \(isInjected ? "주입됨" : "사용 불가")")
                .font(.caption)
        }
        .padding(.top)
    }
}

#Preview {
    ContentView()
}
```

### 5단계: 로깅이 포함된 향상된 서비스

여러 의존성을 보여주기 위해 로깅 서비스를 추가합니다:

```swift
// LoggingService.swift
import Foundation

// MARK: - LoggingService Protocol

protocol LoggingService: Sendable {
    var sessionId: String { get }
    func logAction(_ action: String)
    func logInfo(_ message: String)
}

// MARK: - LoggingService Implementation

final class DefaultLoggingService: LoggingService {
    let sessionId: String

    init() {
        // 매번 새로운 세션 ID 생성 (팩토리 패턴 시연)
        self.sessionId = UUID().uuidString.prefix(8).uppercased().description
        print("📝 [LoggingService] 새 세션 시작: \(sessionId)")
    }

    func logAction(_ action: String) {
        print("📝 [\(sessionId)] ACTION: \(action)")
    }

    func logInfo(_ message: String) {
        print("📝 [\(sessionId)] INFO: \(message)")
    }
}
```

로깅을 사용하도록 CounterService를 업데이트합니다:

```swift
// 로깅이 포함된 향상된 CounterService
final class DefaultCounterService: CounterService {
    // 카운터 서비스에 로깅 서비스 주입
    @Injected private var logger: LoggingService?

    func increment(_ value: Int) -> Int {
        let newValue = value + 1
        logger?.logAction("증가: \(value) → \(newValue)")
        return newValue
    }

    func decrement(_ value: Int) -> Int {
        let newValue = value - 1
        logger?.logAction("감소: \(value) → \(newValue)")
        return newValue
    }

    func reset() -> Int {
        logger?.logAction("0으로 리셋")
        return 0
    }
}
```

앱 설정에 로깅 서비스를 등록합니다:

```swift
private func setupDependencies() {
    // LoggingService를 팩토리로 등록 (매번 새 인스턴스)
    UnifiedDI.register(LoggingService.self) {
        DefaultLoggingService()
    }

    // CounterService를 싱글톤으로 등록
    UnifiedDI.register(CounterService.self) {
        DefaultCounterService()
    }

    print("✅ 모든 의존성이 성공적으로 등록되었습니다")
}
```

## 🧪 WeaveDI를 사용한 테스팅

의존성 주입을 사용하여 단위 테스트를 작성합니다:

```swift
// CounterServiceTests.swift
import XCTest
import WeaveDI
@testable import WeaveDICounterApp

class CounterServiceTests: XCTestCase {

    override func setUp() async throws {
        // 각 테스트마다 컨테이너 리셋
        await WeaveDI.Container.resetForTesting()

        // 모의 의존성 등록
        UnifiedDI.register(LoggingService.self) {
            MockLoggingService()
        }

        UnifiedDI.register(CounterService.self) {
            DefaultCounterService()
        }
    }

    func testIncrement() {
        let service = DefaultCounterService()
        let result = service.increment(5)
        XCTAssertEqual(result, 6)
    }

    func testDecrement() {
        let service = DefaultCounterService()
        let result = service.decrement(5)
        XCTAssertEqual(result, 4)
    }

    func testReset() {
        let service = DefaultCounterService()
        let result = service.reset()
        XCTAssertEqual(result, 0)
    }
}

// 테스트를 위한 모의 구현
class MockLoggingService: LoggingService {
    let sessionId = "TEST-SESSION"
    var loggedActions: [String] = []

    func logAction(_ action: String) {
        loggedActions.append(action)
    }

    func logInfo(_ message: String) {
        // 모의 구현
    }
}
```

## 🚀 주요 학습 포인트

이 카운터 앱은 다음을 보여줍니다:

1. **프로퍼티 래퍼 사용**: 자동 의존성 해결을 위한 `@Injected`
2. **프로토콜 기반 설계**: 테스트 가능성을 위한 서비스 인터페이스
3. **의존성 등록**: DI 컨테이너 설정
4. **우아한 처리**: 옵셔널 주입된 의존성 다루기
5. **서비스 조합**: 다른 서비스에 의존하는 서비스
6. **테스트 전략**: 단위 테스트를 위한 의존성 모의 객체화

## 🔧 고급 기능

### 여러 프로퍼티 래퍼

예제를 확장하여 다양한 주입 패턴을 보여줄 수 있습니다:

```swift
struct AdvancedCounterView: View {
    @State private var count = 0

    // 다양한 주입 전략
    @Injected private var counterService: CounterService?          // 옵셔널 주입
    @Injected private var logger: LoggingService?              // 에러 처리를 포함한 안전한 주입
    @Factory private var sessionLogger: LoggingService?         // 팩토리 패턴 (접근할 때마다 새 인스턴스)

    var body: some View {
        // 구현...
    }
}
```

### 조건부 등록

환경에 따라 다른 구현을 등록합니다:

```swift
private func setupDependencies() {
    #if DEBUG
    // 디버그 빌드에서 모의 서비스 사용
    UnifiedDI.register(LoggingService.self) {
        MockLoggingService()
    }
    #else
    // 프로덕션에서 실제 서비스 사용
    UnifiedDI.register(LoggingService.self) {
        DefaultLoggingService()
    }
    #endif
}
```

## 📚 다음 단계

이 카운터 앱을 완성한 후:

1. 다양한 프로퍼티 래퍼 타입(`@Factory`, `@Injected`) 실험해보기
2. 더 많은 서비스를 추가하고 의존성 체인 만들기
3. 에러 처리와 엣지 케이스 구현하기
4. 포괄적인 단위 테스트 작성하기
5. 고급 WeaveDI 기능 탐색하기

## 🔗 관련 리소스

- [프로퍼티 래퍼 가이드](/ko/guide/propertyWrappers)
- [WeaveDI를 사용한 테스팅](/ko/tutorial/testing)
- [성능 최적화](/ko/tutorial/performanceOptimization)
- [고급 패턴](/ko/guide/advancedPatterns)

---

축하합니다! WeaveDI로 첫 번째 앱을 만들었습니다. 이 카운터 앱은 의존성 주입의 기본 개념을 보여주며 깔끔한 아키텍처로 더 복잡한 애플리케이션을 구축하기 위한 기반을 마련합니다.