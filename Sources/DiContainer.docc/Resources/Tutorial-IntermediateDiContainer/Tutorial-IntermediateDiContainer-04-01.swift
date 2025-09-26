import DiContainer
import Foundation

// 중급 04-01: 안전 주입 / 복구 전략 사용 예

protocol PaymentGateway: Sendable { func charge(_ amount: Int) -> Bool }
struct DefaultPaymentGateway: PaymentGateway, Sendable { func charge(_ amount: Int) -> Bool { true } }

// 1) 안전한 해석 (실패 시 에러 포함 결과)
func exampleSafeResolve() {
    switch SafeDependencyResolver.safeResolve(PaymentGateway.self) {
    case .success(let gateway):
        _ = gateway.charge(100)

    case .failure(let error):
        // 복구: 기본 구현으로 대체
        let fallback = DefaultPaymentGateway()
        _ = fallback.charge(100)
        _ = error.isRecoverable
    }
}

// 2) 복구 전략을 동반한 안전 해석
func exampleRecoveryStrategy() {
    let resolved = SafeDependencyResolver.safeResolve(
        PaymentGateway.self,
        strategy: .fallback { DefaultPaymentGateway() }
    )
    _ = resolved?.charge(50)
}

// 3) SafeInject Property Wrapper 사용 예
struct CheckoutViewModel {
    @SafeInject var gateway: PaymentGateway?

    func checkout(amount: Int) {
        if let gw = gateway {
            _ = gw.charge(amount)
        } else {
            _ = DefaultPaymentGateway().charge(amount)
        }
    }
}

