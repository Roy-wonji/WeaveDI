//
//  DIContainer.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import LogMacro
import Combine


/// `DependencyContainer`는 애플리케이션 전반에서 의존성을 등록, 조회 및 해제하는 역할을 수행하는 싱글턴 DI 컨테이너입니다.
///
/// - 내부적으로 의존성을 `String`(타입 이름) 키로 관리합니다.
/// - 동기화를 위해 concurrent `DispatchQueue`와 `.barrier` 플래그를 사용하여 thread-safe하게 구현되었습니다.
/// - `@Observable`을 사용하여 외부에서 변경을 감지할 수 있습니다.
public final class DependencyContainer: @unchecked Sendable , ObservableObject {

    // MARK: - 저장 프로퍼티

    /// 등록된 의존성(또는 팩토리 클로저)을 저장하는 딕셔너리.
    /// key: 타입 이름(String), value: 인스턴스를 생성하는 클로저(Any)
    private var registry = [String: Any]()

    /// 등록된 의존성을 해제하기 위한 핸들러들을 저장하는 딕셔너리.
    /// key: 타입 이름(String), value: 해제 클로저 (() -> Void)
    private var releaseHandlers = [String: () -> Void]()

    /// 읽기·쓰기를 동기화하기 위한 concurrent `DispatchQueue`.
    /// 읽기는 `sync`, 쓰기는 `async(flags: .barrier)`를 사용하여 동시성 문제를 방지합니다.
    private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)

    // MARK: - 초기화

    /// 기본 초기화 메서드.
    /// - 설명: 생성 시 `registry`와 `releaseHandlers`는 빈 상태로 시작됩니다.
    public init() {}

    // MARK: - 의존성 등록

    /// 주어진 타입의 의존성을 등록합니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`)
    ///   - build: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
    /// - Returns: 나중에 해당 의존성을 해제할 때 호출할 해제 클로저
    @discardableResult
    public func register<T>(
        _ type: T.Type,
        build: @escaping () -> T
    ) -> () -> Void {
        let key = String(describing: type)

        // 동기적으로 registry에 build 클로저를 저장합니다.
        syncQueue.sync(flags: .barrier) {
            self.registry[key] = build
        }

        // 로그: 등록 완료
        Task {
            await Log.debug("Registered", key)
        }

        // 해제 클로저: 해당 키의 값을 제거합니다.
        let releaseHandler: () -> Void = { [weak self] in
            self?.syncQueue.sync(flags: .barrier) {
                self?.registry[key] = nil
                self?.releaseHandlers[key] = nil
            }
            Task {
                await Log.debug("Released", key)
            }
        }

        // 동기적으로 releaseHandlers에도 저장합니다.
        syncQueue.sync(flags: .barrier) {
            self.releaseHandlers[key] = releaseHandler
        }

        return releaseHandler
    }

    // MARK: - 의존성 조회

    /// 주어진 타입의 의존성을 조회하여 인스턴스를 생성합니다.
    ///
    /// - Parameter type: 조회할 의존성의 타입
    /// - Returns: 등록된 의존성이 있으면 생성된 인스턴스, 없으면 `nil`
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return syncQueue.sync {
            guard let factory = self.registry[key] as? () -> T else {
                Task {
                  await Log.error("No registered dependency found for \(String(describing: T.self))")
                }
                return nil
            }
            return factory()
        }
    }

    /// 주어진 타입의 의존성을 조회하거나, 등록되어 있지 않으면 기본값을 반환합니다.
    ///
    /// - Parameters:
    ///   - type: 조회할 의존성의 타입
    ///   - defaultValue: 의존성이 없을 때 사용할 기본값 (자동 클로저)
    /// - Returns: 조회된 의존성 또는 기본값
    public func resolveOrDefault<T>(
        _ type: T.Type,
        default defaultValue: @autoclosure () -> T
    ) -> T {
        resolve(type) ?? defaultValue()
    }

    // MARK: - 의존성 해제

    /// 특정 타입의 의존성을 해제합니다.
    ///
    /// - Parameter type: 해제할 의존성의 타입
    public func release<T>(_ type: T.Type) {
        let key = String(describing: type)
        syncQueue.async(flags: .barrier) {
            self.releaseHandlers[key]?()
        }
    }

    // MARK: - KeyPath 기반 서브스크립트

    /// KeyPath 기반 접근: 내부적으로 `resolve(T.self)`를 호출합니다.
    public subscript<T>(keyPath: KeyPath<DependencyContainer, T>) -> T? {
        get { resolve(T.self) }
    }

    // MARK: - 인스턴스 직접 등록

    /// 이미 생성된 인스턴스를 클로저로 래핑하여 등록합니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 인스턴스의 타입
    ///   - instance: 미리 생성된 인스턴스
    /// - 설명: `T`가 `Sendable`하지 않아도 등록할 수 있도록 설계되었습니다.
    public func register<T: Sendable>(
        _ type: T.Type,
        instance: T
    ) {
        let key = String(describing: type)
        syncQueue.async(flags: .barrier) { [unowned self] in
            // @Sendable 캐스트를 제거하여 instance 캡처 오류 해결
            self.registry[key] = { instance }
        }
        Task {
            await Log.debug("Registered instance for", key)
        }
    }
}


public extension DependencyContainer {
    /// 전역적으로 사용 가능한 `DependencyContainer` 인스턴스 (live container)
    static let live = DependencyContainer()
}


// MARK: - Box 클래스

/// non-Sendable 타입을 안전하게 캡슐화하기 위한 래퍼 클래스입니다.
private final class Box<T> {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

/// `DependencyContainer`는 애플리케이션 전반에서 의존성(또는 팩토리 클로저)을 등록, 조회 및 해제하는 DI 컨테이너입니다.
///
/// - 내부적으로 의존성을 `String`(타입 이름) 키로 관리합니다.
/// - 동기화를 위해 concurrent `DispatchQueue`와 `.barrier` 플래그를 사용하여 thread-safe하게 구현되었습니다.
/// - Swift 5.9 미만 또는 iOS 17.0 미지원 환경에서 사용됩니다.


// MARK: - 사용 예시 코드

/*
--------------------------------------------
 예시 1: 간단한 의존성 등록 & 조회
--------------------------------------------
import Foundation

// 1) 프로토콜 정의
protocol UserRepositoryProtocol {
    func fetchUser(id: String) -> String
}

// 2) 구현체 정의
struct DefaultUserRepository: UserRepositoryProtocol {
    func fetchUser(id: String) -> String {
        return "User(\(id))"
    }
}

// 3) 애플리케이션 시작 시점에 의존성 등록
@main
struct MyApp {
    static func main() async {
        // DefaultUserRepository를 UserRepositoryProtocol 타입으로 등록
        DependencyContainer.live.register(UserRepositoryProtocol.self) {
            DefaultUserRepository()
        }

        // 등록된 인스턴스 조회
        if let repo: UserRepositoryProtocol = DependencyContainer.live.resolve(UserRepositoryProtocol.self) {
            print(repo.fetchUser(id: "123"))  // 출력: User(123)
        }
    }
}
*/

/*
--------------------------------------------
 예시 2: 등록 해제
--------------------------------------------
import Foundation

protocol LoggerProtocol {
    func log(_ message: String)
}

struct ConsoleLogger: LoggerProtocol {
    func log(_ message: String) {
        print("Log:", message)
    }
}

@main
struct MyApp {
    static func main() async {
        // LoggerProtocol을 ConsoleLogger로 등록하고 해제 핸들러를 받아옴
        let releaseLogger = DependencyContainer.live.register(LoggerProtocol.self) {
            ConsoleLogger()
        }

        // 조회 후 사용
        if let logger: LoggerProtocol = DependencyContainer.live.resolve(LoggerProtocol.self) {
            logger.log("Hello DI")  // 출력: Log: Hello DI
        }

        // 등록 해제
        releaseLogger()

        // 해제 후 조회 시 nil 반환
        print(DependencyContainer.live.resolve(LoggerProtocol.self) == nil)  // true
    }
}
*/

/*
--------------------------------------------
 예시 3: 등록된 인스턴스를 직접 주입
--------------------------------------------
import Foundation

struct NetworkService {
    let baseURL: URL
    func request(endpoint: String) {
        print("Requesting:", baseURL.appendingPathComponent(endpoint))
    }
}

@main
struct MyApp {
    static func main() async {
        // 이미 생성한 인스턴스를 등록
        let service = NetworkService(baseURL: URL(string: "https://api.example.com")!)
        DependencyContainer.live.register(NetworkService.self, instance: service)

        // 조회 후 사용
        let ns = DependencyContainer.live.resolve(NetworkService.self)!
        ns.request(endpoint: "posts/1")
        // 출력: Requesting: https://api.example.com/posts/1
    }
}
*/
