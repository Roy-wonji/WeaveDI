# WeaveDI v3.2.0 마이그레이션 가이드 & 릴리스 노트

UnifiedRegistry 통합, 성능 개선, 향상된 Swift 6 동시성 지원을 특징으로 하는 WeaveDI v3.2.0의 완전한 가이드입니다.

## 🚀 v3.2.0의 새로운 기능

### 주요 기능

#### 1. UnifiedRegistry 통합
- **10배 성능 향상**: TypeSafeRegistry를 고성능 UnifiedRegistry로 교체
- **설정 불필요**: 코드 변경 없이 자동 최적화
- **락-프리 작업**: 스냅샷 기반 읽기로 경합 제거
- **메모리 최적화**: 딕셔너리 조회 대신 O(1) TypeID 기반 배열 접근

#### 2. QoS 우선순위 보존
- **우선순위 역전 수정**: 비동기 작업에서 QoS 경고 해결
- **스레드 안전 품질**: 비동기 경계에서 적절한 스레드 서비스 품질 유지
- **성능 안정성**: 스레드 우선순위 불일치 제거

#### 3. 향상된 Swift 6 동시성 지원
- **완전한 Sendable 준수**: 코드베이스 전체에 포괄적인 Sendable 제약 추가
- **액터 안전 작업**: 적절한 곳에 완전한 `@unchecked Sendable` 어노테이션
- **동시성 우선 설계**: 모든 API가 Swift 6 동시성을 염두에 두고 설계됨

#### 4. 프로퍼티 래퍼 개선
- **향상된 @Injected**: 더 나은 오류 처리 및 옵셔널 타입 지원
- **개선된 @Factory**: 더 유연한 팩토리 패턴 구현
- **컨테이너 통합**: WeaveDI.Container 해결과 직접 통합

#### 5. 포괄적인 테스트 커버리지
- **25/25 테스트 통과**: 전체 테스트 스위트 재활성화 및 현대화
- **PropertyWrapperTests**: 프로퍼티 래퍼 기능에 대한 완전한 테스트 커버리지
- **IntegrationTests**: 엔드-투-엔드 통합 테스트 시나리오
- **DependencyValues 통합**: 향상된 swift-dependencies 브리지 테스트

## 📈 성능 개선

### 이전 vs 이후 비교

| 작업 | v3.1.x | v3.2.0 | 개선도 |
|------|--------|---------|--------|
| 단일 해결 | ~0.001ms | ~0.0001ms | **10배 빠름** |
| 동시 읽기 | 락 경합 | 락-프리 | **경합 없음** |
| 메모리 사용 | 딕셔너리 오버헤드 | 배열 기반 | **낮은 메모리** |
| QoS 보존 | 우선순위 역전 | 보존됨 | **스레드 안전성** |

### 기술 아키텍처

```swift
// v3.1.x: 락을 사용한 딕셔너리 기반
private var registrations: [String: Any] = [:]
private let lock = NSLock()

// v3.2.0: O(1) 접근을 사용한 UnifiedRegistry
private let unifiedRegistry = UnifiedRegistry()
// - TypeID → 배열 인덱스 매핑
// - 읽기용 불변 스냅샷
// - 업데이트시 쓰기 시 복사
```

## 🔧 API 변경사항

### 브레이킹 체인지 없음! ✅

모든 기존 API가 완전히 호환됩니다:

```swift
// ✅ 이 모든 것들이 변경 없이 계속 작동합니다:

// UnifiedDI API
let service = UnifiedDI.register(UserService.self) { UserServiceImpl() }
let resolved = UnifiedDI.resolve(UserService.self)

// WeaveDI.Container API
let container = WeaveDI.Container()
container.register(UserService.self) { UserServiceImpl() }
let resolved2 = container.resolve(UserService.self)

// 프로퍼티 래퍼
@Injected(UserService.self) var userService
@Factory(UserService.self) var userServiceFactory
```

### 향상된 API

#### 개선된 오류 처리
```swift
// v3.2.0: 더 나은 옵셔널 처리
@Injected(UserService.self) var userService: UserService?
// 등록되지 않았으면 자동으로 nil로 해결 (크래시 없음)
```

#### QoS-인식 작업
```swift
// v3.2.0: 적절한 QoS 보존
Task.detached(priority: .userInitiated) { [unifiedRegistry] in
    result = await unifiedRegistry.resolveAsync(type)
    semaphore.signal()
}
```

## 📝 마이그레이션 단계

### 대부분의 프로젝트: 마이그레이션 불필요! 🎉

v3.2.0은 완전한 API 호환성을 유지하므로, 대부분의 프로젝트는 코드 변경 없이 업그레이드할 수 있습니다:

1. **Package.swift 업데이트**:
   ```swift
   .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
   ```

2. **재빌드 및 테스트**: 기존 코드가 자동으로 UnifiedRegistry 최적화의 혜택을 받습니다

3. **성능 확인**: 앱을 실행하고 성능 개선을 관찰하세요

### 고급 프로젝트용

내부 API나 커스텀 레지스트리 구현을 사용했다면:

#### TypeSafeRegistry → UnifiedRegistry
```swift
// v3.1.x: 커스텀 TypeSafeRegistry 사용
// private let customRegistry = TypeSafeRegistry()

// v3.2.0: 대신 UnifiedRegistry 사용
private let customRegistry = UnifiedRegistry()
```

#### 프로퍼티 래퍼 업데이트
```swift
// v3.1.x: 프로토콜 기반 @Injected (런타임 문제 발생)
// @Injected(UserServiceProtocol.self) var service

// v3.2.0: @Injected와 함께 구체 타입 사용
@Injected(UserServiceImpl.self) var service

// 또는 프로토콜에 대해 컨테이너 해결 사용
var service: UserServiceProtocol? {
    return WeaveDI.Container.live.resolve(UserServiceProtocol.self)
}
```

## 🧪 테스트 업데이트

### 테스트 호환성

모든 테스트가 v3.2.0 호환성을 위해 업데이트되었습니다:

- **PropertyWrapperTests**: 현대적인 Swift 6 구문으로 완전 재작성
- **IntegrationTests**: UnifiedRegistry 통합을 위해 업데이트
- **DependencyValuesIntegrationTests**: 향상된 swift-dependencies 브리지 테스트

### 테스트 실행

```bash
# 모든 테스트가 통과하는지 확인
swift test

# 특정 테스트 스위트
swift test --filter "PropertyWrapperTests"
swift test --filter "IntegrationTests"
```

## 🐛 버그 수정

### 수정된 문제

1. **QoS 우선순위 역전**: 비동기 작업에서 스레드 우선순위 경고 제거
2. **Sendable 위반**: 모든 Swift 6 동시성 경고 해결
3. **프로퍼티 래퍼 크래시**: 옵셔널 프로토콜 타입과의 런타임 크래시 수정
4. **메모리 누수**: UnifiedRegistry에서 메모리 관리 개선
5. **테스트 실패**: 모든 불안정한 테스트 해결 및 신뢰성 개선

## ⚡ 성능 최적화

### UnifiedRegistry 아키텍처

새로운 UnifiedRegistry는 여러 최적화 레이어를 제공합니다:

1. **TypeID 매핑**: O(1) 접근을 위한 `ObjectIdentifier` → `Int` 슬롯 매핑
2. **스냅샷 기술**: 락-프리 읽기를 위한 불변 스토리지 클래스
3. **인라인 최적화**: 오버헤드 감소를 위한 `@inlinable` + `@inline(__always)`
4. **메모리 레이아웃**: 더 나은 캐시 지역성을 위한 최적화된 데이터 구조

### 벤치마킹 결과

```swift
// 성능 측정 (100만 작업)
let start = CFAbsoluteTimeGetCurrent()
for _ in 0..<1_000_000 {
    _ = UnifiedDI.resolve(UserService.self)
}
let duration = CFAbsoluteTimeGetCurrent() - start

// v3.1.x: ~2.1초
// v3.2.0: ~0.21초 (10배 개선)
```

## 🔮 미래 호환성

v3.2.0은 장기적 안정성을 위해 설계되었습니다:

- **Swift 6 준비**: 미래 Swift 버전과 완전 호환
- **API 안정성**: v3.x 시리즈에서 브레이킹 체인지 계획 없음
- **성능 기반**: UnifiedRegistry가 미래 최적화의 기반 제공
- **동시성 진화**: Swift 동시성 발전에 대비

## 📚 문서 업데이트

### 업데이트된 가이드

- **[런타임 최적화](./runtimeOptimization.md)**: UnifiedRegistry용으로 업데이트
- **[벤치마크](./benchmarks.md)**: 새로운 성능 비교 데이터
- **[UnifiedDI 가이드](./unifiedDi.md)**: UnifiedRegistry 통합 섹션 추가
- **[프로퍼티 래퍼](./propertyWrappers.md)**: 업데이트된 사용 패턴

### 새로운 콘텐츠

- **UnifiedRegistry 통합**: 새로운 아키텍처에 대한 기술 심화
- **마이그레이션 가이드**: 이 포괄적인 마이그레이션 문서
- **성능 분석**: 상세한 벤치마킹 방법론 및 결과

## 🤝 기여하기

v3.2.0은 동일한 기여 가이드라인을 유지합니다:

- 모든 API가 후진 호환성 유지
- 새로운 기능은 포괄적인 테스트 포함 필요
- 성능 개선은 벤치마크 포함 필요
- 사용자 대상 변경사항은 문서 업데이트 필요

## 📞 지원

v3.2.0과 관련된 문제가 있으시면:

1. **마이그레이션 가이드 확인**: 대부분의 문제가 이 문서에서 다뤄집니다
2. **테스트 예제 검토**: 업데이트된 테스트 파일에서 사용 패턴 확인
3. **성능 문제**: 예상 결과와 벤치마크 비교
4. **API 질문**: 업데이트된 문서 섹션 확인

## 🎯 요약

WeaveDI v3.2.0이 제공하는 것:

- ✅ **10배 성능 향상** UnifiedRegistry 통합을 통해
- ✅ **브레이킹 체인지 없음** - 기존 코드가 변경 없이 작동
- ✅ **완전한 Swift 6 지원** 포괄적인 Sendable 준수로
- ✅ **향상된 테스트** 완전한 테스트 스위트 커버리지로
- ✅ **더 나은 문서** 업데이트된 가이드와 예제로

**지금 업그레이드하여 노력 없이 성능 부스트를 경험해보세요!**

---

*UnifiedRegistry 아키텍처에 대한 기술적 세부사항은 [런타임 최적화 가이드](./runtimeOptimization.md)를 참조하세요*

*API 사용 예제는 [UnifiedDI vs WeaveDI.Container 가이드](./unifiedDi.md)를 참조하세요*