import WeaveDI
import Foundation

// 중급 01-03: 순환 의존성 감지/해결 전략 (사용법 예)

protocol AType: Sendable {}
protocol BType: Sendable {}
struct AImpl: AType, Sendable {}
struct BImpl: BType, Sendable {}

func exampleCircularDetection() {
    // 1) 일반 등록/해석 흐름 (샘플)
    _ = DI.register(AType.self) { AImpl() }
    _ = DI.register(BType.self) { BImpl() }
    _ = DI.resolve(AType.self)
    _ = DI.resolve(BType.self)

    // 2) 자동 수집된 의존 그래프에서 순환 감지 결과 확인
    let cycles = DIContainer.live.getDetectedCircularDependencies()
    _ = cycles // 결과를 로그/화면으로 노출하여 점검
}

