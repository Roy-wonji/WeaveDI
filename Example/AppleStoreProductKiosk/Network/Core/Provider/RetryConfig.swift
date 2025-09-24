//
//  RetryConfig.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// MARK: - Retry Configuration

/// 재시도 관련 설정을 관리하는 구조체
///
/// 어떤 상태 코드와 에러에서 재시도할지 설정 가능합니다.
struct RetryConfig {
    /// 재시도 가능한 HTTP 상태 코드들
    let retryableStatusCodes: Set<Int>

    /// 재시도 가능한 URLError 코드들
    let retryableURLErrorCodes: Set<URLError.Code>

    /// 커스텀 초기화
    /// - Parameters:
    ///   - retryableStatusCodes: 재시도할 HTTP 상태 코드 집합
    ///   - retryableURLErrorCodes: 재시도할 URLError 코드 집합
    init(
        retryableStatusCodes: Set<Int> = [],
        retryableURLErrorCodes: Set<URLError.Code> = []
    ) {
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableURLErrorCodes = retryableURLErrorCodes
    }
}

// MARK: - Predefined Configurations

extension RetryConfig {

    /// 공격적 재시도 설정 (500 포함)
    /// - 일시적 문제일 가능성이 있는 모든 에러에서 재시도
    /// - 개발/테스트 환경에 적합
    static let aggressive = RetryConfig(
        retryableStatusCodes: [
            500,  // Internal Server Error - 서버 내부 오류
            502,  // Bad Gateway - 게이트웨이 오류
            503,  // Service Unavailable - 서비스 이용 불가
            504,  // Gateway Timeout - 게이트웨이 타임아웃
            429   // Too Many Requests - 요청 과다
        ],
        retryableURLErrorCodes: [
            .timedOut,                // 타임아웃
            .networkConnectionLost,   // 네트워크 연결 끊김
            .notConnectedToInternet,  // 인터넷 연결 없음
            .cannotConnectToHost      // 호스트 연결 불가
        ]
    )

    /// 보수적 재시도 설정 (500 제외)
    /// - 명확히 일시적인 문제로 판단되는 경우만 재시도
    /// - 프로덕션 환경에 적합
    static let conservative = RetryConfig(
        retryableStatusCodes: [
            502,  // Bad Gateway - 게이트웨이 문제
            503,  // Service Unavailable - 서버 과부하/점검
            504,  // Gateway Timeout - 게이트웨이 타임아웃
            429   // Too Many Requests - Rate limiting
        ],
        retryableURLErrorCodes: [
            .timedOut,                // 타임아웃만
            .networkConnectionLost    // 네트워크 연결 끊김만
        ]
    )

    /// 최소 재시도 설정
    /// - 네트워크 타임아웃과 서비스 이용 불가만 재시도
    /// - 매우 안정적인 서비스에 적합
    static let minimal = RetryConfig(
        retryableStatusCodes: [
            503,  // Service Unavailable만
            429   // Rate limiting만
        ],
        retryableURLErrorCodes: [
            .timedOut  // 타임아웃만
        ]
    )

    /// 재시도 없음
    /// - 모든 에러에서 즉시 실패
    /// - 디버깅이나 특수한 경우에 사용
    static let none = RetryConfig(
        retryableStatusCodes: [],
        retryableURLErrorCodes: []
    )

    /// 기본 설정 (보수적 설정 사용)
    static let `default` = conservative
}

// MARK: - Convenience Methods

extension RetryConfig {

    /// 주어진 상태 코드가 재시도 가능한지 확인
    /// - Parameter statusCode: HTTP 상태 코드
    /// - Returns: 재시도 가능 여부
    func shouldRetryStatusCode(_ statusCode: Int) -> Bool {
        return retryableStatusCodes.contains(statusCode)
    }

    /// 주어진 URLError가 재시도 가능한지 확인
    /// - Parameter error: URLError
    /// - Returns: 재시도 가능 여부
    func shouldRetryURLError(_ error: URLError) -> Bool {
        return retryableURLErrorCodes.contains(error.code)
    }

    /// 재시도 가능한 상태 코드를 추가한 새로운 설정 반환
    /// - Parameter statusCodes: 추가할 상태 코드들
    /// - Returns: 새로운 RetryConfig 인스턴스
    func addingStatusCodes(_ statusCodes: Int...) -> RetryConfig {
        var newStatusCodes = retryableStatusCodes
        statusCodes.forEach { newStatusCodes.insert($0) }

        return RetryConfig(
            retryableStatusCodes: newStatusCodes,
            retryableURLErrorCodes: retryableURLErrorCodes
        )
    }

    /// 재시도 가능한 상태 코드를 제거한 새로운 설정 반환
    /// - Parameter statusCodes: 제거할 상태 코드들
    /// - Returns: 새로운 RetryConfig 인스턴스
    func removingStatusCodes(_ statusCodes: Int...) -> RetryConfig {
        var newStatusCodes = retryableStatusCodes
        statusCodes.forEach { newStatusCodes.remove($0) }

        return RetryConfig(
            retryableStatusCodes: newStatusCodes,
            retryableURLErrorCodes: retryableURLErrorCodes
        )
    }
}