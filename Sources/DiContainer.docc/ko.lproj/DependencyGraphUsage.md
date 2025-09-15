# 의존성 그래프 시각화 가이드

DiContainer는 Uber Needle과 유사한 강력한 의존성 그래프 시각화 기능을 제공합니다.

## 📊 개요

의존성 그래프 시각화를 통해 다음을 할 수 있습니다:
- 의존성 구조를 시각적으로 파악
- 순환 의존성 탐지 및 해결
- 복잡한 의존성 체인 분석
- 다양한 포맷으로 그래프 내보내기

## 🚀 빠른 시작

### 1. 기본 그래프 생성

```swift
import DiContainer

// 의존성 등록
UnifiedDI.register(UserServiceProtocol.self) { UserServiceImpl() }
UnifiedDI.register(NetworkServiceProtocol.self) { URLSessionNetworkService() }

// 자동 그래프 생성
try AutoGraphGenerator.quickGenerate()
```

### 2. 실시간 모니터링

```swift
// 5초마다 그래프 업데이트
let outputDir = URL(fileURLWithPath: "live_graphs")
AutoGraphGenerator.shared.startRealtimeGraphMonitoring(
    outputDirectory: outputDir,
    refreshInterval: 5.0
)
```

## 📋 지원 포맷

### DOT (Graphviz)
```swift
let dotGraph = DependencyGraphVisualizer.generateDOTGraph(
    title: "My App Dependencies",
    options: GraphVisualizationOptions(
        direction: .topToBottom,
        nodeShape: .box,
        backgroundColor: "#f8f9fa"
    )
)

// 이미지 변환 (터미널에서)
// dot -Tpng dependency_graph.dot -o graph.png
// dot -Tsvg dependency_graph.dot -o graph.svg
```

### Mermaid (GitHub/Notion 호환)
```swift
let mermaidGraph = DependencyGraphVisualizer.generateMermaidGraph(
    title: "Dependency Overview"
)

print("```mermaid")
print(mermaidGraph)
print("```")
```

### ASCII 텍스트
```swift
let asciiGraph = DependencyGraphVisualizer.generateASCIIGraph(maxWidth: 80)
print(asciiGraph)
```

### JSON 데이터
```swift
let jsonGraph = DependencyGraphVisualizer.generateJSONGraph()
// API나 외부 도구와 연동 시 유용
```

## 🔍 순환 의존성 탐지

### 자동 탐지 활성화
```swift
// 순환 의존성 탐지 활성화
CircularDependencyDetector.shared.setDetectionEnabled(true)

// 의존성 등록 시 자동으로 순환 의존성 검사
do {
    try UnifiedDI.register(ServiceA.self) { ServiceAImpl() }
} catch SafeDIError.circularDependency(let path) {
    print("순환 의존성 발견: \(path.joined(separator: " → "))")
}
```

### 전체 그래프 분석
```swift
let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
if !cycles.isEmpty {
    print("발견된 순환 의존성:")
    for cycle in cycles {
        print("  🔄 \(cycle.description)")
    }
}
```

### 상세 리포트 생성
```swift
let outputDir = URL(fileURLWithPath: "dependency_reports")
try AutoGraphGenerator.shared.generateCircularDependencyReport(
    outputDirectory: outputDir
)
```

## 📈 의존성 분석

### 특정 타입 분석
```swift
let analysis = CircularDependencyDetector.shared.analyzeDependencyChain(UserService.self)
print(analysis.summary)

// 출력:
// 의존성 체인 분석: UserService
// - 직접 의존성: 2개
// - 전체 의존성: 5개
// - 최대 깊이: 3
// - 순환 의존성: 없음
```

### 전체 그래프 통계
```swift
let stats = CircularDependencyDetector.shared.getGraphStatistics()
print(stats.summary)

// 출력:
// 의존성 그래프 통계:
// - 총 타입 수: 15
// - 총 의존성 수: 28
// - 평균 의존성/타입: 1.9
// - 최대 의존성/타입: 4
// - 의존성 없는 타입: 3
// - 탐지된 순환: 0개
```

## 🛠 앱 통합

### AppDelegate 통합
```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // DI 컨테이너 설정
        Task {
            await DependencyContainer.bootstrap { container in
                // 의존성 등록...
            }

            #if DEBUG
            // 개발 모드에서만 그래프 생성
            AppIntegrationExamples.setupDevelopmentGraphGeneration()
            #endif
        }

        return true
    }
}
```

### SwiftUI 통합
```swift
@main
struct MyApp: App {

    init() {
        Task {
            await DependencyContainer.bootstrap { container in
                // 의존성 등록...
            }

            #if DEBUG
            // 그래프 생성 (개발용)
            let setup = AppIntegrationExamples.swiftUIAppIntegration()
            setup()
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 환경변수 제어
```bash
# Xcode Scheme에서 설정
GENERATE_DEPENDENCY_GRAPH=true

# 또는 터미널에서
GENERATE_DEPENDENCY_GRAPH=true ./MyApp
```

```swift
// 조건부 그래프 생성
AppIntegrationExamples.conditionalGraphGeneration()
```

## 🧪 CI/CD 통합

### 정적 분석 스크립트
```swift
// CI/CD 파이프라인에서 사용
do {
    try AppIntegrationExamples.cicdStaticAnalysis()
    print("✅ 의존성 구조 검증 성공")
} catch CIError.circularDependencyDetected(let count) {
    print("❌ 순환 의존성 \(count)개 발견")
    exit(1)
}
```

### GitHub Actions 예제
```yaml
name: Dependency Analysis
on: [push, pull_request]

jobs:
  dependency-check:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Dependency Analysis
      run: |
        swift run DependencyAnalyzer
        # 순환 의존성 검사 및 그래프 생성
```

## 🎨 고급 사용법

### 커스텀 시각화 옵션
```swift
let options = GraphVisualizationOptions(
    direction: .leftToRight,
    nodeShape: .circle,
    highlightCycles: true,
    backgroundColor: "#ffffff",
    nodeColor: "#4CAF50",
    edgeColor: "#2196F3",
    cycleColor: "#F44336"
)

try AutoGraphGenerator.shared.generateAllGraphs(
    outputDirectory: URL(fileURLWithPath: "custom_graphs"),
    formats: [.dot, .mermaid, .json],
    options: options
)
```

### 다중 포맷 내보내기
```swift
// 모든 포맷으로 동시 생성
await GraphGenerationExamples.multiFormatGraphGeneration()

// 생성된 파일들:
// • dependency_graph.dot
// • dependency_graph.mermaid
// • dependency_graph.json
// • dependency_graph.txt
```

### 콘솔 출력
```swift
// 텍스트 기반 의존성 트리
let tree = DependencyGraphVisualizer.generateDependencyTree(
    "UserService",
    maxDepth: 4
)
print(tree)

// ASCII 그래프
GraphGenerationExamples.dependencyTreeConsoleOutput()
```

> 참고: DOT → 이미지(PNG/SVG) 변환은 macOS 환경에서 Graphviz 명령어를 실행해야 합니다. iOS 등 샌드박스 환경에서는 DOT/Mermaid 텍스트를 산출하여 외부 뷰어나 웹에서 렌더링하는 방식을 권장합니다.

## 🔧 개발자 도구

### 명시적 그래프 생성
```swift
// 즉시 그래프 생성
AppIntegrationExamples.generateGraphsNow()

// 또는 개발자 도구 사용
await DeveloperTools.generateComprehensiveGraphs()
```

### 디버깅 도구
```swift
// 의존성 해결 추적
DeveloperTools.enableDependencyTracing()

// 성능 모니터링
DeveloperTools.enablePerformanceMonitoring()

// 메모리 사용량 추적
DeveloperTools.enableMemoryTracking()
```

## 💡 팁과 권장사항

1. **개발 모드 전용**: 프로덕션에서는 그래프 생성을 비활성화하세요
2. **정기적 분석**: CI/CD에서 순환 의존성을 정기적으로 검사하세요
3. **시각화 활용**: 복잡한 의존성 구조를 이해하는 데 그래프를 활용하세요
4. **성능 고려**: 대규모 프로젝트에서는 필요시에만 그래프를 생성하세요

## 📚 추가 자료

- [CoreAPIs](CoreAPIs.md) - 핵심 API 가이드
- [PluginSystem](PluginSystem.md) - 플러그인 시스템
- [PropertyWrappers](PropertyWrappers.md) - 프로퍼티 래퍼 사용법
