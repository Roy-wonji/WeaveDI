//
//  ModuleBuildMetrics.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//

import Foundation
import WeaveDICore

// MARK: - Build Metrics

/// 모듈 빌드 실행 통계 정보
struct ModuleBuildMetrics {
  /// 처리된 모듈 수
  let moduleCount: Int

  /// 총 실행 시간 (초)
  let duration: TimeInterval

  /// 초당 처리 모듈 수
  let modulesPerSecond: Double

  /// 포맷된 요약 정보
  var summary: String {
    return """
        Module Build Metrics:
        - Modules: \(moduleCount)
        - Duration: \(String(format: "%.3f", duration))s
        - Rate: \(String(format: "%.1f", modulesPerSecond)) modules/sec
        """
  }
}
