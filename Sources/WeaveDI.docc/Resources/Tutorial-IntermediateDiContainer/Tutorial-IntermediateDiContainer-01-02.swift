import DiContainer
import Foundation

// 중급 01-02: Optimizer & Utilities 사용 예 (공개 API 중심)

// 예제 서비스
protocol MetricsService: Sendable { func run() }
struct FastMetricsService: MetricsService, Sendable { func run() { /* work */ } }

func exampleOptimizerAndUtilities() async {
    // 1) 성능 최적화 활성화
    DIAdvanced.Performance.enableOptimization()

    // 2) 등록 (즉시 생성/등록)
    _ = DI.register(MetricsService.self) { FastMetricsService() }

    // 3) 추적과 함께 해석 (자동 통계 수집)
    for _ in 0..<10 {
        _ = DIAdvanced.Performance.resolveWithTracking(MetricsService.self)?.run()
    }

    // 4) 통계 확인
    let stats = await DIAdvanced.Performance.getStats()
    _ = stats // 발표 시 로그/화면 출력으로 활용
}

