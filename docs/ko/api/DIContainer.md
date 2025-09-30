---
title: DIContainer
lang: ko-KR
---

# DIContainer

DIContainer 전용 Global Actor (자동 정의)

```swift
public actor DIContainerActor {
  public static let shared = DIContainerActor()
}
```

## 개요
`DIContainer`는 현대적이고 직관적인 의존성 주입 컨테이너입니다.
기존의 여러 Container 클래스들을 하나로 통합하여 단순화했습니다.
## 핵심 특징
### 🔒 스레드 안전성
- **타입 안전한 레지스트리**: TypeSafeRegistry 사용
- **동시성 지원**: Swift Concurrency와 완벽 호환
- **멀티스레드 안전**: 여러 스레드에서 동시 접근 가능
### 📝 통합된 등록 시스템
- **즉시 등록**: `register(_:factory:)` - 바로 사용 가능
- **인스턴스 등록**: `register(_:instance:)` - 이미 생성된 객체
- **KeyPath 지원**: `\.keyPath` 방식으로 타입 안전 보장
- **모듈 시스템**: 대량 등록을 위한 Module 패턴
### 🚀 부트스트랩 시스템
- **안전한 초기화**: 앱 시작 시 의존성 준비
- **원자적 교체**: 컨테이너 전체를 한 번에 교체
- **테스트 지원**: 테스트 간 격리 보장
- **Swift 6 동시성**: 기존 API는 동기, Actor API는 자동 생성

```swift
public final class DIContainer: ObservableObject, @unchecked Sendable {
}
```

  /// 타입 안전한 의존성 저장소
  /// 모듈 기반 일괄 등록을 위한 모듈 배열 (동시성 안전: concurrent + barrier)
  /// Parent-Child 관계 지원
  /// Swift 6 완전 호환 shared 인스턴스 관리
  /// 전역 인스턴스 (동기 API - 기존 호환성)
  /// @DIContainerActor로 보호된 shared 인스턴스
  /// Actor 보호하에 의존성 등록
  /// Actor 보호하에 의존성 해결
  /// 빈 컨테이너를 생성합니다
  /// 기본 초기화 (루트 컨테이너)
  /// Parent-Child 초기화
  /// - Parameter parent: 부모 컨테이너 (의존성을 상속받음)
  /// 새로운 자식 컨테이너를 생성합니다.
  /// 자식 컨테이너는 부모의 의존성을 상속받습니다.
  /// ### 사용법:
  /// ```swift
  /// let appContainer = DIContainer()
  /// appContainer.register(DatabaseService.self) { DatabaseImpl() }
  /// let userModule = appContainer.createChild()
  /// userModule.register(UserRepository.self) {
  ///     UserRepositoryImpl(database: resolve()) // 부모에서 Database 해결
  /// }
  /// ```
  /// - Returns: 새로운 자식 컨테이너
  /// 모든 자식 컨테이너를 가져옵니다
  /// - Returns: 현재 등록된 자식 컨테이너들
  /// 부모 컨테이너를 가져옵니다.
  /// - Returns: 부모 컨테이너 (루트인 경우 nil)
  /// 의존성을 등록하고 즉시 생성된 인스턴스를 반환합니다
  /// 팩토리를 즉시 실행하여 인스턴스를 생성하고, 컨테이너에 등록한 후 반환합니다.
  /// 가장 직관적이고 권장되는 등록 방법입니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 인스턴스
  /// ### 사용 예시:
  /// ```swift
  /// let repository = container.register(UserRepository.self) {
  ///     UserRepositoryImpl()
  /// }
  /// ```
  /// 팩토리 패턴으로 의존성을 등록합니다 (지연 생성)
  /// 실제 `resolve` 호출 시에만 팩토리가 실행되어 매번 새로운 인스턴스가 생성됩니다.
  /// 메모리 효율성이 중요하거나 생성 비용이 높은 경우 사용합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 클로저
  /// - Returns: 등록 해제 핸들러
  /// 이미 생성된 인스턴스를 등록합니다
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  /// Actor 보호된 인스턴스 등록 (동시성 안전)
  /// 등록된 의존성을 조회합니다
  /// 의존성이 등록되지 않은 경우 nil을 반환하므로 안전하게 처리할 수 있습니다.
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  /// 의존성을 조회하거나 기본값을 반환합니다
  /// - Parameters:
  ///   - type: 조회할 타입
  ///   - defaultValue: 해결 실패 시 사용할 기본값
  /// - Returns: 해결된 인스턴스 또는 기본값
  /// 특정 타입의 의존성 등록을 해제합니다
  /// - Parameter type: 해제할 타입
  /// KeyPath 기반 의존성 조회 서브스크립트
  /// - Parameter keyPath: WeaveDI.Container의 T?를 가리키는 키패스
  /// - Returns: resolve(T.self) 결과
  /// 모듈을 컨테이너에 추가합니다 (스레드 안전)
  /// 실제 등록은 `buildModules()` 호출 시에 병렬로 처리됩니다.
  /// - Parameter module: 등록 예약할 Module 인스턴스
  /// - Returns: 체이닝을 위한 현재 컨테이너 인스턴스
  /// 수집된 모든 모듈의 등록을 병렬로 실행합니다 (스레드 안전)
  /// TaskGroup을 사용하여 모든 모듈을 동시에 병렬 처리합니다.
  /// 대량의 의존성 등록 시간을 크게 단축할 수 있습니다.
  /// 성능 메트릭과 함께 모듈을 빌드합니다
  /// - Returns: 빌드 실행 통계
  /// 현재 등록 대기 중인 모듈의 개수를 반환합니다
  /// 컨테이너가 비어있는지 확인합니다
  /// 모듈을 등록하는 편의 메서드
  /// 함수 호출 스타일을 지원하는 메서드 (체이닝용)
  /// 모듈 빌드 메서드 (기존 buildModules와 동일)

```swift
public extension DIContainer {
}
```

  /// 컨테이너를 부트스트랩합니다 (동기 등록)
  /// 앱 시작 시 의존성을 안전하게 초기화하기 위한 메서드입니다.
  /// 원자적으로 컨테이너를 교체하여 초기화 경합을 방지합니다.
  /// - Parameter configure: 의존성 등록 클로저
  /// 컨테이너를 부트스트랩합니다 (비동기 등록)
  /// 비동기 초기화가 필요한 의존성(예: 데이터베이스, 원격 설정)이 있을 때 사용합니다.
  /// - Parameter configure: 비동기 의존성 등록 클로저
  /// 별도의 Task 컨텍스트에서 비동기 부트스트랩을 수행하는 편의 메서드입니다
  /// 혼합 부트스트랩 (동기 + 비동기)
  /// - Parameters:
  ///   - sync: 즉시 필요한 의존성 등록
  ///   - async: 비동기 초기화가 필요한 의존성 등록
  /// 이미 부트스트랩되어 있지 않은 경우에만 실행합니다
  /// - Parameter configure: 의존성 등록 클로저
  /// - Returns: 부트스트랩이 수행되었는지 여부
  /// 이미 부트스트랩되어 있지 않은 경우에만 비동기 부트스트랩을 수행합니다
  /// 런타임에 의존성을 업데이트합니다 (동기)
  /// - Parameter configure: 업데이트할 의존성 등록 클로저
  /// 런타임에 의존성을 업데이트합니다 (비동기)
  /// - Parameter configure: 비동기 업데이트 클로저
  /// DI 컨테이너 접근 전, 부트스트랩이 완료되었는지를 보장합니다
  /// 테스트를 위해 컨테이너를 초기화합니다
  /// ⚠️ DEBUG 빌드에서만 사용 가능합니다.
  /// 부트스트랩 상태를 확인합니다
기존 WeaveDI.Container와의 호환성을 위한 별칭

```swift
public enum WeaveDI {
  public typealias Container = DIContainer
}
```

  /// 🎯 모든 의존성을 자동으로 등록하는 훅
  /// 프로젝트에서 이 메서드를 구현하면 ModuleFactoryManager.registerAll()이 자동으로 호출합니다.
  /// ### 사용법:
  /// ```swift
  /// // 프로젝트의 AutoDIRegistry.swift
  /// extension WeaveDI.Container {
  ///     static func registerRepositories() async {
  ///         await helper.exchangeRepositoryModule().register()
  ///     }
  ///     static func registerUseCases() async {
  ///         await helper.exchangeUseCaseModule().register()
  ///     }
  /// }
  /// ```
  /// 📦 Repository 등록 (프로젝트에서 오버라이드)
  /// 🔧 UseCase 등록 (프로젝트에서 오버라이드)
WeaveDI.Container.live 호환성

```swift
public extension DIContainer {
  static var live: DIContainer {
    get { shared }
    set { shared = newValue }
  }
}
```

Factory 타입들을 위한 KeyPath 확장

```swift
public extension DIContainer {
}
```

  /// Repository 모듈 팩토리 KeyPath
  /// UseCase 모듈 팩토리 KeyPath
  /// Scope 모듈 팩토리 KeyPath
  /// 모듈 팩토리 매니저 KeyPath
모듈 빌드 실행 통계 정보

```swift
public struct ModuleBuildMetrics {
  /// 처리된 모듈 수
  public let moduleCount: Int
}
```

  /// 총 실행 시간 (초)
  /// 초당 처리 모듈 수
  /// 포맷된 요약 정보
자동 의존성 주입 기능 확장

```swift
public extension DIContainer {
}
```

  /// 🚀 자동 생성된 의존성 그래프를 시각화합니다
  /// 별도 설정 없이 자동으로 수집된 의존성 관계를 텍스트로 출력합니다.
  /// ⚡ 자동 최적화된 타입들을 반환합니다
  /// 사용 패턴을 분석하여 자동으로 성능 최적화가 적용된 타입들의 목록입니다.
  /// ⚠️ 자동 감지된 순환 의존성을 반환합니다
  /// 의존성 등록/해결 과정에서 자동으로 감지된 순환 의존성 목록입니다.
  /// 📊 자동 수집된 성능 통계를 반환합니다
  /// 각 타입의 사용 빈도가 자동으로 추적됩니다.
  /// 🔍 특정 타입이 자동 최적화되었는지 확인합니다
  /// - Parameter type: 확인할 타입
  /// - Returns: 최적화 여부
  /// ⚙️ 자동 최적화 기능을 제어합니다
  /// - Parameter enabled: 활성화 여부 (기본값: true)
  /// 🧹 자동 수집된 통계를 초기화합니다
