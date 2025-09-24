//
//  RetryStrategy.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// MARK: - Retry Strategy Protocol

/// 재시도 전략을 정의하는 프로토콜
///
/// 언제 재시도할지와 얼마나 대기할지를 결정하는 책임을 분리합니다.
protocol RetryStrategy {
    /// 주어진 상황에서 재시도를 해야 하는지 판단
    /// - Parameters:
    ///   - statusCode: HTTP 상태 코드
    ///   - error: 발생한 에러 (옵셔널)
    ///   - attemptCount: 현재 시도 횟수
    ///   - maxRetryCount: 최대 재시도 횟수
    /// - Returns: 재시도 여부
    func shouldRetry(
        statusCode: Int?,
        error: Error?,
        attemptCount: Int,
        maxRetryCount: Int
    ) -> Bool

    /// 재시도 전 대기 시간을 계산
    /// - Parameters:
    ///   - attemptCount: 현재 시도 횟수
    ///   - baseDelay: 기본 대기 시간
    /// - Returns: 실제 대기 시간
    func delayForRetry(attemptCount: Int, baseDelay: TimeInterval) -> TimeInterval
}

// MARK: - Default Retry Strategy

/// 기본 재시도 전략 구현체
struct DefaultRetryStrategy: RetryStrategy {

    /// 재시도 설정
    private let retryConfig: RetryConfig

    /// 초기화
    /// - Parameter retryConfig: 재시도 설정 (기본값: .default)
    init(retryConfig: RetryConfig = .default) {
        self.retryConfig = retryConfig
    }

    func shouldRetry(
        statusCode: Int?,
        error: Error?,
        attemptCount: Int,
        maxRetryCount: Int
    ) -> Bool {
        // 최대 재시도 횟수 초과 체크
        guard attemptCount < maxRetryCount else { return false }

        // 상태 코드 기반 재시도 판단
        if let statusCode = statusCode {
            return retryConfig.shouldRetryStatusCode(statusCode)
        }

        // 네트워크 에러 기반 재시도 판단
        if let error = error {
            return shouldRetryForError(error)
        }

        return false
    }

    func delayForRetry(attemptCount: Int, baseDelay: TimeInterval) -> TimeInterval {
        // Exponential Backoff: 2^attemptCount * baseDelay
        let exponentialDelay = pow(2.0, Double(attemptCount)) * baseDelay

        // 최대 30초로 제한 (무한 증가 방지)
        return min(exponentialDelay, 30.0)
    }

    // MARK: - Private Methods

    /// 에러 타입별 재시도 가능 여부 판단
    private func shouldRetryForError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return retryConfig.shouldRetryURLError(urlError)
        }

        return false
    }
}

// MARK: - Conservative Retry Strategy

/// 보수적 재시도 전략 (최소한의 재시도만)
struct ConservativeRetryStrategy: RetryStrategy {

    /// 재시도 설정
    private let retryConfig: RetryConfig

    /// 초기화
    /// - Parameter retryConfig: 재시도 설정 (기본값: .conservative)
    init(retryConfig: RetryConfig = .conservative) {
        self.retryConfig = retryConfig
    }

    func shouldRetry(
        statusCode: Int?,
        error: Error?,
        attemptCount: Int,
        maxRetryCount: Int
    ) -> Bool {
        guard attemptCount < maxRetryCount else { return false }

        // RetryConfig 기반 재시도 판단
        if let statusCode = statusCode {
            return retryConfig.shouldRetryStatusCode(statusCode)
        }

        if let error = error, let urlError = error as? URLError {
            return retryConfig.shouldRetryURLError(urlError)
        }

        return false
    }

    func delayForRetry(attemptCount: Int, baseDelay: TimeInterval) -> TimeInterval {
        // 고정된 대기 시간 (Exponential 없음)
        return baseDelay
    }
}