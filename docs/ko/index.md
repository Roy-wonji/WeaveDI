---
layout: home

hero:
  name: "WeaveDI"
  text: "Swift를 위한 현대적 의존성 주입"
  tagline: Swift Concurrency 지원을 갖춘 고성능 DI 프레임워크
  image:
    src: /logo.svg
    alt: WeaveDI
  actions:
    - theme: brand
      text: 시작하기
      link: /ko/guide/quickStart
    - theme: alt
      text: GitHub 보기
      link: https://github.com/Roy-wonji/WeaveDI

features:
  - icon: 🚀
    title: 런타임 핫패스 최적화
    details: TypeID + 락-프리 읽기로 50-80% 성능 향상. 번개같이 빠른 의존성 해결.
    link: ko/guide/runtimeOptimization
  - icon: 🎭
    title: Actor Hop 최적화
    details: 서로 다른 Actor 컨텍스트 간 전환을 지능적으로 최적화하여 최대 성능 달성.
    link: ko/guide/diActor
  - icon: 🔒
    title: 완전한 타입 안전성
    details: KeyPath 기반 등록과 강력한 타입 추론으로 컴파일 타임 검증 제공.
    link: ko/guide/unifiedDi
  - icon: 📝
    title: 직관적인 Property Wrapper
    details: "@Inject, @Factory, @SafeInject - 간단하고 강력한 의존성 주입 패턴."
    link: ko/guide/propertyWrappers
  - icon: 🏗️
    title: 강력한 모듈 시스템
    details: 확장 가능한 의존성 관리를 위한 AppDIContainer, ModuleFactory, Container.
    link: ko/guide/moduleSystem
  - icon: 🧪
    title: 테스트 친화적 설계
    details: 쉬운 모킹, 격리된 테스트, 신뢰할 수 있는 테스트를 위한 부트스트랩 리셋.
    link: ko/guide/bootstrap
---

## 빠른 예제

```swift
import WeaveDI

// 1. 앱 시작 시 의존성 부트스트랩
await DependencyContainer.bootstrap { container in
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    container.register(\.userRepository) {
        UserRepositoryImpl()
    }
}

// 2. 주입을 위한 프로퍼티 래퍼 사용
class ViewController {
    @Inject var userService: UserServiceProtocol?
    @Factory var dataProcessor: DataProcessor

    func loadUserData() async {
        guard let service = userService else { return }
        let userData = await service.fetchUser()
        updateUI(with: userData)
    }
}

// 3. 현대적인 async/await 지원
let userService = await UnifiedDI.resolve(UserService.self)
let userData = await userService?.fetchUserData()
```

## 성능 지표

| 시나리오 | 기존 DI | WeaveDI 3.2 | 개선율 |
|---------|--------|-------------|--------|
| 단일 의존성 해결 | 0.8ms | 0.2ms | **75%** |
| 복잡한 의존성 그래프 | 15.6ms | 3.1ms | **80%** |
| MainActor UI 업데이트 | 3.1ms | 0.6ms | **81%** |

## 왜 WeaveDI인가?

WeaveDI 3.1.0는 다음을 제공하는 현대적인 Swift 애플리케이션을 위해 설계되었습니다:

- **iOS 15.0+, macOS 14.0+, watchOS 8.0+, tvOS 15.0+** 지원
- **Swift Concurrency** 일급 통합
- **Actor 모델** 최적화
- 릴리스 빌드에서 **제로 비용 추상화**
- **포괄적인 테스팅** 지원

*Swift 개발자를 위한 프레임워크*