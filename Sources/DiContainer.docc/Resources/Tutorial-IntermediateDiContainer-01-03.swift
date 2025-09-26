import Foundation
import DiContainer
import LogMacro

// MARK: - 순환 의존성 감지 및 해결 시스템

/// 복잡한 프로젝트에서 발생할 수 있는 순환 의존성(Circular Dependency) 문제를
/// 감지하고 해결하는 시스템을 구현합니다.

// MARK: - 순환 의존성 감지기

final class CircularDependencyDetector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "CircularDependencyDetector", attributes: .concurrent)
    private var _resolutionStack: [String] = []
    private var _detectedCycles: Set<String> = []
    private var _dependencyGraph: [String: Set<String>] = [:]

    /// 의존성 해결 시작을 알립니다
    func beginResolution<T>(for type: T.Type) throws {
        let typeName = String(describing: type)

        try queue.sync {
            // 순환 의존성 체크
            if _resolutionStack.contains(typeName) {
                let cycleStart = _resolutionStack.firstIndex(of: typeName) ?? 0
                let cycle = Array(_resolutionStack[cycleStart...]) + [typeName]
                let cycleDescription = cycle.joined(separator: " → ")

                _detectedCycles.insert(cycleDescription)
                #logError("🔄 순환 의존성 감지: \(cycleDescription)")

                throw CircularDependencyError.cyclicDependency(cycle: cycleDescription)
            }

            _resolutionStack.append(typeName)
            #logInfo("🔍 의존성 해결 시작: \(typeName) (스택 깊이: \(_resolutionStack.count))")
        }
    }

    /// 의존성 해결 완료를 알립니다
    func endResolution<T>(for type: T.Type) {
        let typeName = String(describing: type)

        queue.async(flags: .barrier) {
            if let lastIndex = self._resolutionStack.lastIndex(of: typeName) {
                self._resolutionStack.remove(at: lastIndex)
            }
            #logInfo("✅ 의존성 해결 완료: \(typeName)")
        }
    }

    /// 의존성 관계를 기록합니다
    func recordDependency<T, U>(parent: T.Type, dependency: U.Type) {
        let parentName = String(describing: parent)
        let dependencyName = String(describing: dependency)

        queue.async(flags: .barrier) {
            if self._dependencyGraph[parentName] == nil {
                self._dependencyGraph[parentName] = []
            }
            self._dependencyGraph[parentName]?.insert(dependencyName)
            #logInfo("📝 의존성 기록: \(parentName) → \(dependencyName)")
        }
    }

    /// 감지된 순환 의존성을 반환합니다
    func getDetectedCycles() -> [String] {
        return queue.sync {
            return Array(_detectedCycles)
        }
    }

    /// 의존성 그래프를 분석하여 잠재적 순환 의존성을 찾습니다
    func analyzeForPotentialCycles() -> [String] {
        return queue.sync {
            var potentialCycles: [String] = []

            for (startType, dependencies) in _dependencyGraph {
                if let cycle = findCycleFrom(startType, visited: [], graph: _dependencyGraph) {
                    potentialCycles.append(cycle.joined(separator: " → "))
                }
            }

            return potentialCycles
        }
    }

    private func findCycleFrom(
        _ current: String,
        visited: [String],
        graph: [String: Set<String>]
    ) -> [String]? {
        if visited.contains(current) {
            // 순환 발견
            let cycleStart = visited.firstIndex(of: current) ?? 0
            return Array(visited[cycleStart...]) + [current]
        }

        let newVisited = visited + [current]

        if let dependencies = graph[current] {
            for dependency in dependencies {
                if let cycle = findCycleFrom(dependency, visited: newVisited, graph: graph) {
                    return cycle
                }
            }
        }

        return nil
    }
}

enum CircularDependencyError: Error, LocalizedError {
    case cyclicDependency(cycle: String)

    var errorDescription: String? {
        switch self {
        case .cyclicDependency(let cycle):
            return "순환 의존성이 감지되었습니다: \(cycle)"
        }
    }
}

// MARK: - 순환 의존성 해결 전략

/// 순환 의존성 문제를 해결하는 다양한 패턴들을 제공합니다
final class CircularDependencyResolver {

    // MARK: - 전략 1: Lazy Injection

    /// 지연 주입을 통한 순환 의존성 해결
    static func demonstrateLazyInjection() {
        #logInfo("💡 전략 1: Lazy Injection 패턴")

        // 문제가 되는 순환 의존성 예제
        protocol ServiceA: AnyObject {
            var serviceB: ServiceB? { get set }
            func doSomething()
        }

        protocol ServiceB: AnyObject {
            var serviceA: ServiceA? { get set }
            func doSomethingElse()
        }

        // 해결: Lazy 프로퍼티 사용
        class LazyServiceA: ServiceA {
            lazy var serviceB: ServiceB? = DIContainer.shared.resolve(ServiceB.self)

            func doSomething() {
                #logInfo("ServiceA 작업 실행")
                serviceB?.doSomethingElse()
            }
        }

        class LazyServiceB: ServiceB {
            lazy var serviceA: ServiceA? = DIContainer.shared.resolve(ServiceA.self)

            func doSomethingElse() {
                #logInfo("ServiceB 작업 실행")
                // 순환 호출 방지를 위해 실제로는 ServiceA를 다시 호출하지 않음
            }
        }

        #logInfo("✅ Lazy Injection으로 순환 의존성 해결")
    }

    // MARK: - 전략 2: Interface Segregation

    /// 인터페이스 분리를 통한 순환 의존성 해결
    static func demonstrateInterfaceSegregation() {
        #logInfo("💡 전략 2: Interface Segregation 패턴")

        // 문제: UserService와 OrderService가 서로를 참조
        protocol UserQueryService: Sendable {
            func getUser(id: String) async throws -> User
        }

        protocol UserValidationService: Sendable {
            func validateUser(id: String) async throws -> Bool
        }

        protocol OrderCreationService: Sendable {
            func createOrder(userId: String, items: [OrderItem]) async throws -> Order
        }

        protocol OrderQueryService: Sendable {
            func getOrderHistory(userId: String) async throws -> [Order]
        }

        // 해결: 각 서비스가 필요한 인터페이스만 의존하도록 분리
        class RefactoredUserService: UserQueryService, UserValidationService {
            // OrderService에 의존하지 않음 - 순환 의존성 제거됨

            func getUser(id: String) async throws -> User {
                // 구현
                return User(id: id, email: "user@example.com", name: "User", membershipLevel: .bronze)
            }

            func validateUser(id: String) async throws -> Bool {
                // 구현
                return true
            }
        }

        class RefactoredOrderService: OrderCreationService, OrderQueryService {
            @Inject private var userValidation: UserValidationService // 전체 UserService 대신 필요한 인터페이스만

            func createOrder(userId: String, items: [OrderItem]) async throws -> Order {
                // userValidation만 사용 - 순환 의존성 없음
                _ = try await userValidation.validateUser(id: userId)

                return Order(
                    id: UUID().uuidString,
                    userId: userId,
                    items: items,
                    totalAmount: 0,
                    status: .pending,
                    createdAt: Date()
                )
            }

            func getOrderHistory(userId: String) async throws -> [Order] {
                // 구현
                return []
            }
        }

        #logInfo("✅ Interface Segregation으로 순환 의존성 해결")
    }

    // MARK: - 전략 3: Event-Driven Architecture

    /// 이벤트 기반 아키텍처를 통한 순환 의존성 해결
    static func demonstrateEventDrivenApproach() {
        #logInfo("💡 전략 3: Event-Driven Architecture 패턴")

        // 이벤트 정의
        protocol DomainEvent: Sendable {
            var eventId: String { get }
            var occurredAt: Date { get }
        }

        struct UserCreatedEvent: DomainEvent {
            let eventId = UUID().uuidString
            let occurredAt = Date()
            let userId: String
            let userEmail: String
        }

        struct OrderCreatedEvent: DomainEvent {
            let eventId = UUID().uuidString
            let occurredAt = Date()
            let orderId: String
            let userId: String
        }

        // 이벤트 버스
        protocol EventBus: Sendable {
            func publish(_ event: DomainEvent)
            func subscribe<T: DomainEvent>(to eventType: T.Type, handler: @escaping (T) -> Void)
        }

        // 해결: 직접 의존성 대신 이벤트를 통한 통신
        class EventDrivenUserService {
            @Inject private var eventBus: EventBus

            func createUser(email: String, name: String) async throws -> User {
                let user = User(id: UUID().uuidString, email: email, name: name, membershipLevel: .bronze)

                // 직접 다른 서비스를 호출하는 대신 이벤트 발행
                eventBus.publish(UserCreatedEvent(userId: user.id, userEmail: user.email))

                #logInfo("👤 사용자 생성 완료: \(user.id)")
                return user
            }
        }

        class EventDrivenNotificationService {
            @Inject private var eventBus: EventBus

            init() {
                setupEventSubscriptions()
            }

            private func setupEventSubscriptions() {
                // UserCreatedEvent 구독
                eventBus.subscribe(to: UserCreatedEvent.self) { [weak self] event in
                    self?.handleUserCreated(event)
                }

                // OrderCreatedEvent 구독
                eventBus.subscribe(to: OrderCreatedEvent.self) { [weak self] event in
                    self?.handleOrderCreated(event)
                }
            }

            private func handleUserCreated(_ event: UserCreatedEvent) {
                #logInfo("📧 환영 이메일 발송: \(event.userEmail)")
            }

            private func handleOrderCreated(_ event: OrderCreatedEvent) {
                #logInfo("📧 주문 확인 이메일 발송: \(event.orderId)")
            }
        }

        #logInfo("✅ Event-Driven Architecture로 순환 의존성 해결")
    }
}

// MARK: - 종합 순환 의존성 관리 시스템

final class CircularDependencyManager {
    private let detector = CircularDependencyDetector()
    private let resolver = CircularDependencyResolver()

    /// 의존성 해결 과정을 모니터링합니다
    func monitorResolution<T>(for type: T.Type) throws {
        try detector.beginResolution(for: type)

        // 실제 해결 로직은 여기서...

        detector.endResolution(for: type)
    }

    /// 의존성 관계를 기록합니다
    func recordDependencyRelation<T, U>(parent: T.Type, dependency: U.Type) {
        detector.recordDependency(parent: parent, dependency: dependency)
    }

    /// 순환 의존성 진단 리포트를 생성합니다
    func generateDiagnosticReport() -> String {
        let detectedCycles = detector.getDetectedCycles()
        let potentialCycles = detector.analyzeForPotentialCycles()

        var report = """
        🔄 순환 의존성 진단 리포트
        ========================

        🚨 감지된 순환 의존성: \(detectedCycles.count)개
        """

        if detectedCycles.isEmpty {
            report += "\n- 감지된 순환 의존성이 없습니다. ✅"
        } else {
            for cycle in detectedCycles {
                report += "\n- \(cycle)"
            }
        }

        report += "\n\n⚠️ 잠재적 순환 의존성: \(potentialCycles.count)개"

        if potentialCycles.isEmpty {
            report += "\n- 잠재적 순환 의존성이 없습니다. ✅"
        } else {
            for cycle in potentialCycles {
                report += "\n- \(cycle)"
            }
        }

        report += """

        💡 순환 의존성 해결 방법:
        1. Lazy Injection: 지연 주입을 통한 해결
        2. Interface Segregation: 인터페이스를 더 작은 단위로 분리
        3. Event-Driven: 이벤트 기반 아키텍처로 직접 의존성 제거
        4. Dependency Inversion: 추상화를 통한 의존성 방향 변경
        """

        return report
    }
}

// MARK: - 사용 예제

extension DIContainer {
    /// 순환 의존성 관리 시스템을 설정합니다
    func setupCircularDependencyManagement() -> CircularDependencyManager {
        #logInfo("🔧 순환 의존성 관리 시스템 설정")

        let manager = CircularDependencyManager()

        // 실제 구현에서는 DiContainer의 resolve 과정에
        // manager.monitorResolution 호출을 추가해야 함

        #logInfo("✅ 순환 의존성 관리 시스템 설정 완료")
        return manager
    }
}

// MARK: - 순환 의존성 해결 예제

enum CircularDependencyExample {
    static func demonstrateCircularDependencyResolution() async {
        #logInfo("🎬 순환 의존성 해결 데모 시작")

        let container = DIContainer()
        let manager = container.setupCircularDependencyManagement()

        // 다양한 해결 전략 시연
        CircularDependencyResolver.demonstrateLazyInjection()
        CircularDependencyResolver.demonstrateInterfaceSegregation()
        CircularDependencyResolver.demonstrateEventDrivenApproach()

        // 진단 리포트 생성
        let report = manager.generateDiagnosticReport()
        #logInfo("📋 순환 의존성 진단 리포트:\n\(report)")

        #logInfo("🎉 순환 의존성 해결 데모 완료")
    }
}