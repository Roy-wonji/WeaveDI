//
//  DI.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Simplified API Design

/// 단순화된 DI API - 사용자 혼란을 줄이기 위해 핵심 패턴만 제공
///
/// ## 3가지 핵심 패턴:
/// 1. **@Inject** - 의존성 주입 (옵셔널/필수)
/// 2. **DI.register()** - 의존성 등록
/// 3. **DI.resolve()** - 의존성 해결
///
/// ## 사용 예시:
/// ```swift
/// // 1. 등록
/// DI.register(ServiceProtocol.self) { ServiceImpl() }
///
/// // 2. 주입
/// @Inject(\.service) var service: ServiceProtocol?         // 옵셔널
/// @Inject(\.service) var service: ServiceProtocol          // 필수 (컴파일 타임 체크)
///
/// // 3. 수동 해결
/// let service = DI.resolve(ServiceProtocol.self)
/// ```
public enum DI {
    // Implementation will be provided by extensions in separate files
}