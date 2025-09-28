# 빠른 시작 가이드

5분 안에 WeaveDI를 시작해보세요.

## 설치

### Swift Package Manager

프로젝트의 Package.swift 파일에 WeaveDI를 추가하세요. 이 설정은 Swift Package Manager가 GitHub 리포지토리에서 WeaveDI 버전 3.1.0 이상을 다운로드하도록 지시합니다:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

**작동 원리:**
- 공식 리포지토리에서 WeaveDI 프레임워크를 다운로드합니다
- 최신 기능과 버그 수정이 포함된 3.1.0 이상 버전을 보장합니다
- Swift 프로젝트의 빌드 시스템과 원활하게 통합됩니다

### Xcode

1. File → Add Package Dependencies
2. 입력: `https://github.com/Roy-wonji/WeaveDI.git`
3. Add Package

## 기본 사용법

### 1. Import

의존성 주입이 필요한 Swift 파일에 WeaveDI를 import하세요. 이를 통해 프로퍼티 래퍼, 등록 API, 컨테이너 관리 등 모든 WeaveDI 기능에 접근할 수 있습니다:

```swift
import WeaveDI
```

**사용 가능한 기능:**
- `@Inject`, `@Factory`, `@SafeInject` 프로퍼티 래퍼 접근
- UnifiedDI 등록 및 해결 API
- DIContainer 부트스트랩 기능
- 모든 WeaveDI 유틸리티 클래스와 프로토콜

### 2. 서비스 정의

서비스를 위한 프로토콜(인터페이스)과 구현을 생성하세요. 이는 의존성 역전 원칙을 따릅니다 - 구체적인 구현이 아닌 추상화에 의존하세요:

```swift
// 서비스 계약 정의 (사용 가능한 기능)
protocol UserService {
    func fetchUser(id: String) async -> User?
}

// 실제 서비스 로직 구현
class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // 실제 앱에서는 API나 데이터베이스를 호출할 것입니다
        // 데모 목적으로 간단한 User 객체를 반환합니다
        return User(id: id, name: "John")
    }
}
```

**프로토콜을 사용하는 이유:**
- **테스트 가능성**: 테스트용 모킹 구현을 쉽게 생성할 수 있습니다
- **유연성**: 의존 코드를 변경하지 않고 구현을 교체할 수 있습니다
- **유지보수성**: 인터페이스와 구현의 명확한 분리
- **모범 사례**: 깔끔한 아키텍처를 위한 SOLID 원칙을 따릅니다

### 3. 의존성 등록

WeaveDI의 의존성 주입 컨테이너에 서비스 구현을 등록하세요. 이는 의존성이 요청될 때 WeaveDI가 인스턴스를 생성하는 방법을 알려줍니다. 앱 시작 시, 일반적으로 App delegate나 SwiftUI App 구조체에서 수행하세요:

```swift
// 앱 시작 시 등록 - 프로토콜과 구현 간의 바인딩을 생성합니다
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()  // 실제 구현을 생성하는 팩토리 클로저
}
```

**등록 작동 방식:**
- **타입 등록**: `UserService` 프로토콜을 `UserServiceImpl` 클래스에 매핑합니다
- **팩토리 클로저**: `{ UserServiceImpl() }` 클로저가 인스턴스 생성 방법을 정의합니다
- **지연 생성**: 인스턴스는 처음 요청될 때만 생성됩니다 (지연 로딩)
- **기본 싱글톤**: 다르게 구성하지 않는 한 동일한 인스턴스가 앱 전체에서 재사용됩니다
- **반환 값**: 필요한 경우 즉시 사용할 수 있도록 생성된 인스턴스를 반환합니다

### 4. Property Wrapper 사용

이제 WeaveDI의 프로퍼티 래퍼를 사용하여 모든 클래스에서 등록된 서비스를 주입하고 사용하세요. `@Inject` 래퍼는 컨테이너에서 의존성을 자동으로 해결합니다:

```swift
class UserViewController {
    // @Inject는 DI 컨테이너에서 UserService를 자동으로 해결합니다
    // '?'는 옵셔널로 만듭니다 - 서비스가 등록되지 않았어도 앱이 크래시되지 않습니다
    @Inject var userService: UserService?

    func loadUser() async {
        // 주입된 의존성을 항상 안전하게 언래핑하세요
        guard let service = userService else {
            print("❌ UserService를 사용할 수 없습니다")
            return
        }

        // 주입된 서비스를 사용하여 작업 수행
        let user = await service.fetchUser(id: "123")

        // 가져온 데이터로 UI 업데이트
        DispatchQueue.main.async {
            // 여기서 UI를 업데이트하세요
            print("✅ 사용자 로드됨: \(user?.name ?? "알 수 없음")")
        }
    }
}
```

**@Inject 작동 방식:**
- **자동 해결**: WeaveDI가 등록된 구현을 자동으로 찾아 주입합니다
- **옵셔널 안전성**: 서비스가 등록되지 않았으면 `nil`을 반환합니다 (크래시 방지)
- **지연 로딩**: 서비스는 처음 접근될 때만 해결됩니다
- **스레드 안전**: 다양한 스레드와 액터에서 안전하게 사용할 수 있습니다

## Property Wrapper

### @Inject - 선택적 의존성

대부분의 의존성 주입 시나리오에서 `@Inject`를 사용하세요. 의존성이 등록되지 않았어도 앱을 크래시시키지 않는 안전한 옵셔널 주입을 제공합니다:

```swift
class ViewController {
    // 표준 의존성 주입 - 안전하고 옵셔널
    @Inject var userService: UserService?

    func viewDidLoad() {
        super.viewDidLoad()

        // 안전한 옵셔널 체이닝 - 서비스가 nil이어도 크래시되지 않습니다
        userService?.fetchUser(id: "current") { [weak self] user in
            DispatchQueue.main.async {
                self?.displayUser(user)
            }
        }

        // 대안: 더 나은 오류 처리를 위한 명시적 nil 확인
        guard let service = userService else {
            showErrorMessage("사용자 서비스를 사용할 수 없습니다")
            return
        }

        // 이제 서비스가 사용 가능함을 알 수 있습니다
        service.fetchUser(id: "current") { user in
            // 사용자 데이터 처리
        }
    }
}
```

**@Inject를 사용하는 경우:**
- **대부분의 시나리오**: 의존성 주입의 주요 선택
- **선택적 의존성**: 중요하지 않지만 있으면 좋은 서비스
- **안전한 주입**: 누락된 의존성으로 인한 크래시를 방지하고 싶을 때
- **테스팅**: 실제 서비스를 등록하지 않아 쉽게 모킹 가능

### @Factory - 매번 새 인스턴스

공유 싱글톤이 아닌 새로운 인스턴스가 필요할 때 `@Factory`를 사용하세요. 상태가 없는 작업이나 격리된 인스턴스가 필요할 때 완벽합니다:

```swift
class DocumentProcessor {
    // @Factory는 접근할 때마다 새로운 PDFGenerator 인스턴스를 생성합니다
    // 각 문서가 자체 생성기를 가져 상태 충돌을 방지합니다
    @Factory var pdfGenerator: PDFGenerator

    func createDocument(content: String) {
        // pdfGenerator에 접근할 때마다 완전히 새로운 인스턴스를 반환합니다
        let generator = pdfGenerator // 여기서 새 인스턴스가 생성됩니다

        // 이 특정 생성기를 구성합니다
        generator.setContent(content)
        generator.setFormat(.A4)

        // PDF 생성
        let pdfData = generator.generate()
        savePDF(pdfData)
    }

    func createMultipleDocuments(contents: [String]) {
        for content in contents {
            // 각 반복마다 완전히 새로운 PDFGenerator를 얻습니다
            let generator = pdfGenerator // 각 문서마다 새로운 인스턴스

            generator.setContent(content)
            let pdf = generator.generate()
            savePDF(pdf)

            // 재설정이나 정리가 필요 없습니다 - 각 생성기는 독립적입니다
        }
    }
}
```

**@Factory를 사용하는 경우:**
- **상태가 없는 작업**: PDF 생성, 이미지 처리, 데이터 변환
- **동시 처리**: 각 스레드/작업이 자체 인스턴스가 필요한 경우
- **공유 상태 방지**: 한 작업이 다른 작업에 영향을 주지 않게 하기
- **빌더 패턴**: 각 구성마다 새로운 빌더
- **수명이 짧은 객체**: 지속될 필요가 없는 객체

### @SafeInject - 에러 처리

누락된 의존성에 대한 명시적 오류 처리가 필요할 때 `@SafeInject`를 사용하세요. 이 래퍼는 의존성 해결 실패에 대한 더 많은 제어를 제공합니다:

```swift
class DataManager {
    // @SafeInject는 해결이 실패할 때 명시적인 오류 정보를 제공합니다
    @SafeInject var database: Database?

    func save(_ data: Data) throws {
        // 의존성 주입이 성공했는지 확인
        guard let db = database else {
            // 디버깅을 위한 특정 오류 로그
            print("❌ Database 의존성을 찾을 수 없습니다 - DI 등록을 확인하세요")

            // 호출자를 위한 설명적인 오류 던지기
            throw DIError.dependencyNotFound(type: "Database")
        }

        // 데이터베이스 작업 진행
        try db.save(data)
        print("✅ 데이터가 성공적으로 저장되었습니다")
    }

    func safeSave(_ data: Data) -> Result<Void, Error> {
        do {
            guard let db = database else {
                return .failure(DIError.dependencyNotFound(type: "Database"))
            }

            try db.save(data)
            return .success(())

        } catch {
            return .failure(error)
        }
    }
}

// 더 나은 오류 처리를 위한 커스텀 오류 타입
enum DIError: LocalizedError {
    case dependencyNotFound(type: String)

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let type):
            return "필수 의존성 '\(type)'을 찾을 수 없습니다. DI 컨테이너에 등록해 주세요."
        }
    }
}
```

**@SafeInject를 사용하는 경우:**
- **중요한 의존성**: 작업에 절대적으로 필요한 서비스
- **오류 보고**: 누락된 의존성에 대한 상세한 오류 정보가 필요할 때
- **명시적 실패 처리**: `nil`이 충분히 설명적이지 않을 때
- **프로덕션 디버깅**: 로그에서 더 나은 진단 정보를 얻기 위해

## 고급 기능

### 런타임 최적화

WeaveDI는 프로덕션 앱에서 의존성 해결 속도를 크게 향상시킬 수 있는 내장 성능 최적화를 포함합니다:

```swift
// 자동 런타임 최적화 활성화
// 이는 앱 라이프사이클 초기에, 일반적으로 AppDelegate나 App.swift에서 호출해야 합니다
UnifiedRegistry.shared.enableOptimization()

// 최적화 시스템은 다음을 수행합니다:
// 1. 빠른 접근을 위해 자주 해결되는 의존성을 캐시합니다
// 2. 최소한의 해결 오버헤드를 위해 의존성 그래프를 최적화합니다
// 3. 더 나은 메모리 관리를 위한 지연 로딩 전략을 사용합니다
// 4. 성능을 모니터링하고 사용 패턴에 따라 자동 튜닝합니다

print("🚀 WeaveDI 최적화 활성화됨 - 더 나은 성능을 기대하세요!")
```

**최적화가 하는 일:**
- **Hot Path 캐싱**: 자주 접근되는 의존성이 즉시 해결을 위해 캐시됩니다
- **그래프 최적화**: 의존성 해결 경로가 최소한의 오버헤드를 위해 최적화됩니다
- **메모리 관리**: 메모리 압박 하에서 사용되지 않는 의존성의 자동 정리
- **성능 모니터링**: 지속적인 개선을 위한 해결 패턴의 실시간 분석

**활성화하는 경우:**
- **프로덕션 빌드**: 최고의 성능을 위해 릴리스 빌드에서 항상 활성화
- **대형 애플리케이션**: 많은 의존성을 가진 앱에 필수
- **성능 중요 앱**: 게임, 실시간 앱, 또는 엄격한 성능 요구사항이 있는 앱

### Bootstrap 패턴

Bootstrap 패턴은 한 곳에서 모든 의존성을 설정하는 권장 방법입니다. 이는 적절한 초기화 순서를 보장하고 의존성 관리를 더 체계적으로 만듭니다:

```swift
// 앱 시작 시 모든 의존성 부트스트랩
// 이는 일반적으로 App.swift나 AppDelegate에서 호출됩니다
await DIContainer.bootstrap { container in
    // 논리적 순서로 서비스 등록

    // 1. 핵심 인프라 서비스 먼저
    container.register(LoggerProtocol.self) {
        ConsoleLogger() // 디버깅을 위한 기본 로깅
    }

    // 2. 데이터 레이어 서비스
    container.register(DatabaseService.self) {
        CoreDataService() // 데이터베이스 레이어
    }

    // 3. 네트워크 서비스
    container.register(NetworkService.self) {
        URLSessionNetworkService() // HTTP 클라이언트
    }

    // 4. 비즈니스 로직 서비스 (인프라에 의존)
    container.register(UserService.self) {
        UserServiceImpl() // 데이터베이스와 네트워크 서비스를 자동으로 사용
    }

    // 5. 프레젠테이션 레이어 서비스
    container.register(AnalyticsService.self) {
        FirebaseAnalytics() // 사용자 추적 및 분석
    }

    print("✅ 모든 의존성이 성공적으로 등록되었습니다")
}

// 대안: 환경별 부트스트랩
#if DEBUG
await DIContainer.bootstrap { container in
    // 개발용 모킹 서비스 사용
    container.register(UserService.self) { MockUserService() }
    container.register(NetworkService.self) { MockNetworkService() }
}
#else
await DIContainer.bootstrap { container in
    // 프로덕션용 실제 서비스 사용
    container.register(UserService.self) { UserServiceImpl() }
    container.register(NetworkService.self) { URLSessionNetworkService() }
}
#endif
```

**Bootstrap 패턴의 장점:**
- **중앙화된 설정**: 모든 의존성 등록이 한 곳에
- **적절한 순서**: 의존성이 논리적 순서로 등록됩니다
- **환경 인식**: 디버그/릴리스 빌드에 대한 다른 설정
- **오류 감지**: 누락되거나 잘못 구성된 의존성을 쉽게 발견
- **문서화**: 앱의 의존성에 대한 명확한 맵 역할

## 다음 단계

- [Property Wrapper](/ko/guide/propertyWrappers) - 상세한 주입 패턴
- [Core API](/ko/api/coreApis) - 완전한 API 레퍼런스
- [런타임 최적화](/ko/guide/runtimeOptimization) - 성능 튜닝