import DiContainer
import Foundation

// 중급 02-02: KeyPath / 조건부 등록 사용 예

// MARK: 예제 타입
protocol Logger: Sendable { func log(_ message: String) }
struct ConsoleLogger: Logger, Sendable { func log(_ message: String) { /* print(message) */ } }

protocol AnalyticsService: Sendable { func track(_ event: String) }
struct ProdAnalytics: AnalyticsService, Sendable { func track(_ event: String) { /* send */ } }
struct NoopAnalytics: AnalyticsService, Sendable { func track(_ event: String) { /* ignore */ } }

// KeyPath 사용을 위한 접근자 추가 (예시)
extension DependencyContainer {
    var logger: Logger? { resolve(Logger.self) }
    var analytics: AnalyticsService? { resolve(AnalyticsService.self) }
}

// MARK: 등록/해석 예시
func exampleKeyPathAndConditional(isProd: Bool) {
    // 1) KeyPath 기반 기본 등록
    SimpleKeyPathRegistry.register(\.logger) { ConsoleLogger() }

    // 인스턴스로 바로 등록해야 하는 경우
    SimpleKeyPathRegistry.registerInstance(\.logger, instance: ConsoleLogger())

    // 2) 조건부 등록 (환경에 따라 다른 구현)
    SimpleKeyPathRegistry.registerIf(\.analytics, condition: isProd) { ProdAnalytics() }
    SimpleKeyPathRegistry.registerIf(\.analytics, condition: !isProd) { NoopAnalytics() }

    // 3) 해석 (KeyPath로 접근)
    _ = DIContainer.live[\.logger]?.log("hello")
    _ = DIContainer.live[\.analytics]?.track("screen_open")
}

