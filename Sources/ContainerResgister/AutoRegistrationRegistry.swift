//
//  AutoRegistrationRegistry.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Auto Registration Registry

/// Needle 스타일의 자동 등록을 위한 타입 매핑 레지스트리입니다.
/// 
/// 이 레지스트리는 인터페이스/프로토콜 타입을 구체적인 구현체와 연결하여
/// ContainerRegister가 자동으로 의존성을 생성할 수 있게 해줍니다.
public final class AutoRegistrationRegistry: @unchecked Sendable {
    
    public static let shared = AutoRegistrationRegistry()
    
    /// 타입 이름을 키로 하고 팩토리 클로저를 값으로 하는 매핑
    private var typeFactories: [String: () -> Any] = [:]
    
    /// 스레드 안전을 위한 큐
    private let queue = DispatchQueue(label: "AutoRegistrationRegistry", attributes: .concurrent)
    
    private init() {}
    
    /// 타입과 그 구현체를 등록합니다.
    /// 
    /// - Parameters:
    ///   - protocolType: 인터페이스/프로토콜 타입
    ///   - factory: 구현체 인스턴스를 생성하는 팩토리 클로저
    public func register<T>(_ protocolType: T.Type, factory: @Sendable @escaping () -> T) {
        let typeName = String(describing: protocolType)
        
        queue.async(flags: .barrier) {
            self.typeFactories[typeName] = factory
        }
    }
    
    /// 등록된 타입에 대한 인스턴스를 생성합니다.
    /// 
    /// - Parameter type: 생성할 타입
    /// - Returns: 생성된 인스턴스 (등록되지 않은 경우 nil)
    public func createInstance<T>(for type: T.Type) -> T? {
        let typeName = String(describing: type)
        
        return queue.sync {
            guard let factory = typeFactories[typeName] else {
                return nil
            }
            return factory() as? T
        }
    }
    
    /// 모든 등록된 타입을 출력합니다 (디버깅용)
    public func debugPrintRegisteredTypes() {
        queue.sync {
            #logDebug("🔍 AutoRegistrationRegistry - Registered Types:")
            for (index, typeName) in typeFactories.keys.sorted().enumerated() {
                #logDebug("   [\(index + 1)] \(typeName)")
            }
        }
    }
    
    /// 등록된 타입 개수를 반환합니다.
    public var registeredCount: Int {
        queue.sync { typeFactories.count }
    }
}

// MARK: - Convenience Registration Extensions

public extension AutoRegistrationRegistry {
    
    /// 여러 타입을 한번에 등록하는 편의 메서드입니다.
    /// 
    /// ## 사용 예시:
    /// ```swift
    /// AutoRegistrationRegistry.shared.registerTypes {
    ///   (BookListInterface.self, { BookListRepositoryImpl() })
    ///   (UserServiceProtocol.self, { UserServiceImpl() })
    ///   (NetworkServiceProtocol.self, { DefaultNetworkService() })
    /// }
    /// ```
    func registerTypes(@TypeRegistrationBuilder _ builder: () -> [TypeRegistration]) {
        let registrations = builder()
        for registration in registrations {
            registration.register(in: self)
        }
    }
}

// MARK: - Type Registration Builder

/// 타입 등록을 위한 Result Builder입니다.
@resultBuilder
public struct TypeRegistrationBuilder {
    public static func buildBlock(_ components: TypeRegistration...) -> [TypeRegistration] {
        components
    }
}

/// 개별 타입 등록을 나타내는 구조체입니다.
public struct TypeRegistration {
    private let registerFunc: (AutoRegistrationRegistry) -> Void
    
    public init<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) {
        self.registerFunc = { registry in
            registry.register(type, factory: factory)
        }
    }
    
    func register(in registry: AutoRegistrationRegistry) {
        registerFunc(registry)
    }
}

// MARK: - Global Registration Functions

/// 전역 함수로 자동 등록 설정을 간편하게 할 수 있습니다.
public func setupAutoRegistration() {
    // 사용자가 필요에 따라 타입들을 등록할 수 있습니다.
    // AutoRegistrationRegistry.shared.registerTypes {
    //     TypeRegistration(NetworkServiceProtocol.self) { DefaultNetworkService() }
    // }
}

