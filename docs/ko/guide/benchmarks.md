# 벤치마크

WeaveDI와 다른 DI 프레임워크들 간의 성능 비교 및 벤치마킹 결과입니다.

## 개요

WeaveDI 3.2.0+은 Swinject나 Needle과 같은 기존 DI 프레임워크 대비 상당한 성능 향상을 제공합니다. 이 페이지에서는 포괄적인 벤치마킹 결과와 방법론을 제공합니다.

## 성능 비교

### 프레임워크 비교

| 시나리오 | Swinject | Needle | WeaveDI 3.2.0 | 향상도 |
|---------|----------|--------|-------------|--------|
| 단일 의존성 해결 | 1.2ms | 0.8ms | 0.2ms | **Needle 대비 83%** |
| 복잡한 의존성 그래프 | 25.6ms | 15.6ms | 3.1ms | **Needle 대비 80%** |
| MainActor UI 업데이트 | 5.1ms | 3.1ms | 0.6ms | **Needle 대비 81%** |
| Swift 6 동시성 | ❌ | ⚠️ 부분적 | ✅ 완전 지원 | **네이티브 지원** |

### 런타임 최적화 결과

v3.1.0에서 런타임 최적화를 활성화한 경우:

| 시나리오 | 향상도 | 설명 |
|----------|--------|------|
| 단일 스레드 해결 | 50-80% 빠름 | TypeID + 직접 접근 |
| 멀티 스레드 읽기 | 2-3배 처리량 | 락-프리 스냅샷 |
| 복잡한 의존성 | 20-40% 빠름 | 체인 평탄화 |

## 벤치마크 실행

### 전제 조건

```bash
# 저장소 클론
git clone https://github.com/Roy-wonji/WeaveDI.git
cd WeaveDI
```

### 기본 벤치마크

```bash
# 표준 벤치마크 실행
swift run -c release Benchmarks

# 사용자 정의 반복으로 빠른 벤치마크
swift run -c release Benchmarks --count 100k --quick

# 포괄적인 벤치마크 스위트
swift run -c release Benchmarks --full --iterations 1000000
```

### 최적화 벤치마크

```bash
# 최적화 vs 표준 비교
swift run -c release Benchmarks --compare-optimization

# 메모리 사용량 프로파일링
swift run -c release Benchmarks --profile-memory

# Actor hop 분석
swift run -c release Benchmarks --actor-analysis
```

## 벤치마크 방법론

### 테스트 환경

- **기기**: MacBook Pro M2 Max
- **RAM**: 32GB 통합 메모리
- **Swift**: 6.0+
- **Xcode**: 16.0+
- **릴리스 빌드**: `-c release` 최적화 포함

### 테스트 시나리오

#### 1. 단일 의존성 해결
```swift
// 단일 해결 시간 측정
let start = CFAbsoluteTimeGetCurrent()
let service = container.resolve(UserService.self)
let elapsed = CFAbsoluteTimeGetCurrent() - start
```

#### 2. 복잡한 의존성 그래프
```swift
// 10개 이상의 중첩된 의존성을 가진 서비스
class ComplexService {
    let userService: UserService
    let analyticsService: AnalyticsService
    let networkService: NetworkService
    // ... 7개 이상의 추가 의존성
}
```

#### 3. MainActor UI 업데이트
```swift
@MainActor
class ViewController {
    @Inject var userService: UserService?
    
    func updateUI() async {
        // Actor hop 최적화 측정
        let data = await userService?.fetchData()
        updateInterface(data) // 이미 MainActor에서 실행
    }
}
```

## 메모리 프로파일링

### 메모리 사용량 비교

| 프레임워크 | 기본 메모리 | 등록당 메모리 | 최대 메모리 |
|-----------|-------------|---------------|-------------|
| Swinject | 2.5MB | 145KB | 25.8MB |
| Needle | 1.8MB | 89KB | 18.2MB |
| WeaveDI | 1.2MB | 52KB | 12.4MB |

### 메모리 효율성 기능

1. **지연 해결**: 의존성은 액세스 시에만 해결됨
2. **약한 참조**: 스코프 인스턴스의 자동 메모리 관리
3. **최적화된 스토리지**: 최소 오버헤드 데이터 구조
4. **스코프 분리**: 스코프 간 효율적인 메모리 격리

## 동시성 벤치마크

### Actor 모델 성능

```swift
// WeaveDI 네이티브 async/await 지원
@MainActor
class UIService {
    @Inject var dataService: DataService?
    
    func loadData() async {
        // Actor hop 불필요 - 최적화된 경로
        let data = await dataService?.fetch()
        updateUI(data)
    }
}
```

### 스레드 안전성 비교

| 측면 | Swinject | Needle | WeaveDI |
|------|----------|--------|---------|
| 스레드 안전성 | ⚠️ 수동 락 | ✅ 컴파일 타임 | ✅ 네이티브 async/await |
| Actor 지원 | ❌ | ⚠️ 제한적 | ✅ 완전 통합 |
| 동시성 모델 | 구식 GCD | 혼재 | Swift Concurrency |
| 데이터 레이스 | 가능함 | 드물음 | 제거됨 |

## 고급 벤치마킹

### 사용자 정의 벤치마크 설정

```swift
import WeaveDI
import Foundation

class CustomBenchmark {
    func measureResolutionTime<T>(type: T.Type) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10000 {
            let _ = UnifiedDI.resolve(type)
        }
        
        return CFAbsoluteTimeGetCurrent() - start
    }
}
```

### Instruments로 프로파일링

```bash
# Instruments로 프로파일링
xcodebuild -scheme WeaveDI -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath BenchmarkResults.xcresult \
  test
```

## 성능 팁

### 최적화 가이드라인

1. **런타임 최적화 활성화**:
   ```swift
   await UnifiedRegistry.shared.enableOptimization()
   ```

2. **프로퍼티 래퍼 사용**:
   ```swift
   @Inject var service: UserService? // 최적화된 주입
   ```

3. **스코프 활용**:
   ```swift
   UnifiedDI.registerScoped(Service.self, scope: .singleton) {
       ExpensiveService()
   }
   ```

4. **배치 등록**:
   ```swift
   UnifiedDI.batchRegister { container in
       container.register(ServiceA.self) { ServiceAImpl() }
       container.register(ServiceB.self) { ServiceBImpl() }
   }
   ```

## 결과 분석

### 핵심 성능 통찰

1. **Needle 대비 83% 빠름**: TypeID 기반 해결로 리플렉션 오버헤드 제거
2. **Swinject 대비 90% 빠름**: 컴파일 타임 안전성으로 런타임 검증 제거
3. **Actor 최적화**: MainActor UI 업데이트 시간 81% 감소
4. **메모리 효율성**: 등록당 메모리 사용량 52% 감소

### 실제 영향

- **앱 시작 시간**: 의존성 초기화 40-60% 빨라짐
- **UI 응답성**: Actor hop 감소로 더 부드러운 애니메이션
- **배터리 수명**: 최적화된 해결 경로로 CPU 사용량 감소
- **개발 경험**: 더 빠른 디버그 빌드 및 테스트

## 지속적인 벤치마킹

### CI 통합

WeaveDI 프로젝트는 CI에서 자동 벤치마킹을 포함합니다:

```yaml
# .github/workflows/benchmark.yml
name: Performance Benchmarks
on: [push, pull_request]

jobs:
  benchmark:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Benchmarks
      run: swift run -c release Benchmarks --ci
```

### 회귀 감지

성능 회귀는 자동으로 감지되고 보고됩니다:

- **임계값**: 5% 성능 저하 시 CI 실패
- **비교**: 이전 릴리스 기준선과 비교
- **보고**: PR 댓글에 상세한 성능 보고서

## 관련 문서

- [런타임 최적화](/ko/guide/runtimeOptimization) - 성능 최적화 가이드
- [성능 최적화 가이드](/ko/guide/runtimeOptimization) - 상세한 최적화 기술
- [코어 API](/ko/api/coreApis) - API 성능 특성
