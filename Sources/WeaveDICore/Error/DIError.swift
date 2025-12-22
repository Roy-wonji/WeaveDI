//
//  DIError.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - DIError

/// Dependency Injection 관련 에러를 나타내는 열거형입니다.
/// 
/// ## 사용법:
/// ```swift
/// do {
///     let service = try DI.resolve(ServiceProtocol.self)
/// } catch DIError.dependencyNotFound(let message) {
///     #logDebug("의존성을 찾을 수 없습니다: \(message)")
/// } catch {
///     #logDebug("알 수 없는 오류: \(error)")
/// }
/// ```
public enum DIError: Error, LocalizedError, CustomStringConvertible {
  
  // MARK: - Cases
  
  /// 등록되지 않은 의존성을 해결하려고 시도한 경우
  case dependencyNotFound(String)
  
  /// 순환 의존성이 감지된 경우
  case circularDependency(String)
  
  /// 의존성 등록에 실패한 경우
  case registrationFailed(String)
  
  /// 의존성 생성 중 오류가 발생한 경우
  case creationFailed(String, underlying: Error?)
  
  /// 잘못된 구성으로 인한 오류
  case configurationError(String)
  
  /// 컨테이너가 아직 부트스트랩되지 않은 경우
  case containerNotBootstrapped(String)
  
  /// 내부 오류
  case internalError(String)
  
  // MARK: - LocalizedError
  
  public var errorDescription: String? {
    switch self {
      case .dependencyNotFound(let message):
        return "의존성을 찾을 수 없습니다: \(message)"
      case .circularDependency(let message):
        return "순환 의존성이 감지되었습니다: \(message)"
      case .registrationFailed(let message):
        return "의존성 등록에 실패했습니다: \(message)"
      case .creationFailed(let message, let underlying):
        if let underlying = underlying {
          return "의존성 생성에 실패했습니다: \(message). 원인: \(underlying.localizedDescription)"
        } else {
          return "의존성 생성에 실패했습니다: \(message)"
        }
      case .configurationError(let message):
        return "잘못된 구성입니다: \(message)"
      case .containerNotBootstrapped(let message):
        return "컨테이너가 초기화되지 않았습니다: \(message)"
        
      case .internalError(let message):
        return "내부 오류: \(message)"
    }
  }
  
  public var failureReason: String? {
    switch self {
      case .dependencyNotFound(_):
        return "요청한 타입이 DI 컨테이너에 등록되지 않았습니다."
      case .circularDependency(_):
        return "의존성들이 서로를 참조하여 무한 루프가 발생했습니다."
      case .registrationFailed(_):
        return "의존성 등록 과정에서 문제가 발생했습니다."
      case .creationFailed(_, _):
        return "등록된 팩토리에서 인스턴스 생성 중 오류가 발생했습니다."
      case .configurationError(_):
        return "DI 컨테이너 설정에 문제가 있습니다."
      case .containerNotBootstrapped(_):
        return "DI 컨테이너가 아직 초기화되지 않았습니다."
        
      case .internalError(_):
        return "DiContainer 내부에서 예기치 않은 문제가 발생했습니다."
    }
  }
  
  public var recoverySuggestion: String? {
    switch self {
      case .dependencyNotFound(let message):
        let typeName = extractTypeName(from: message)
        return "DI.register(\(typeName).self) { /* 구현체 */ }를 호출하여 의존성을 등록하세요."
      case .circularDependency(_):
        return "의존성 관계를 검토하여 순환 참조를 제거하세요."
      case .registrationFailed(_):
        return "등록 코드를 확인하고 팩토리 클로저가 올바른지 검토하세요."
      case .creationFailed(_, _):
        return "팩토리 클로저 내부의 코드를 확인하고 필요한 의존성이 모두 등록되었는지 확인하세요."
      case .configurationError(_):
        return "DI 컨테이너 설정을 검토하고 올바른 구성인지 확인하세요."
      case .containerNotBootstrapped(_):
        return "앱 시작 시 UnifiedDI.bootstrap()을 호출하세요."
        
      case .internalError(_):
        return "GitHub 이슈를 통해 문제를 제보하거나 디버그 정보를 확인하세요."
    }
  }
  
  // MARK: - CustomStringConvertible
  
  public var description: String {
    return errorDescription ?? "Unknown DIError"
  }
  
  // MARK: - Helper Methods
  
  private func extractTypeName(from message: String) -> String {
    // "Type 'ServiceProtocol' not found" -> "ServiceProtocol"
    let pattern = #"'([^']+)'"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
       let range = Range(match.range(at: 1), in: message) {
      return String(message[range])
    }
    return "YourType"
  }
}

// MARK: - Convenience Initializers

public extension DIError {
  
  /// 의존성을 찾을 수 없는 오류를 생성합니다.
  static func dependencyNotFound<T>(_ type: T.Type, hint: String? = nil) -> DIError {
    let baseMessage = "Type '\(type)' not found in DI container"
    let fullMessage = hint.map { "\(baseMessage). \($0)" } ?? baseMessage
    return .dependencyNotFound(fullMessage)
  }
  
  /// 순환 의존성 오류를 생성합니다.
  static func circularDependency<T>(_ type: T.Type, chain: [String] = []) -> DIError {
    let chainString = chain.joined(separator: " -> ")
    let message = "Circular dependency detected for type '\(type)'. Chain: \(chainString) -> \(type)"
    return .circularDependency(message)
  }
  
  /// 의존성 생성 실패 오류를 생성합니다.
  static func creationFailed<T>(_ type: T.Type, underlying: Error) -> DIError {
    let message = "Failed to create instance of type '\(type)'"
    return .creationFailed(message, underlying: underlying)
  }
}

// MARK: - Result Extensions

public extension Result where Success: Any, Failure == DIError {
  
  /// 의존성 해결 결과에서 값을 안전하게 추출합니다.
  var resolved: Success? {
    switch self {
      case .success(let value):
        return value
      case .failure:
        return nil
    }
  }
  
  /// 실패 시 로그를 출력하고 nil을 반환합니다.
  func resolvedWithLogging(file: String = #file, function: String = #function, line: Int = #line) -> Success? {
    switch self {
      case .success(let value):
        return value
      case .failure(let error):
        #logDebug("🚨 [DI] \(error.localizedDescription) at \(function) in \(file):\(line)")
        if let suggestion = error.recoverySuggestion {
          #logDebug("💡 [DI] Suggestion: \(suggestion)")
        }
        return nil
    }
  }
}
