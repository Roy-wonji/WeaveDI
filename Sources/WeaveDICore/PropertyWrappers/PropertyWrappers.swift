//
//  PropertyWrappers.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation
import LogMacro

// MARK: - @Factory

/// ## 🏭 @Factory - 팩토리 패턴 주입
///
/// 매번 새로운 인스턴스를 생성하는 팩토리 패턴 Property Wrapper입니다.
/// 상태를 공유하지 않는 독립적인 객체가 필요할 때 사용합니다.
///
/// ### 사용법:
/// ```swift
/// class ReportService {
///     @Factory var pdfGenerator: PDFGenerator          // 매번 새 인스턴스
///     @Factory(\.emailSender) var email: EmailSender   // KeyPath로 팩토리
/// }
/// ```
@propertyWrapper
public struct Factory<T> {

  // MARK: - Properties

  private let keyPath: KeyPath<DIContainer, T?>?
  private let directFactory: (() -> T)?

  // MARK: - Initialization

  /// KeyPath를 사용한 팩토리 초기화
  /// - Parameter keyPath: 팩토리가 등록된 KeyPath
    public init(_ keyPath: KeyPath<DIContainer, T?>) {
    self.keyPath = keyPath
    self.directFactory = nil
  }

  /// 직접 팩토리 함수를 제공하는 초기화
  /// - Parameter factory: 인스턴스를 생성하는 클로저
  public init(factory: @escaping () -> T) {
    self.keyPath = nil
    self.directFactory = factory
  }

  // MARK: - Property Wrapper Implementation

  /// 매번 새로운 인스턴스를 반환합니다
  public var wrappedValue: T {
    // 직접 팩토리가 있으면 실행
    if let factory = directFactory {
      return factory()
    }

    // KeyPath를 통한 팩토리 실행
    if let keyPath = keyPath {
      guard let instance = DIContainer.shared[keyPath: keyPath] else {
        fatalError("""
                🚨 [Factory] 팩토리를 찾을 수 없습니다!
                
                KeyPath: \(keyPath)
                타입: \(T.self)
                
                💡 해결방법:
                   UnifiedDI.register(\\.keyPath) { YourImplementation() }
                """)
      }
      return instance
    }

    fatalError("🚨 [Factory] 잘못된 설정입니다. KeyPath 또는 직접 팩토리가 필요합니다.")
  }
}
