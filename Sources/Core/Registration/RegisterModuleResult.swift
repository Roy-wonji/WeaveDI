//
//  RegisterModuleResult.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - RegisterModuleError

/// RegisterModule에서 발생하는 오류를 정의하는 열거형입니다.
public enum RegisterModuleError: Error, LocalizedError, CustomStringConvertible {
    /// 타입 캐스팅 실패
    case typeCastFailure(from: String, to: String, reason: String? = nil)
    
    /// 의존성 해결 실패
    case dependencyResolutionFailure(type: String, reason: String? = nil)
    
    /// 순환 의존성 감지
    case circularDependency(involved: [String])
    
    /// 팩토리 실행 오류
    case factoryExecutionError(type: String, underlyingError: Error)
    
    /// 설정 오류
    case configurationError(message: String)
    
    public var errorDescription: String? {
        return description
    }
    
    public var description: String {
        switch self {
        case .typeCastFailure(let from, let to, let reason):
            let reasonText = reason.map { " Reason: \($0)" } ?? ""
            return "타입 캐스팅 실패: \(from) -> \(to)로 변환할 수 없습니다.\(reasonText)"
            
        case .dependencyResolutionFailure(let type, let reason):
            let reasonText = reason.map { " Reason: \($0)" } ?? ""
            return "의존성 해결 실패: \(type) 타입을 해결할 수 없습니다.\(reasonText)"
            
        case .circularDependency(let involved):
            return "순환 의존성 감지: \(involved.joined(separator: " -> "))"
            
        case .factoryExecutionError(let type, let underlyingError):
            return "팩토리 실행 오류: \(type) 생성 중 오류 발생 - \(underlyingError.localizedDescription)"
            
        case .configurationError(let message):
            return "설정 오류: \(message)"
        }
    }
}

// MARK: - RegisterModuleResult

/// RegisterModule 작업의 결과를 나타내는 Result 타입입니다.
public typealias RegisterModuleResult<T> = Result<T, RegisterModuleError>

// MARK: - Safe Registration Functions

public extension RegisterModule {
    
    /// 안전한 의존성 생성 함수 - Result를 반환하는 버전
    /// 
    /// - Parameters:
    ///   - protocolType: 등록할 의존성의 프로토콜 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: Module 생성 클로저를 반환하는 Result
    func makeDependencySafe<T, U>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> U
    ) -> RegisterModuleResult<@Sendable () -> Module> {
        return .success {
            self.makeDependencyModuleSafe(protocolType, factory: factory)
        }
    }
    
    /// 안전한 의존성 모듈 생성 - 내부 구현
    /// 
    /// - Parameters:
    ///   - type: 생성할 의존성의 타입
    ///   - factory: 의존성 인스턴스를 생성하는 클로저
    /// - Returns: 생성된 Module (오류 시 기본값 사용)
    private func makeDependencyModuleSafe<T, U>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> U
    ) -> Module {
        return self.makeModule(type) {
            let instance = factory()
            
            // 안전한 캐스팅 시도
            guard let dependency = instance as? T else {
                // 로깅 후 기본값 반환 (실제로는 컴파일 타임에 방지되어야 함)
                Log.error("Type casting failed: \(U.self) cannot be cast to \(T.self)")
                
                // 기본값 전략들
                if let defaultProvider = getDefaultProvider(for: type) {
                    return defaultProvider()
                }
                
                // 최후의 수단: 런타임 오류 대신 의미있는 오류 처리
                preconditionFailure("Critical error: Unable to cast \(U.self) to \(T.self) and no default provider available")
            }
            
            return dependency
        }
    }
    
    /// 기본값 제공자를 찾는 헬퍼 함수
    /// 
    /// - Parameter type: 기본값이 필요한 타입
    /// - Returns: 기본값을 생성하는 클로저 (있는 경우)
    private func getDefaultProvider<T>(for type: T.Type) -> (() -> T)? {
        // 여기서 기본값 제공 로직을 구현할 수 있습니다
        // 예: Mock 객체, No-Op 구현체 등
        return nil
    }
    
    /// Optional을 반환하는 안전한 의존성 생성 함수
    /// 
    /// - Parameters:
    ///   - protocolType: 등록할 의존성의 프로토콜 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 성공 시 Module 생성 클로저, 실패 시 nil
    func makeDependencyOptional<T, U>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> U
    ) -> (@Sendable () -> Module)? {
        // 컴파일 타임에 타입 호환성 체크 (실제로는 매크로나 제네릭 제약으로 처리)
        guard U.self is T.Type || (factory() as? T) != nil else {
            Log.error("Type incompatibility detected: \(U.self) is not compatible with \(T.self)")
            return nil
        }
        
        return {
            self.makeModule(protocolType) {
                let instance = factory()
                return instance as! T // 이미 위에서 검증했으므로 안전
            }
        }
    }
    
    /// 타입 안전한 의존성 생성 (컴파일 타임 체크 권장)
    /// 
    /// - Parameters:
    ///   - protocolType: 등록할 의존성의 프로토콜 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: Module 생성 클로저
    /// - Note: 프로토콜 준수 여부는 컴파일 타임에 개발자가 확인해야 합니다
    func makeTypeSafeDependency<T>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> @Sendable () -> Module {
        return {
            self.makeModule(protocolType, factory: factory)
        }
    }
}

// MARK: - Backward Compatibility

public extension RegisterModule {
    
    /// 기존 makeDependency를 유지하되 더 안전하게 개선
    /// 
    /// - Parameters:
    ///   - protocolType: 등록할 의존성의 프로토콜 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: Module을 생성하는 클로저
    func makeDependencyImproved<T, U>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> U
    ) -> @Sendable () -> Module {
        return {
            self.makeModule(protocolType) {
                let instance = factory()
                
                guard let dependency = instance as? T else {
                    // fatalError 대신 상세한 오류 정보와 함께 처리
                    let error = RegisterModuleError.typeCastFailure(
                        from: String(describing: U.self),
                        to: String(describing: T.self),
                        reason: "The factory produces \(type(of: instance)) which cannot be cast to \(T.self)"
                    )
                    
                    Log.error("❌ \(error.description)")
                    
                    #if DEBUG
                    // 디버그 빌드에서는 크래시하여 개발 중 문제를 빨리 발견
                    preconditionFailure(error.description)
                    #else
                    // 릴리즈 빌드에서는 기본값이나 대체 구현 시도
                    if let fallback = createFallbackInstance(for: protocolType) {
                        Log.warning("🔄 Using fallback instance for \(T.self)")
                        return fallback
                    } else {
                        fatalError(error.description) // 최후의 수단
                    }
                    #endif
                }
                
                return dependency
            }
        }
    }
    
    /// 폴백 인스턴스 생성 시도
    /// 
    /// - Parameter type: 폴백 인스턴스가 필요한 타입
    /// - Returns: 폴백 인스턴스 (가능한 경우)
    private func createFallbackInstance<T>(for type: T.Type) -> T? {
        // 여기서 타입별 기본 구현체나 Mock 객체를 반환할 수 있습니다
        // 예시: NoOp 구현체, Mock 객체 등
        return nil
    }
}