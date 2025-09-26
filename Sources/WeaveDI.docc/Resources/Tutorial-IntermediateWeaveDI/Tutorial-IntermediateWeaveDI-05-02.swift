import WeaveDI
import Foundation

// 중급 05-02: 테스트 시나리오/검증 루틴 (사용 예)

func testScenarios_usageStats() async {
    // 1) 테스트 대상 등록
    _ = DI.register(String.self) { "value" }

    // 2) 여러 번 해석하여 사용 통계 생성
    for _ in 0..<5 { _ = DI.resolve(String.self) }

    // 3) 통계/제안 확인으로 간단 검증
    let stats = DIContainer.live.getUsageStatistics()
    let top = UnifiedDI.getTopUsedTypes()
    let tips = UnifiedDI.getOptimizationTips()
    _ = (stats, top, tips) // 테스트에서 기대값 비교/스냅샷 검증 등으로 활용
}

