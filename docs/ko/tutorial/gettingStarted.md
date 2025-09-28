# WeaveDI 시작하기

단계별로 첫 번째 iOS 앱을 WeaveDI로 구축해보세요. 이 튜토리얼은 실제 WeaveDI API를 기반으로 작성되었습니다.

## 🎯 만들어볼 것

간단한 사용자 프로필 앱을 만들어보며 다음을 배웁니다:
- 기본 의존성 등록과 해결
- Property wrapper 주입
- WeaveDI와 Swift Concurrency
- 의존성 주입으로 테스트하기

## 📱 프로젝트 설정

### 1. 새 iOS 프로젝트 만들기

```bash
# Xcode에서 새 iOS 프로젝트 생성
# File → New → Project → iOS → App
# 이름: UserProfileApp
```

### 2. WeaveDI 패키지 추가

```swift
// Package.swift 또는 Xcode Package Manager에서
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

### 3. WeaveDI import

```swift
import WeaveDI
```

## 🏗️ 1단계: 모델 정의하기

먼저 데이터 모델을 정의합니다:

```swift
// Models/User.swift
import Foundation

/// 사용자 정보를 담는 구조체
/// Sendable을 준수하여 Swift Concurrency에서 안전하게 사용 가능
struct User: Codable, Sendable {
    let id: String          // 고유 식별자
    let name: String        // 사용자 이름
    let email: String       // 이메일 주소
    let avatarURL: URL?     // 프로필 이미지 URL (선택적)

    /// 편리한 초기화 메서드
    /// - Parameters:
    ///   - id: 사용자 고유 ID
    ///   - name: 사용자 이름
    ///   - email: 이메일 주소
    ///   - avatarURL: 프로필 이미지 URL (기본값: nil)
    init(id: String, name: String, email: String, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
    }
}

/// 네트워크 관련 오류 정의
/// Error 프로토콜을 준수하여 Swift 오류 처리 시스템에서 사용
enum NetworkError: Error {
    case invalidURL         // 잘못된 URL
    case noData            // 데이터 없음
    case decodingError     // JSON 디코딩 실패

    /// 사용자에게 표시할 오류 메시지
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다"
        case .noData:
            return "데이터를 찾을 수 없습니다"
        case .decodingError:
            return "데이터 변환에 실패했습니다"
        }
    }
}
```

## 🔧 2단계: 서비스 프로토콜 만들기

서비스들의 계약을 정의합니다:

```swift
// Services/UserService.swift
import Foundation

/// 사용자 관련 작업을 위한 프로토콜
/// Sendable을 준수하여 Actor 간 안전한 전달 보장
protocol UserService: Sendable {
    /// 사용자 ID로 사용자 정보를 가져옵니다
    /// - Parameter id: 조회할 사용자 ID
    /// - Returns: 사용자 정보
    /// - Throws: 네트워크 오류 또는 데이터 오류
    func fetchUser(id: String) async throws -> User

    /// 사용자 정보를 업데이트합니다
    /// - Parameter user: 업데이트할 사용자 정보
    /// - Throws: 네트워크 오류 또는 권한 오류
    func updateUser(_ user: User) async throws

    /// 사용자 계정을 삭제합니다
    /// - Parameter id: 삭제할 사용자 ID
    /// - Throws: 네트워크 오류 또는 권한 오류
    func deleteUser(id: String) async throws
}

/// 네트워크 작업을 위한 프로토콜
/// HTTP 요청을 추상화하여 테스트와 실제 구현을 분리
protocol NetworkService: Sendable {
    /// 지정된 URL에서 데이터를 가져옵니다
    /// - Parameter url: 요청할 URL
    /// - Returns: 응답 데이터
    /// - Throws: 네트워크 오류
    func fetchData(from url: URL) async throws -> Data

    /// 지정된 URL로 데이터를 전송합니다
    /// - Parameters:
    ///   - data: 전송할 데이터
    ///   - url: 대상 URL
    /// - Returns: 응답 데이터
    /// - Throws: 네트워크 오류
    func postData(_ data: Data, to url: URL) async throws -> Data
}

/// 로컬 캐시를 위한 프로토콜
/// 메모리 캐시를 통해 네트워크 요청을 줄이고 성능 향상
protocol CacheService: Sendable {
    /// 캐시에서 사용자 정보를 가져옵니다
    /// - Parameter id: 사용자 ID
    /// - Returns: 캐시된 사용자 정보 (없으면 nil)
    func getUser(id: String) -> User?

    /// 사용자 정보를 캐시에 저장합니다
    /// - Parameters:
    ///   - user: 저장할 사용자 정보
    ///   - id: 사용자 ID (키로 사용)
    func setUser(_ user: User, id: String)

    /// 캐시에서 사용자 정보를 제거합니다
    /// - Parameter id: 제거할 사용자 ID
    func removeUser(id: String)

    /// 모든 캐시를 지웁니다
    func clearAll()
}
```

## 🛠️ 3단계: 서비스 구현하기 (실제 WeaveDI 패턴)

이제 실제 WeaveDI 패턴을 사용해서 서비스들을 구현합니다:

```swift
// Services/UserServiceImpl.swift
import Foundation
import WeaveDI

/// UserService의 실제 구현
/// WeaveDI의 실제 @Inject property wrapper를 사용
class UserServiceImpl: UserService {
    // 🔍 실제 WeaveDI 소스 코드의 @Inject 사용
    // PropertyWrappers.swift에서 구현된 실제 property wrapper
    @Inject var networkService: NetworkService?    // 네트워크 서비스 (옵셔널)
    @Inject var cacheService: CacheService?        // 캐시 서비스 (옵셔널)

    func fetchUser(id: String) async throws -> User {
        print("🔍 사용자 조회 시작: \(id)")

        // 1단계: 캐시를 먼저 확인 (성능 최적화)
        // 캐시에 있으면 네트워크 요청 없이 즉시 반환
        if let cachedUser = cacheService?.getUser(id: id) {
            print("✅ 캐시에서 사용자 발견: \(cachedUser.name)")
            return cachedUser
        }

        // 2단계: 네트워크에서 가져오기
        // @Inject로 주입된 networkService가 없으면 오류 반환
        guard let network = networkService else {
            print("❌ NetworkService가 주입되지 않았습니다")
            throw NetworkError.noData
        }

        // 실제 API 호출 시뮬레이션
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let data = try await network.fetchData(from: url)

        // 3단계: JSON 파싱 및 캐시 저장
        // 네트워크에서 받은 데이터를 User 객체로 변환
        let user = try JSONDecoder().decode(User.self, from: data)

        // 다음번을 위해 캐시에 저장
        cacheService?.setUser(user, id: id)

        print("🌐 네트워크에서 사용자 가져옴: \(user.name)")
        return user
    }

    func updateUser(_ user: User) async throws {
        print("📝 사용자 정보 업데이트: \(user.name)")

        // 네트워크 서비스가 필요합니다
        guard let network = networkService else {
            throw NetworkError.noData
        }

        // 사용자 정보를 JSON으로 변환
        let url = URL(string: "https://api.example.com/users/\(user.id)")!
        let userData = try JSONEncoder().encode(user)

        // 서버에 업데이트 요청
        _ = try await network.postData(userData, to: url)

        // 캐시도 업데이트
        cacheService?.setUser(user, id: user.id)
        print("✅ 사용자 업데이트 완료: \(user.name)")
    }

    func deleteUser(id: String) async throws {
        print("🗑️ 사용자 삭제: \(id)")

        // 삭제 구현 (실제로는 네트워크 요청이 필요)
        cacheService?.removeUser(id: id)
        print("✅ 사용자 삭제 완료: \(id)")
    }
}
```

```swift
// Services/NetworkServiceImpl.swift
import Foundation

/// NetworkService의 실제 구현
/// URLSession을 사용한 실제 네트워크 통신
class NetworkServiceImpl: NetworkService {
    /// URLSession 인스턴스 (시스템 기본값 사용)
    private let session = URLSession.shared

    func fetchData(from url: URL) async throws -> Data {
        print("🌐 데이터 요청: \(url)")

        // 데모용 네트워크 지연 시뮬레이션
        // 실제 네트워크 요청의 느린 속도를 재현
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5초

        // 데모 목적으로 모의 데이터 반환
        // 실제 앱에서는 진짜 네트워크 요청을 수행:
        // let (data, _) = try await session.data(from: url)
        let mockUser = User(
            id: UUID().uuidString,
            name: "홍길동",
            email: "hong@example.com",
            avatarURL: URL(string: "https://avatar.example.com/hong.jpg")
        )

        return try JSONEncoder().encode(mockUser)
    }

    func postData(_ data: Data, to url: URL) async throws -> Data {
        print("📤 데이터 전송: \(url)")

        // 네트워크 요청 시뮬레이션
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3초

        // 성공 응답 시뮬레이션
        // 실제로는: let (responseData, _) = try await session.upload(for: request)
        return Data() // 빈 성공 응답
    }
}
```

```swift
// Services/CacheServiceImpl.swift
import Foundation

/// CacheService의 실제 구현
/// 메모리 기반 캐시 시스템
class CacheServiceImpl: CacheService {
    /// 사용자 데이터를 저장하는 딕셔너리
    /// [사용자ID: 사용자정보] 형태로 저장
    private var cache: [String: User] = [:]

    /// 동시 접근을 안전하게 처리하기 위한 큐
    /// concurrent: 읽기는 동시에, 쓰기는 배타적으로 처리
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)

    func getUser(id: String) -> User? {
        // 읽기 작업은 동시에 수행 가능 (성능 최적화)
        return queue.sync {
            cache[id]
        }
    }

    func setUser(_ user: User, id: String) {
        // 쓰기 작업은 배타적으로 수행 (데이터 안전성)
        // barrier: 이 작업이 실행될 때 다른 모든 작업이 대기
        queue.async(flags: .barrier) {
            self.cache[id] = user
        }
        print("💾 사용자 캐시됨: \(user.name)")
    }

    func removeUser(id: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: id)
        }
        print("🗑️ 캐시에서 사용자 제거: \(id)")
    }

    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
        print("🧹 모든 캐시 삭제")
    }
}
```

## 📱 4단계: ViewModel 만들기 (실제 WeaveDI API 사용)

```swift
// ViewModels/UserProfileViewModel.swift
import Foundation
import SwiftUI
import WeaveDI

/// 사용자 프로필 화면의 뷰모델
/// @MainActor로 UI 업데이트를 메인 스레드에서 안전하게 처리
@MainActor
class UserProfileViewModel: ObservableObject {
    // 🔍 실제 WeaveDI property wrapper 사용
    @Inject var userService: UserService?

    // SwiftUI에서 UI 업데이트를 위한 @Published 프로퍼티들
    @Published var user: User?                    // 현재 사용자 정보
    @Published var isLoading = false              // 로딩 상태
    @Published var errorMessage: String?          // 오류 메시지

    /// 사용자 프로필을 로드합니다
    /// - Parameter id: 로드할 사용자 ID
    func loadUser(id: String) async {
        print("📱 ViewModel: 사용자 로드 시작 \(id)")

        // UI 상태 업데이트: 로딩 시작
        isLoading = true
        errorMessage = nil

        do {
            // WeaveDI로 주입된 서비스 확인
            guard let service = userService else {
                throw NetworkError.noData
            }

            // 실제 사용자 데이터 로드
            // 이 과정에서 네트워크 요청과 캐시 확인이 자동으로 처리됨
            let loadedUser = try await service.fetchUser(id: id)

            // UI 업데이트: 성공적으로 로드된 사용자 정보 표시
            self.user = loadedUser

        } catch {
            // UI 업데이트: 오류 메시지 표시
            self.errorMessage = error.localizedDescription
            print("❌ 사용자 로드 오류: \(error)")
        }

        // UI 상태 업데이트: 로딩 완료
        isLoading = false
    }

    /// 사용자 프로필을 업데이트합니다
    /// - Parameter updatedUser: 업데이트할 사용자 정보
    func updateUser(_ updatedUser: User) async {
        guard let service = userService else { return }

        do {
            try await service.updateUser(updatedUser)
            // 성공 시 로컬 상태도 업데이트
            self.user = updatedUser
        } catch {
            // 오류 시 사용자에게 알림
            self.errorMessage = error.localizedDescription
        }
    }

    /// 현재 사용자 정보를 새로고침합니다
    func refresh() async {
        guard let currentUser = user else { return }
        await loadUser(id: currentUser.id)
    }
}
```

## 🎨 5단계: SwiftUI 뷰 만들기

```swift
// Views/UserProfileView.swift
import SwiftUI

/// 사용자 프로필을 표시하는 메인 뷰
struct UserProfileView: View {
    /// ViewModel 인스턴스 (WeaveDI가 자동으로 의존성 주입)
    @StateObject private var viewModel = UserProfileViewModel()

    /// 표시할 사용자 ID
    let userId: String

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 로딩 상태에 따른 조건부 UI 렌더링
                if viewModel.isLoading {
                    // 로딩 중일 때: 스피너와 메시지 표시
                    ProgressView("사용자 정보 로딩 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = viewModel.user {
                    // 성공적으로 로드되었을 때: 사용자 상세 정보 표시
                    UserDetailView(user: user) {
                        // 새로고침 버튼 동작
                        Task {
                            await viewModel.refresh()
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    // 오류가 발생했을 때: 오류 메시지와 재시도 버튼 표시
                    ErrorView(message: errorMessage) {
                        // 재시도 버튼 동작
                        Task {
                            await viewModel.loadUser(id: userId)
                        }
                    }
                } else {
                    // 초기 상태: 데이터 없음 메시지
                    Text("사용자 데이터 없음")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("사용자 프로필")
            .task {
                // 뷰가 나타날 때 자동으로 사용자 정보 로드
                await viewModel.loadUser(id: userId)
            }
        }
    }
}

/// 사용자 상세 정보를 표시하는 뷰
struct UserDetailView: View {
    let user: User                      // 표시할 사용자 정보
    let onRefresh: () -> Void          // 새로고침 콜백

    var body: some View {
        VStack(spacing: 16) {
            // 프로필 이미지 (비동기 로딩)
            AsyncImage(url: user.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                // 이미지 로딩 중 또는 없을 때 기본 아이콘
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            // 사용자 이름 (굵은 글씨)
            Text(user.name)
                .font(.title2)
                .fontWeight(.bold)

            // 이메일 주소 (부가 정보 스타일)
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 새로고침 버튼
            Button("새로고침", action: onRefresh)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// 오류 상황을 표시하는 뷰
struct ErrorView: View {
    let message: String                 // 표시할 오류 메시지
    let onRetry: () -> Void            // 재시도 콜백

    var body: some View {
        VStack(spacing: 16) {
            // 경고 아이콘
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            // 오류 제목
            Text("오류 발생")
                .font(.title2)
                .fontWeight(.bold)

            // 구체적인 오류 메시지
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // 재시도 버튼 (눈에 띄는 스타일)
            Button("다시 시도", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## ⚙️ 6단계: 의존성 부트스트랩 (실제 WeaveDI 부트스트랩)

여기가 실제 WeaveDI API를 사용하는 핵심 부분입니다:

```swift
// App/UserProfileApp.swift
import SwiftUI
import WeaveDI

@main
struct UserProfileApp: App {

    init() {
        // 앱 시작 시 의존성 설정
        Task {
            await configureDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            UserProfileView(userId: "user123")
        }
    }

    /// 실제 WeaveDI bootstrap을 사용한 의존성 설정
    /// 이 메서드는 WeaveDI 소스 코드의 실제 API를 사용합니다
    private func configureDependencies() async {
        print("🚀 앱 의존성 설정 시작...")

        // 🔍 실제 DependencyContainer.bootstrap 사용
        // 이는 WeaveDI 소스코드의 DIContainer.swift에서 구현된 실제 메서드입니다
        await DependencyContainer.bootstrap { container in

            // 1. 네트워크 서비스 등록
            // 실제 네트워크 통신을 담당하는 서비스
            container.register(NetworkService.self) {
                print("📦 NetworkService 생성")
                return NetworkServiceImpl()
            }

            // 2. 캐시 서비스 등록
            // 메모리 캐시를 담당하는 서비스
            container.register(CacheService.self) {
                print("📦 CacheService 생성")
                return CacheServiceImpl()
            }

            // 3. 사용자 서비스 등록 (다른 서비스들에 의존)
            // UserServiceImpl은 @Inject를 통해 자동으로 의존성이 주입됩니다
            container.register(UserService.self) {
                print("📦 UserService 생성")
                return UserServiceImpl()
            }
        }

        print("✅ 모든 의존성 설정 완료")
    }
}
```

## 🧪 7단계: 테스트 추가 (실제 WeaveDI 테스팅 패턴)

```swift
// Tests/UserServiceTests.swift
import XCTest
@testable import UserProfileApp
import WeaveDI

final class UserServiceTests: XCTestCase {

    override func setUp() async throws {
        await super.setUp()

        // 🔍 실제 WeaveDI API를 사용한 테스트 환경 설정
        // 각 테스트마다 깨끗한 상태로 시작
        await DependencyContainer.bootstrap { container in
            // 테스트용 모의 서비스들 등록
            container.register(NetworkService.self) {
                MockNetworkService()
            }

            container.register(CacheService.self) {
                MockCacheService()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }

    func testFetchUser_성공() async throws {
        // Given: 테스트 준비
        // 실제 UnifiedDI.resolve를 사용해서 서비스 가져오기
        let userService: UserService = UnifiedDI.resolve(UserService.self)!

        // When: 테스트 실행
        let user = try await userService.fetchUser(id: "test123")

        // Then: 결과 검증
        XCTAssertEqual(user.id, "test123")
        XCTAssertFalse(user.name.isEmpty)
        print("✅ 사용자 가져오기 테스트 성공")
    }

    func testFetchUser_캐시히트() async throws {
        // Given: 캐시에 사용자 미리 저장
        let userService: UserService = UnifiedDI.resolve(UserService.self)!
        let cacheService: CacheService = UnifiedDI.resolve(CacheService.self)!

        let cachedUser = User(id: "cached123", name: "캐시된 사용자", email: "cached@example.com")
        cacheService.setUser(cachedUser, id: "cached123")

        // When: 같은 ID로 사용자 요청
        let user = try await userService.fetchUser(id: "cached123")

        // Then: 캐시된 사용자가 반환되는지 확인
        XCTAssertEqual(user.name, "캐시된 사용자")
        print("✅ 캐시 히트 테스트 성공")
    }
}

// 테스트용 모의 서비스들
class MockNetworkService: NetworkService {
    func fetchData(from url: URL) async throws -> Data {
        // 테스트용 모의 데이터 반환
        let mockUser = User(id: "test123", name: "테스트 사용자", email: "test@example.com")
        return try JSONEncoder().encode(mockUser)
    }

    func postData(_ data: Data, to url: URL) async throws -> Data {
        return Data() // 빈 성공 응답
    }
}

class MockCacheService: CacheService {
    private var cache: [String: User] = [:]

    func getUser(id: String) -> User? { cache[id] }
    func setUser(_ user: User, id: String) { cache[id] = user }
    func removeUser(id: String) { cache.removeValue(forKey: id) }
    func clearAll() { cache.removeAll() }
}
```

## 🎯 핵심 학습 내용

WeaveDI로 완전한 iOS 앱을 만들었습니다! 다음을 배웠습니다:

### ✅ 실제 사용한 WeaveDI 기능들:
1. **@Inject Property Wrapper** - 자동 의존성 주입
2. **DependencyContainer.bootstrap** - 안전한 앱 초기화
3. **UnifiedDI.resolve()** - 깔끔한 의존성 해결
4. **Swift Concurrency 지원** - 네이티브 async/await 통합
5. **테스트 친화적 설계** - 쉬운 모킹과 격리

### 🚀 성능상의 이점:
- **지연 로딩**: 필요할 때만 의존성 생성
- **타입 안전성**: 컴파일 타임 검증
- **Actor 안전성**: 스레드 안전한 작업
- **메모리 효율성**: 최적화된 리소스 사용

### 📈 다음 단계:
- [Property Wrapper 심화](/ko/tutorial/propertyWrappers)
- [Swift Concurrency 통합](/ko/tutorial/concurrencyIntegration)
- [테스팅 전략](/ko/tutorial/testing)

## 🔗 완전한 소스 코드

완전한 프로젝트는 GitHub에서 확인할 수 있습니다: [UserProfileApp 예제](https://github.com/Roy-wonji/WeaveDI/tree/main/Examples/UserProfileApp)

---

**축하합니다!** 실제 프로덕션 패턴을 사용해서 WeaveDI로 첫 번째 앱을 성공적으로 만들었습니다. 이제 깔끔한 아키텍처, 타입 안전한 의존성 주입, 그리고 뛰어난 테스트 가능성을 갖춘 앱이 완성되었습니다.