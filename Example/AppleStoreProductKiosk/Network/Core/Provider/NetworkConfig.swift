//
//  NetworkConfig.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// MARK: - Network Configuration

/// 네트워크 관련 설정을 관리하는 구조체
///
/// 하드코딩된 설정값들을 분리하여 유연성과 테스트 용이성을 제공합니다.
struct NetworkConfig {
    /// 최대 재시도 횟수
    let maxRetryCount: Int

    /// 기본 재시도 간격(초) - Exponential Backoff의 기본값
    let baseRetryDelay: TimeInterval

    /// 요청 타임아웃 시간(초)
    let timeoutInterval: TimeInterval

    /// 기본 설정값으로 초기화
    static let `default` = NetworkConfig(
        maxRetryCount: 3,
        baseRetryDelay: 1.0,
        timeoutInterval: 30.0
    )

    /// 개발/테스트용 빠른 설정
    static let fastConfig = NetworkConfig(
        maxRetryCount: 2,
        baseRetryDelay: 0.5,
        timeoutInterval: 10.0
    )

    /// 프로덕션용 안정적 설정
    static let productionConfig = NetworkConfig(
        maxRetryCount: 5,
        baseRetryDelay: 2.0,
        timeoutInterval: 60.0
    )
}