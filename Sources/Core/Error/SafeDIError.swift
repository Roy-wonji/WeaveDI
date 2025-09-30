//
//  SafeDIError.swift
//  DiContainer
//
//  Created by Wonja Suh on 9/24/25.
//

import Foundation
import LogMacro

// MARK: - Safe Dependency Injection Errors

/// 안전한 의존성 주입을 위한 에러 타입
public enum SafeDIError: Error, LocalizedError, CustomStringConvertible {
  
  // MARK: - Error Cases
  
  /// 의존성을 찾을 수 없는 경우
  case dependencyNotFound(type: String, keyPath: String?)
  
  /// 필수 의존성이 등록되지 않은 경우
  case requiredDependencyMissing(type: String, context: String?)
  
  /// Factory를 찾을 수 없는 경우
  case factoryNotFound(keyPath: String)
  
  /// 순환 의존성이 탐지된 경우
  case circularDependency(path: [String])
  
  /// 의존성 해결 중 타임아웃
  case resolutionTimeout(type: String, timeout: TimeInterval)
  
  /// 잘못된 설정
  case invalidConfiguration(reason: String)
  
  /// 컨테이너가 초기화되지 않은 경우
  case containerNotInitialized
  
  // MARK: - LocalizedError
  
  public var errorDescription: String? {
    switch self {
      case .dependencyNotFound(let type, let keyPath):
        if let keyPath = keyPath {
          return "의존성을 찾을 수 없습니다: \(type) (KeyPath: \(keyPath))"
        } else {
          return "의존성을 찾을 수 없습니다: \(type)"
        }
        
      case .requiredDependencyMissing(let type, let context):
        if let context = context {
          return "필수 의존성이 등록되지 않았습니다: \(type) (\(context))"
        } else {
          return "필수 의존성이 등록되지 않았습니다: \(type)"
        }
        
      case .factoryNotFound(let keyPath):
        return "Factory를 찾을 수 없습니다: \(keyPath)"
        
      case .circularDependency(let path):
        return "순환 의존성이 탐지되었습니다: \(path.joined(separator: " → "))"
        
      case .resolutionTimeout(let type, let timeout):
        return "의존성 해결 시간 초과: \(type) (Timeout: \(timeout)s)"
        
      case .invalidConfiguration(let reason):
        return "잘못된 설정: \(reason)"
        
      case .containerNotInitialized:
        return "DI 컨테이너가 초기화되지 않았습니다. WeaveDI.Container.bootstrap을 먼저 호출하세요."
    }
  }
  
  // MARK: - CustomStringConvertible
  
  public var description: String {
    return errorDescription ?? "알 수 없는 DI 에러"
  }
  
  // MARK: - Helper Methods
  
  /// 개발자 친화적인 디버그 메시지
  public var debugDescription: String {
    switch self {
      case .dependencyNotFound(let type, let keyPath):
        var message = """
            🚨 의존성 해결 실패
            타입: \(type)
            """
        if let keyPath = keyPath {
          message += "\nKeyPath: \(keyPath)"
        }
        message += """
            
            해결 방법:
            1. 의존성이 올바르게 등록되었는지 확인
            2. 타입명이 정확한지 확인
            3. 컨테이너가 초기화되었는지 확인
            """
        return message
        
      case .circularDependency(let path):
        return """
            🔄 순환 의존성 탐지
            경로: \(path.joined(separator: " → "))
            
            해결 방법:
            1. 의존성 구조를 재설계하여 순환 참조 제거
            2. 인터페이스를 통한 추상화 도입
            3. 의존성 주입 순서 변경
            """
        
      default:
        return description
    }
  }
  
  /// 복구 가능한 에러인지 확인
  public var isRecoverable: Bool {
    switch self {
      case .dependencyNotFound, .factoryNotFound:
        return true
      case .circularDependency, .invalidConfiguration, .containerNotInitialized:
        return false
      case .requiredDependencyMissing, .resolutionTimeout:
        return false
    }
  }
}

// MARK: - Safe Resolution Results

/// 안전한 의존성 해결 결과
public enum SafeResolutionResult<T> {
  case success(T)
  case failure(SafeDIError)
  
  /// 성공한 경우 값을 반환, 실패한 경우 nil
  public var value: T? {
    switch self {
      case .success(let value):
        return value
      case .failure:
        return nil
    }
  }
  
  /// 에러 정보
  public var error: SafeDIError? {
    switch self {
      case .success:
        return nil
      case .failure(let error):
        return error
    }
  }
}

// MARK: - Safe Injection Protocol

/// 안전한 의존성 주입을 위한 프로토콜
public protocol SafeInjectable {
  /// 안전한 의존성 해결
  static func safeDependencyResolution() -> SafeResolutionResult<Self>
}

// MARK: - Recovery Strategies

/// 에러 복구 전략
public enum RecoveryStrategy<T> {
  case useDefault(T)
  case retry(maxAttempts: Int)
  case fallback(() throws -> T)
  case ignore
}

/// 안전한 의존성 해결 헬퍼
public enum SafeDependencyResolver {
  
  /// 에러와 함께 안전한 해결
  public static func safeResolve<T>(_ type: T.Type) -> SafeResolutionResult<T> {
    if let resolved = WeaveDI.Container.live.resolve(type) {
      return .success(resolved)
    } else {
      return .failure(.dependencyNotFound(type: String(describing: type), keyPath: nil))
    }
  }
  
  /// 복구 전략과 함께 안전한 해결
  public static func safeResolve<T>(_ type: T.Type, strategy: RecoveryStrategy<T>) -> T? {
    let result = safeResolve(type)
    
    switch result {
      case .success(let value):
        return value
        
      case .failure(_):
        switch strategy {
          case .useDefault(let defaultValue):
            return defaultValue
            
          case .retry(let maxAttempts):
            for _ in 1..<maxAttempts {
              if let value = safeResolve(type).value {
                return value
              }
            }
            return nil
            
          case .fallback(let fallbackClosure):
            return try? fallbackClosure()
            
          case .ignore:
            return nil
        }
    }
  }
}
