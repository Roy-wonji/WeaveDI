# @Injected - 모던 의존성 주입

## 개요

`@Injected`는 WeaveDI의 핵심 Property Wrapper로, TCA의 `@Dependency`에서 영감을 받아 WeaveDI에 최적화되었습니다. 설정 오버헤드 없이 타입 안전하고 컴파일 타임에 검증되는 의존성 주입을 제공합니다.

## 왜 @Injected인가?

- ✅ **타입 안전**: 컴파일 타임 타입 체크
- ✅ **TCA 스타일**: TCA 개발자에게 친숙한 API
- ✅ **유연함**: KeyPath와 Type 기반 접근 모두 지원
- ✅ **불변성**: `mutating get` 불필요
- ✅ **테스트 용이**: 테스트에서 쉽게 오버라이드 가능

## 기본 사용법

### 1. InjectedKey 정의

```swift
struct APIClientKey: InjectedKey {
    static let liveValue: APIClient = APIClientImpl()
    static let testValue: APIClient = MockAPIClient()
}
```

### 2. InjectedValues 확장

```swift
extension InjectedValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
```

### 3. @Injected 사용

```swift
struct MyFeature: Reducer {
    @Injected(\.apiClient) var apiClient

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        .run { send in
            let data = try await apiClient.fetchData()
            await send(.dataLoaded(data))
        }
    }
}
```

## 타입 기반 접근

타입을 직접 사용할 수도 있습니다:

```swift
extension ExchangeUseCaseImpl: InjectedKey {
    public static var liveValue: ExchangeRateInterface {
        let repository = UnifiedDI.register(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
        return ExchangeUseCaseImpl(repository: repository)
    }
}

struct CurrencyFeature: Reducer {
    @Injected(ExchangeUseCaseImpl.self) var exchangeUseCase
}
```

## 테스트하기

`withInjectedValues`를 사용하여 테스트에서 의존성을 오버라이드합니다:

```swift
func testFetchData() async {
    await withInjectedValues { values in
        values.apiClient = MockAPIClient()
    } operation: {
        let feature = MyFeature()
        // Mock으로 테스트
    }
}
```

## @Injected와 비교

| 기능 | @Injected (레거시) | @Injected (신규) |
|------|------------------|------------------|
| 타입 안전 | ❌ 옵셔널 기반 | ✅ 컴파일 타임 |
| TCA 스타일 | ❌ 다름 | ✅ 친숙함 |
| KeyPath | ✅ 지원 | ✅ 지원 |
| 타입 접근 | ❌ 없음 | ✅ 지원 |
| 불변성 | ❌ mutating 필요 | ✅ Non-mutating |
| 테스트 | ⚠️ 수동 | ✅ 내장 |

## 마이그레이션 가이드

### @Injected에서

```swift
// ❌ 이전
@Injected var repository: UserRepository?

// ✅ 신규
@Injected(\.repository) var repository
```

### 수동 해결에서

```swift
// ❌ 이전
let repository = UnifiedDI.requireResolve(UserRepository.self)

// ✅ 신규
@Injected(\.repository) var repository
```

## 모범 사례

1. **KeyPath 접근 선호** - 더 나은 발견 가능성
2. **Type 접근 사용** - 빠른 프로토타이핑용
3. **항상 testValue 정의** - 더 쉬운 테스트
4. **InjectedKey extension을 가까이** - 타입 정의 근처에 위치

## 고급: 프로토콜 기반 의존성

```swift
protocol ExchangeRateInterface: Sendable {
    func getExchangeRates(currency: String) async throws -> ExchangeRates?
}

extension ExchangeUseCaseImpl: InjectedKey {
    public static var liveValue: ExchangeRateInterface {
        // 프로토콜 구현 반환
        ExchangeUseCaseImpl(repository: ...)
    }
}

extension InjectedValues {
    var exchangeUseCase: ExchangeRateInterface {
        get { self[ExchangeUseCaseImpl.self] }
        set { self[ExchangeUseCaseImpl.self] = newValue }
    }
}
```

## 실전 예제: 환율 변환 앱

```swift
// 1. InjectedKey 정의
extension ExchangeUseCaseImpl: InjectedKey {
    public static var liveValue: ExchangeRateInterface {
        let repository = UnifiedDI.register(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
        return ExchangeUseCaseImpl(repository: repository)
    }
}

// 2. InjectedValues 확장
public extension InjectedValues {
    var exchangeUseCase: ExchangeRateInterface {
        get { self[ExchangeUseCaseImpl.self] }
        set { self[ExchangeUseCaseImpl.self] = newValue }
    }
}

// 3. Reducer에서 사용
struct CurrencyFeature: Reducer {
    @Injected(\.exchangeUseCase) var exchangeUseCase

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        case .fetchRates(let currency):
            return .run { send in
                let rates = try await exchangeUseCase.getExchangeRates(currency: currency)
                await send(.ratesLoaded(rates))
            }
    }
}
```

## 참고

- [Property Wrapper 가이드](/ko/guide/propertyWrappers) - 전체 프로퍼티 래퍼 가이드
- [테스트 가이드](/ko/tutorial/testing) - 고급 테스트 패턴
- [TCA 통합](/ko/guide/tcaIntegration) - TCA와 @Injected 사용하기