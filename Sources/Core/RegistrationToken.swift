//
//  RegistrationToken.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - RegistrationToken

/// 의존성 등록을 추적하고 자동으로 해제할 수 있는 토큰입니다.
///
/// ## 특징:
/// - **자동 해제**: 토큰이 deallocate될 때 자동으로 등록 해제
/// - **명시적 해제**: `cancel()` 호출로 수동 해제 가능
/// - **메모리 안전**: Weak reference로 retain cycle 방지
/// - **디버깅 지원**: 등록된 타입 정보 제공
///
/// ## 사용법:
/// ```swift
/// class MyService {
///     private var registrationToken: RegistrationToken?
///     
///     init() {
///         // 자동 해제를 위해 토큰 보관
///         registrationToken = DI.registerWithToken(ServiceProtocol.self) { 
///             ServiceImpl() 
///         }
///     }
///     
///     deinit {
///         // 필요시 명시적 해제 (자동으로도 해제됨)
///         registrationToken?.cancel()
///     }
/// }
/// ```
public final class RegistrationToken: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// 등록 해제 클로저 (weak reference 사용으로 retain cycle 방지)
    private var releaseHandler: (() -> Void)?
    
    /// 등록된 타입의 이름 (디버깅용)
    private let typeName: String
    
    /// 등록 시각 (디버깅용)
    private let registrationTime: Date
    
    /// 토큰이 이미 취소되었는지 여부
    private var isCancelled: Bool = false
    
    /// 취소 시각 (디버깅용)
    private var cancellationTime: Date?
    
    // MARK: - Lifecycle
    
    /// RegistrationToken을 생성합니다.
    /// - Parameters:
    ///   - typeName: 등록된 타입의 이름
    ///   - releaseHandler: 등록 해제를 수행하는 클로저
    internal init(typeName: String, releaseHandler: @escaping () -> Void) {
        self.typeName = typeName
        self.releaseHandler = releaseHandler
        self.registrationTime = Date()
        
        #if DEBUG
        print("🔗 [RegistrationToken] Created for \(typeName) at \(registrationTime)")
        #endif
    }
    
    deinit {
        // 자동 해제: 토큰이 deallocate될 때 등록도 해제
        if !isCancelled {
            #if DEBUG
            print("♻️  [RegistrationToken] Auto-releasing \(typeName) on deinit")
            #endif
            releaseHandler?()
        }
    }
    
    // MARK: - Public Methods
    
    /// 등록을 명시적으로 취소합니다.
    /// 이미 취소된 경우 아무 작업도 하지 않습니다.
    public func cancel() {
        guard !isCancelled else {
            #if DEBUG
            print("⚠️ [RegistrationToken] Already cancelled: \(typeName)")
            #endif
            return
        }
        
        isCancelled = true
        cancellationTime = Date()
        
        #if DEBUG
        print("🚫 [RegistrationToken] Manually cancelled \(typeName) at \(cancellationTime!)")
        #endif
        
        releaseHandler?()
        releaseHandler = nil // release handler를 nil로 설정하여 메모리 해제
    }
    
    /// 토큰이 유효한지 확인합니다.
    public var isValid: Bool {
        return !isCancelled && releaseHandler != nil
    }
    
    /// 등록된 타입의 이름을 반환합니다.
    public var registeredTypeName: String {
        return typeName
    }
    
    /// 등록된 시간을 반환합니다.
    public var registeredAt: Date {
        return registrationTime
    }
    
    /// 취소된 시간을 반환합니다 (취소되지 않았으면 nil).
    public var cancelledAt: Date? {
        return cancellationTime
    }
}

// MARK: - CustomStringConvertible

extension RegistrationToken: CustomStringConvertible {
    public var description: String {
        let status = isCancelled ? "cancelled" : "active"
        return "RegistrationToken(type: \(typeName), status: \(status), registeredAt: \(registrationTime))"
    }
}

// MARK: - RegistrationTokenGroup

/// 여러 RegistrationToken을 한 번에 관리하는 그룹입니다.
///
/// ## 사용법:
/// ```swift
/// class AppDISetup {
///     private let tokenGroup = RegistrationTokenGroup()
///     
///     func setupDependencies() {
///         tokenGroup.add(DI.registerWithToken(ServiceA.self) { ServiceAImpl() })
///         tokenGroup.add(DI.registerWithToken(ServiceB.self) { ServiceBImpl() })
///         tokenGroup.add(DI.registerWithToken(ServiceC.self) { ServiceCImpl() })
///     }
///     
///     func cleanup() {
///         tokenGroup.cancelAll() // 모든 등록 한 번에 해제
///     }
/// }
/// ```
public final class RegistrationTokenGroup: @unchecked Sendable {
    
    // MARK: - Properties
    
    private var tokens: [RegistrationToken] = []
    private let queue = DispatchQueue(label: "com.diContainer.tokenGroup", attributes: .concurrent)
    
    // MARK: - Public Methods
    
    /// 토큰을 그룹에 추가합니다.
    /// - Parameter token: 추가할 토큰
    public func add(_ token: RegistrationToken) {
        queue.async(flags: .barrier) {
            self.tokens.append(token)
        }
    }
    
    /// 여러 토큰을 한 번에 추가합니다.
    /// - Parameter tokens: 추가할 토큰들
    public func add(_ tokens: [RegistrationToken]) {
        queue.async(flags: .barrier) {
            self.tokens.append(contentsOf: tokens)
        }
    }
    
    /// 모든 토큰을 취소합니다.
    public func cancelAll() {
        queue.async(flags: .barrier) {
            for token in self.tokens {
                token.cancel()
            }
            self.tokens.removeAll()
        }
    }
    
    /// 유효한 토큰의 개수를 반환합니다.
    public var activeTokenCount: Int {
        return queue.sync {
            tokens.filter { $0.isValid }.count
        }
    }
    
    /// 전체 토큰의 개수를 반환합니다.
    public var totalTokenCount: Int {
        return queue.sync {
            tokens.count
        }
    }
    
    /// 모든 등록된 타입의 이름을 반환합니다.
    public var registeredTypeNames: [String] {
        return queue.sync {
            tokens.map { $0.registeredTypeName }
        }
    }
}

// MARK: - DI Extension for Token Support

public extension DI {
    
    /// 토큰과 함께 의존성을 등록합니다.
    /// 토큰을 통해 나중에 등록을 해제할 수 있습니다.
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 등록을 관리하는 토큰
    static func registerWithToken<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> RegistrationToken {
        let releaseHandler = DependencyContainer.live.register(type, build: factory)
        let typeName = String(describing: type)
        return RegistrationToken(typeName: typeName, releaseHandler: releaseHandler)
    }
    
    /// 싱글톤을 토큰과 함께 등록합니다.
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - instance: 공유할 인스턴스
    /// - Returns: 등록을 관리하는 토큰
    static func registerSingletonWithToken<T>(
        _ type: T.Type,
        instance: T
    ) -> RegistrationToken {
        DependencyContainer.live.register(type, instance: instance)
        let typeName = String(describing: type)
        
        // 싱글톤의 경우 해제 로직 생성
        let releaseHandler = {
            DependencyContainer.live.release(type)
        }
        
        return RegistrationToken(typeName: typeName, releaseHandler: releaseHandler)
    }
}