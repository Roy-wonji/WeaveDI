---
title: SafeDependencyKey
lang: en-US
---

# SafeDependencyKey

안전한 DependencyKey 패턴을 위한 확장
## 문제가 있는 패턴:
```swift
extension BookListUseCaseImpl: DependencyKey {
    public static var liveValue: BookListInterface = {
        // 🚨 이런 식으로 사용하면 안됨
        let repository = SimpleKeyPathRegistry.register(\.bookListInterface) { ... }
        return BookListUseCaseImpl(repository: repository as! BookListInterface)
    }()
}
```
## ✅ 안전한 패턴들:

```swift
public enum SafeDependencyKeyPatterns {
}
```

  /// 방법 1: 앱 시작 시 사전 등록 + 해결
  /// 방법 2: Factory 지연 초기화 패턴
  /// 방법 3: Task 기반 비동기 등록 패턴
안전한 DependencyKey 등록을 위한 헬퍼

```swift
public enum SafeDependencyRegister {
}
```

  /// 앱 시작 시 DependencyKey용 의존성 등록
  /// KeyPath로 안전하게 의존성 해결
  /// KeyPath로 의존성 해결 (기본값 포함)
  /// DependencyKey 지원을 위한 안전한 resolver

```swift
public enum DependencyKeyMigrationGuide {
  public static func printMigrationSteps() {
    #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                    🔄 DEPENDENCYKEY MIGRATION GUIDE                          ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ ❌ BEFORE (문제가 있는 패턴):                                                ║
        ║ ─────────────────────────────────                                           ║
        ║                                                                               ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║   public static var liveValue: BookListInterface = {                        ║
        ║     let repository = SimpleKeyPathRegistry.register(\\.bookListInterface) {      ║
        ║       BookListRepositoryImpl()                                               ║
        ║     }                                                                        ║
        ║     return BookListUseCaseImpl(repository: repository as! BookListInterface) ║
        ║   }()                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 🚨 문제점:                                                                   ║
        ║ • MainActor 격리 위반                                                        ║
        ║ • 등록과 사용의 혼동 (register는 등록용, 값 반환용 아님)                    ║
        ║ • 강제 캐스팅 위험                                                           ║
        ║ • Static 초기화에서 비동기 작업 불가                                         ║
        ║                                                                               ║
        ║ ✅ AFTER (안전한 패턴):                                                     ║
        ║ ────────────────────────                                                     ║
        ║                                                                               ║
        ║ // 1. AppDelegate에서 사전 등록                                              ║
        ║ func setupDependencies() {                                                   ║
        ║   SimpleKeyPathRegistry.register(\\.bookListInterface) {                         ║
        ║     BookListRepositoryImpl()                                                 ║
        ║   }                                                                          ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 2. DependencyKey에서 안전한 해결                                          ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║   public static var liveValue: BookListInterface = {                        ║
        ║     return SafeDependencyRegister.resolveWithFallback(                      ║
        ║       \\.bookListInterface,                                                  ║
        ║       fallback: DefaultBookListRepositoryImpl()                             ║
        ║     )                                                                        ║
        ║   }()                                                                        ║
        ║                                                                               ║
        ║   public static var testValue: BookListInterface =                          ║
        ║     DefaultBookListRepositoryImpl()                                          ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 💡 핵심 원칙:                                                               ║
        ║ • 등록은 앱 시작 시 (AppDelegate/App.swift)                                  ║
        ║ • 사용은 필요한 곳에서 (ViewController/ViewModel)                            ║
        ║ • DependencyKey는 이미 등록된 것을 해결만                                    ║
        ║ • 항상 fallback 제공으로 안전성 확보                                        ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
  }
}
```

