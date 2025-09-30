# @Injected - Modern Dependency Injection

## Overview

`@Injected` is WeaveDI's flagship property wrapper, inspired by TCA's `@Dependency` but optimized for WeaveDI. It provides type-safe, compile-time checked dependency injection with zero configuration overhead.

## Why @Injected?

- ✅ **Type-Safe**: Compile-time type checking
- ✅ **TCA-Style**: Familiar API for TCA developers
- ✅ **Flexible**: Supports both KeyPath and Type-based access
- ✅ **Immutable**: No `mutating get` required
- ✅ **Testable**: Easy to override in tests

## Basic Usage

### 1. Define InjectedKey

```swift
struct APIClientKey: InjectedKey {
    static let liveValue: APIClient = APIClientImpl()
    static let testValue: APIClient = MockAPIClient()
}
```

### 2. Extend InjectedValues

```swift
extension InjectedValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
```

### 3. Use @Injected

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

## Type-Based Access

You can also use `@Injected` with types directly:

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

## Testing

Override dependencies in tests using `withInjectedValues`:

```swift
func testFetchData() async {
    await withInjectedValues { values in
        values.apiClient = MockAPIClient()
    } operation: {
        let feature = MyFeature()
        // Test with mock
    }
}
```

## Comparison with @Inject

| Feature | @Inject (Legacy) | @Injected (New) |
|---------|------------------|-----------------|
| Type Safety | ❌ Optional-based | ✅ Compile-time |
| TCA Style | ❌ Different | ✅ Familiar |
| KeyPath | ✅ Supported | ✅ Supported |
| Type Access | ❌ No | ✅ Supported |
| Immutable | ❌ Needs mutating | ✅ Non-mutating |
| Testing | ⚠️ Manual | ✅ Built-in |

## Migration Guide

### From @Inject

```swift
// ❌ Old
@Inject var repository: UserRepository?

// ✅ New
@Injected(\.repository) var repository
```

### From Manual Resolution

```swift
// ❌ Old
let repository = UnifiedDI.requireResolve(UserRepository.self)

// ✅ New
@Injected(\.repository) var repository
```

## Best Practices

1. **Prefer KeyPath access** for better discoverability
2. **Use Type access** for quick prototyping
3. **Always define testValue** for easier testing
4. **Keep InjectedKey extensions close** to the type definition

## Advanced: Protocol-based Dependencies

```swift
protocol ExchangeRateInterface: Sendable {
    func getExchangeRates(currency: String) async throws -> ExchangeRates?
}

extension ExchangeUseCaseImpl: InjectedKey {
    public static var liveValue: ExchangeRateInterface {
        // Return protocol implementation
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

## See Also

- [@Factory](./factory.md) - For creating new instances each time
- [InjectedKey Protocol](./injected-key.md) - Detailed protocol documentation
- [Testing Guide](./testing.md) - Advanced testing patterns