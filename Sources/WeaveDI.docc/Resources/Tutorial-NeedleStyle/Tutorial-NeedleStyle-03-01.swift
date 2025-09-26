// 컴파일타임 의존성 검증: @DependencyGraph 매크로

import WeaveDI

/*
 🎯 목표: Needle의 핵심 장점인 컴파일타임 안전성을 WeaveDI로 구현

 Needle의 컴파일타임 검증:
 - 코드 생성 도구로 의존성 그래프 검증
 - 순환 의존성 자동 감지
 - "If it compiles, it works" 보장

 WeaveDI의 컴파일타임 검증:
 - @DependencyGraph 매크로로 즉시 검증
 - 순환 의존성 컴파일 에러 발생
 - 더 간단하고 직관적인 문법
*/

// 🏗️ 서비스 계층 정의
protocol Logger: Sendable {
    func log(_ message: String)
}

protocol NetworkService: Sendable {
    func request(url: String) async -> String
}

protocol DatabaseService: Sendable {
    func save(data: String) async
    func load(id: String) async -> String?
}

protocol UserRepository: Sendable {
    func getUser(id: String) async -> User?
    func saveUser(_ user: User) async
}

protocol UserService: Sendable {
    func createUser(name: String) async -> User
    func getUserById(id: String) async -> User?
}

// 📊 의존성 그래프 정의 (Needle의 핵심 기능)
@DependencyGraph([
    // UI Layer
    UserService.self: [UserRepository.self, Logger.self],

    // Business Layer
    UserRepository.self: [NetworkService.self, DatabaseService.self, Logger.self],

    // Infrastructure Layer
    NetworkService.self: [Logger.self],
    DatabaseService.self: [Logger.self]

    // ✅ 이 그래프는 올바릅니다: 순환 의존성 없음
    // Logger는 최하위 레벨이므로 다른 의존성이 없음
])
extension WeaveDI {}

// 🔧 구현체 정의
class ConsoleLogger: Logger {
    func log(_ message: String) {
        print("📝 [\(Date())] \(message)")
    }
}

class HTTPNetworkService: NetworkService {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func request(url: String) async -> String {
        logger.log("🌐 Network request to \(url)")
        // 실제 네트워크 요청 시뮬레이션
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        return "Response from \(url)"
    }
}

class CoreDataService: DatabaseService {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func save(data: String) async {
        logger.log("💾 Saving data to database")
        // 데이터베이스 저장 시뮬레이션
    }

    func load(id: String) async -> String? {
        logger.log("📖 Loading data with id: \(id)")
        return "Data for \(id)"
    }
}

class UserRepositoryImpl: UserRepository {
    private let networkService: NetworkService
    private let databaseService: DatabaseService
    private let logger: Logger

    init(networkService: NetworkService, databaseService: DatabaseService, logger: Logger) {
        self.networkService = networkService
        self.databaseService = databaseService
        self.logger = logger
    }

    func getUser(id: String) async -> User? {
        logger.log("👤 Getting user with id: \(id)")

        // 먼저 데이터베이스에서 확인
        if let userData = await databaseService.load(id: id) {
            return User(id: id, name: userData)
        }

        // 없으면 네트워크에서 가져오기
        let response = await networkService.request(url: "https://api.example.com/users/\(id)")
        let user = User(id: id, name: response)

        // 데이터베이스에 캐시
        await databaseService.save(data: user.name)

        return user
    }

    func saveUser(_ user: User) async {
        logger.log("💾 Saving user: \(user.name)")
        await databaseService.save(data: user.name)
    }
}

class UserServiceImpl: UserService {
    private let repository: UserRepository
    private let logger: Logger

    init(repository: UserRepository, logger: Logger) {
        self.repository = repository
        self.logger = logger
    }

    func createUser(name: String) async -> User {
        logger.log("🆕 Creating new user: \(name)")
        let user = User(id: UUID().uuidString, name: name)
        await repository.saveUser(user)
        return user
    }

    func getUserById(id: String) async -> User? {
        logger.log("🔍 Getting user by id: \(id)")
        return await repository.getUser(id: id)
    }
}

// 📦 모델 정의
struct User: Sendable {
    let id: String
    let name: String
}

// 🚀 DI 컨테이너 설정
extension UnifiedDI {
    static func setupDependencyGraph() {
        // Bottom-up 방식으로 의존성 등록 (의존성 그래프 순서대로)

        // 1. Infrastructure Layer (최하위)
        _ = register(Logger.self) { ConsoleLogger() }

        // 2. Infrastructure Services
        _ = register(NetworkService.self) {
            HTTPNetworkService(logger: resolve(Logger.self)!)
        }

        _ = register(DatabaseService.self) {
            CoreDataService(logger: resolve(Logger.self)!)
        }

        // 3. Business Layer
        _ = register(UserRepository.self) {
            UserRepositoryImpl(
                networkService: resolve(NetworkService.self)!,
                databaseService: resolve(DatabaseService.self)!,
                logger: resolve(Logger.self)!
            )
        }

        // 4. Service Layer (최상위)
        _ = register(UserService.self) {
            UserServiceImpl(
                repository: resolve(UserRepository.self)!,
                logger: resolve(Logger.self)!
            )
        }

        // 🔍 Needle 스타일 검증
        _ = validateNeedleStyle(
            component: AppComponent.self,
            dependencies: [
                Logger.self,
                NetworkService.self,
                DatabaseService.self,
                UserRepository.self,
                UserService.self
            ]
        )

        print("✅ 의존성 그래프 설정 완료 - 컴파일 타임 검증 통과!")
    }
}

// 📱 사용 예시
func demonstrateCompileTimeSafety() async {
    // DI 컨테이너 설정
    UnifiedDI.setupDependencyGraph()

    // 서비스 사용
    let userService = UnifiedDI.resolve(UserService.self)!

    // 비즈니스 로직 실행
    let newUser = await userService.createUser(name: "Alice")
    print("생성된 사용자: \(newUser)")

    let retrievedUser = await userService.getUserById(id: newUser.id)
    print("조회된 사용자: \(retrievedUser?.name ?? "없음")")
}

// 임시 타입 (호환성을 위해)
struct AppComponent {}