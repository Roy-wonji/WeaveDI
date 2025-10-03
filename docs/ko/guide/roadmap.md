# WeaveDI 로드맵

이 문서는 WeaveDI의 미래 개발 계획, 예정된 기능, 그리고 장기 비전을 설명합니다. WeaveDI를 Swift에서 가장 강력하고 효율적이며 개발자 친화적인 의존성 주입 프레임워크로 만들기 위해 노력하고 있습니다.

## 버전 기록 및 현재 상태

### 현재 버전: 3.2.0 ✅ (2025년 10월 1일 출시)

**출시된 기능:**
- ✅ 엄격한 동시성을 포함한 Swift 6.0 완전 호환
- ✅ `@DIContainerActor`를 통한 Actor 인식 의존성 주입
- ✅ **@Injected Property Wrapper** - TCA 스타일 의존성 주입
- ✅ **AppDI 간소화** - `AppDIManager`를 통한 간소화된 앱 초기화
- ✅ TypeID와 락-프리 읽기를 통한 런타임 최적화
- ✅ 자동 성능 모니터링 및 최적화 제안
- ✅ TCA (The Composable Architecture) 통합
- ✅ 다중 스코프 의존성 관리
- ✅ 포괄적인 테스팅 유틸리티
- ✅ 다국어 문서화 (영어 & 한국어)

**지원 중단:**
- ⚠️ `@Injected` - 4.0.0에서 제거 예정 (`@Injected` 사용)
- ⚠️ `@SafeInject` - 4.0.0에서 제거 예정 (`@Injected` 사용)

**성능 지표:**
- ⚡ v2.x 대비 50-80% 빠른 의존성 해결
- 🧠 멀티스레드 시나리오에서 2-3배 향상된 메모리 효율성
- 🔧 최적화된 빌드에서 제로 코스트 추상화

## 예정된 릴리스

### 버전 3.3.0 🚧 (2026년 Q1)

**초점: 개발자 도구 및 시각화**

#### 새로운 기능
- 🔧 **WeaveDI Inspector**: SwiftUI 오버레이를 포함한 시각적 의존성 그래프 분석 도구
- 📊 **향상된 Performance Profiler**: 실시간 DI 성능 모니터링 대시보드
- 🎯 **Smart Code Completion**: 향상된 Xcode 통합
- 📝 **자동 생성 문서**: 코드로부터 의존성 문서 생성

#### 개선사항
- 🚀 **향상된 @Factory**: 파라미터를 지원하는 복잡한 팩토리 패턴
- 🔍 **더 나은 오류 메시지**: 더 설명적인 런타임 오류 보고
- 🧪 **테스팅 개선**: 간소화된 모킹 주입 패턴
- ⚙️ **빌드 타임 검증**: 컴파일 타임 의존성 검증

#### 코드 예제 (미리보기)

```swift
// WeaveDI Inspector 통합
#if DEBUG
import WeaveDIInspector

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .weaveDIInspector() // 시각적 의존성 그래프 오버레이
        }
    }
}
#endif

// 향상된 @Factory (예정)
@Factory(.parameters(userId: String.self, theme: Theme.self))
var userProfileService: UserProfileService
```

### 버전 3.4.0 📋 (2026년 Q2)

**초점: 고급 아키텍처 패턴**

#### 주요 기능
- 🏗️ **모듈 시스템 2.0**: 향상된 모듈식 아키텍처 지원
- 🔄 **의존성 스코프**: 요청, 세션, 커스텀 스코프 관리
- 🎭 **인터페이스 분리**: 자동 프로토콜 기반 의존성 주입
- 🌐 **분산 의존성**: 원격 서비스 주입 지원

#### 새로운 아키텍처 패턴

```swift
// 모듈 시스템 2.0
@Module
struct UserModule {
    @Provides
    func userService() -> UserService {
        UserServiceImpl()
    }

    @Provides @Singleton
    func userRepository(@Injected networkService: NetworkService) -> UserRepository {
        CoreDataUserRepository(networkService: networkService)
    }
}

// 고급 스코프
@RequestScoped
class RequestHandler {
    @Injected var requestId: RequestID  // 요청별 고유
    @Injected var userContext: UserContext  // 요청 스코프
}

// 분산 의존성
@RemoteService("user-service")
var remoteUserService: UserService?  // 마이크로서비스에서 주입
```

### 버전 3.4.0 🎯 (2025년 Q3)

**초점: 엔터프라이즈 및 프로덕션 기능**

#### 엔터프라이즈 기능
- 🏢 **Enterprise Container**: 멀티 테넌트 의존성 격리
- 📈 **메트릭 및 모니터링**: 프로덕션급 성능 메트릭
- 🔐 **보안**: 의존성 접근 제어 및 검증
- 🔄 **핫 리로딩**: 재시작 없이 런타임 의존성 업데이트

#### 프로덕션 최적화

```swift
// 엔터프라이즈 컨테이너
@Enterprise
class MultiTenantApp {
    @TenantIsolated
    @Injected var tenantService: TenantService?  // 테넌트별 격리

    @Shared
    @Injected var sharedCache: CacheService?  // 테넌트 간 공유
}

// 핫 리로딩 (개발)
#if DEBUG
WeaveDI.enableHotReloading { newDependencies in
    // 앱 재시작 없이 의존성 업데이트
    print("🔄 \(newDependencies.count)개의 의존성을 다시 로드했습니다")
}
#endif

// 프로덕션 메트릭
ProductionMetrics.configure {
    reportDependencyResolutionTimes(threshold: .milliseconds(10))
    alertOnMissingDependencies()
    trackMemoryUsage(interval: .minutes(5))
}
```

## 장기 비전 (2025-2026)

### 버전 4.0.0 🌟 (2025년 Q4)

**혁신적인 기능:**

#### 🤖 AI 기반 의존성 관리
- **자동 의존성 발견**: AI가 누락된 의존성을 제안
- **성능 최적화**: ML 기반 최적화 권장사항
- **코드 생성**: DI 보일러플레이트 코드 자동 생성
- **테스팅**: AI 생성 테스트 시나리오 및 모킹

#### 🔮 예측적 성능
- **사용 예측**: 사용 패턴 기반 의존성 사전 로드
- **메모리 최적화**: 의존성 예측적 가비지 컬렉션
- **로드 밸런싱**: 다중 컨테이너 간 자동 로드 분산

#### 🌈 차세대 개발자 경험
- **비주얼 프로그래밍**: 드래그 앤 드롭 의존성 그래프 빌더
- **실시간 협업**: 팀 기반 의존성 관리
- **통합 디버깅**: 의존성 해결 과정 단계별 디버깅

### 미래 탐구 (2026+)

#### 크로스 플랫폼 확장
- 🖥️ **macOS**: AppKit 통합을 통한 네이티브 macOS 앱 지원
- ⌚ **watchOS**: 워치 컴플리케이션과 백그라운드 작업에 최적화
- 📺 **tvOS**: 메모리 효율적인 TV 앱 아키텍처에 초점
- 🐧 **Swift on Server**: Linux 서버사이드 Swift 지원

#### 고급 언어 기능
- 🎭 **Swift Macros 2.0**: 차세대 매크로 시스템 통합
- 🔗 **Property Wrappers 3.0**: 향상된 프로퍼티 래퍼 기능
- ⚡ **Concurrency Evolution**: 미래 Swift 동시성 기능 통합

## 커뮤니티 및 생태계

### 계획된 통합

#### UI 프레임워크
- ✅ **SwiftUI**: 완전한 통합 (현재)
- ✅ **TCA**: 포괄적인 지원 (v3.1.0)
- 🔄 **UIKit**: 향상된 통합 (v3.2.0)
- 📋 **Vapor**: 서버사이드 Swift 지원 (v3.3.0)

#### 테스팅 프레임워크
- ✅ **XCTest**: 네이티브 지원 (현재)
- 📋 **Quick/Nimble**: 일급 통합 (v3.2.0)
- 📋 **SwiftTesting**: 새로운 Swift 테스팅 프레임워크 지원 (v3.3.0)

#### 빌드 도구 및 CI/CD
- 🔧 **Xcode Cloud**: 향상된 통합
- 📋 **GitHub Actions**: WeaveDI 프로젝트용 사전 빌드 워크플로
- 📋 **Fastlane**: 배포 시 자동 의존성 검증
- 🔧 **SwiftPM**: 고급 패키지 관리 기능

### 커뮤니티 기능

#### 문서화 및 학습
- 📚 **인터랙티브 튜토리얼**: 단계별 학습 경로
- 🎥 **비디오 코스**: 포괄적인 WeaveDI 마스터리 코스
- 📖 **모범 사례 가이드**: 실제 아키텍처 패턴
- 🌍 **다국어 문서**: 더 많은 언어 지원

#### 개발자 도구
- 🔧 **Xcode Extensions**: 향상된 IDE 통합
- 📱 **WeaveDI Studio**: 독립형 의존성 관리 도구
- 🌐 **Web Dashboard**: 클라우드 기반 프로젝트 분석
- 📊 **Dependency Analyzer**: 정적 분석 및 보고

## 기술 로드맵

### 성능 개선

#### 현재 벤치마크 (v3.1.0)
```
의존성 해결:
- 간단한 해결: ~0.01ms (v2.x 대비 50-80% 빠름)
- 복잡한 그래프: ~0.05ms (20-40% 개선)
- 동시 접근: 2-3배 빠름 (락-프리 읽기)

메모리 사용량:
- 메모리 사용량: v2.x 대비 60% 감소
- 가비지 컬렉션: 40% 적은 빈도
- 피크 메모리: 대형 앱에서 30% 감소
```

#### 목표 벤치마크 (v4.0.0)
```
의존성 해결:
- 간단한 해결: ~0.005ms (v3.1.0 대비 2배 빠름)
- 복잡한 그래프: ~0.02ms (2.5배 개선)
- 예측적 로딩: 거의 제로 해결 시간

메모리 사용량:
- 메모리 사용량: v2.x 대비 80% 감소
- 제로 카피 의존성 공유
- 예측적 메모리 관리
```

### Swift 언어 진화

#### Swift 6.x 기능
- ✅ **Strict Concurrency**: 완전한 준수 (v3.1.0)
- 📋 **향상된 매크로**: 고급 매크로 기능 (v3.2.0)
- 📋 **Typed Throws**: 더 나은 에러 처리 (v3.3.0)
- 🔮 **Region-based Memory**: 메모리 안전성 개선 (v4.0.0)

#### 미래 Swift 기능
- 🔮 **소유권 시스템**: 제로 카피 의존성 주입
- 🔮 **이펙트 시스템**: 함수형 이펙트 통합
- 🔮 **분산 액터**: 네이티브 원격 의존성 지원

## 주요 변경사항 및 마이그레이션

### 버전 3.x → 4.0.0 마이그레이션

#### 폐기된 API (v4.0.0에서 제거 예정)
```swift
// ❌ v3.2.0에서 폐기, v4.0.0에서 제거
UnifiedDI.register(SomeService.self) { SomeServiceImpl() }

// ✅ v4.0.0의 새로운 문법
@Provides
func someService() -> SomeService { SomeServiceImpl() }
```

#### 마이그레이션 타임라인
- **v3.2.0**: 폐기 경고 도입
- **v3.3.0**: 마이그레이션 도구 제공
- **v3.4.0**: v4.0.0 이전 최종 경고
- **v4.0.0**: 주요 변경사항과 함께 새로운 시작

## 기능 요청 및 피드백

WeaveDI의 미래를 형성하는 데 커뮤니티의 의견을 중요하게 생각합니다. 기여 방법:

### 기능 요청 방법

1. 📋 **GitHub Issues**: 상세한 사용 사례와 함께 기능 요청 생성
2. 💬 **Discussions**: 진행 중인 아키텍처 토론 참여
3. 🗳️ **기능 투표**: 커뮤니티 제안 기능에 투표
4. 🎯 **RFC 프로세스**: 공식 Request for Comments 제출

### 우선순위 결정 과정

**높은 우선순위:**
- 개발자 경험 개선
- 성능 최적화
- Swift 진화 호환성
- 중요한 버그 수정

**중간 우선순위:**
- 새로운 아키텍처 패턴
- 고급 도구 기능
- 커뮤니티 요청 통합
- 문서 향상

**낮은 우선순위:**
- 실험적 기능
- 틈새 사용 사례
- 플랫폼별 최적화
- 레거시 호환성

## 참여하기

### 기여 기회

#### 코드 기여
- 🐛 **버그 수정**: 안정성 향상에 도움
- ⚡ **성능**: 중요한 경로 최적화
- 🆕 **기능**: 로드맵 항목 구현
- 🧪 **테스트**: 테스트 커버리지 확장

#### 문서 및 커뮤니티
- 📚 **문서**: 가이드 및 튜토리얼 개선
- 🌍 **번역**: 더 많은 언어로 문서 번역 도움
- 🎥 **콘텐츠 제작**: 튜토리얼 및 예제 생성
- 💬 **커뮤니티 지원**: 다른 개발자 도움

#### 테스팅 및 피드백
- 🧪 **베타 테스팅**: 프리릴리스 버전 테스트
- 📊 **성능 테스팅**: 개선사항 벤치마크 도움
- 🐛 **버그 리포트**: 상세한 재현과 함께 이슈 보고
- 💡 **기능 피드백**: 제안된 기능에 대한 생각 공유

### 기여 방법

1. **Repository Fork**: [WeaveDI GitHub](https://github.com/Roy-wonji/WeaveDI)
2. **기여 가이드 읽기**: 기여 가이드라인 따르기
3. **토론 참여**: 기능 계획에 참여
4. **PR 제출**: 코드 개선사항 기여

## 타임라인 요약

| 버전 | 출시일 | 초점 | 주요 기능 |
|------|--------|------|----------|
| **v3.2.0** | ✅ 2025년 10월 1일 | TCA 스타일 DI | @Injected, AppDI 간소화 |
| **v3.1.0** | 2025년 9월 27일 | 성능 | 런타임 최적화, Lock-free |
| **v3.3.0** | 2026년 Q1 | 개발자 도구 | Inspector, 향상된 프로파일러 |
| **v3.4.0** | 2026년 Q2 | 아키텍처 | 모듈 시스템 2.0, 스코프 |
| **v4.0.0** | 2026년 Q4 | 주요 변경 | @Injected, @SafeInject 제거 |

---

**Swift에서 의존성 주입의 미래를 함께 만들어가세요!**

이 로드맵에 대한 질문, 제안, 토론:
- 📧 이메일: [suhwj81@gmail.com](mailto:suhwj81@gmail.com)
- 🐙 GitHub: [Roy-wonji/WeaveDI](https://github.com/Roy-wonji/WeaveDI)
- 💬 토론: [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)