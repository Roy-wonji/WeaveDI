//
//  ContainerRegisterTypo.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - 타이포 관련 안내

/// ContainerResgister는 오타입니다. 올바른 이름은 ContainerRegister입니다.
/// 
/// 기존 ContainerResgister.swift 파일의 구현체는 그대로 사용하되,
/// 새로운 코드에서는 올바른 이름을 사용하는 것을 권장합니다.
/// 
/// ## 사용 방법:
/// ```swift
/// @ContainerResgister(\.authUseCase)  // 현재 파일명 기준 (동작함)
/// private var authUseCase: AuthInterface
/// ```
/// 
/// ## 권장 방법 (향후):
/// ```swift 
/// @ContainerRegister(\.authUseCase)   // 올바른 스펠링
/// private var authUseCase: AuthInterface
/// ```
/// 
/// - Note: 실제 구현은 ContainerResgister.swift에 있습니다.
/// - Note: 파일명 변경은 기존 코드 영향을 고려하여 점진적으로 진행하세요.