//
//  AsyncProvider.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation
import LogMacro

/// 개선된 비동기 네트워크 Provider
///
/// SOLID 원칙을 준수하며 책임을 분리한 네트워크 요청 처리 클래스입니다.
/// - 설정 분리: NetworkConfig
/// - 재시도 전략 분리: RetryStrategy
/// - 응답 처리 분리: ResponseHandler
/// - 재시도 설정 분리: RetryConfig
///
/// ## 사용 예시:
/// ```swift
/// // 1. 기본 설정 (보수적 재시도 - 500 에러 제외)
/// let provider = AsyncProvider<KioskProductService>()
///
/// // 2. 공격적 재시도 (500 에러 포함)
/// let aggressiveProvider = AsyncProvider<KioskProductService>.aggressive()
///
/// // 3. 재시도 없음
/// let noRetryProvider = AsyncProvider<KioskProductService>.noRetry()
///
/// // 4. 커스텀 설정
/// let customProvider = AsyncProvider<KioskProductService>(
///     retryConfig: .aggressive.addingStatusCodes(408)
/// )
/// ```
final class AsyncProvider<T: TargetType> {

    // MARK: - Properties

    /// 사용할 URLSession
    private let session: URLSession

    /// 네트워크 설정
    private let config: NetworkConfig

    /// 재시도 전략
    private let retryStrategy: RetryStrategy

    /// 응답 처리기
    private let responseHandler: ResponseHandler

    // MARK: - Initialization

    /// Provider 초기화
    /// - Parameters:
    ///   - session: URLSession (기본값: .shared)
    ///   - config: 네트워크 설정 (기본값: .default)
    ///   - retryConfig: 재시도 설정 (기본값: .default)
    ///   - retryStrategy: 재시도 전략 (기본값: nil, retryConfig 기반으로 자동 생성)
    ///   - responseHandler: 응답 처리기 (기본값: DefaultResponseHandler)
    init(
        session: URLSession = .shared,
        config: NetworkConfig = .default,
        retryConfig: RetryConfig = .default,
        retryStrategy: RetryStrategy? = nil,
        responseHandler: ResponseHandler = DefaultResponseHandler()
    ) {
        self.session = session
        self.config = config
        self.retryStrategy = retryStrategy ?? DefaultRetryStrategy(retryConfig: retryConfig)
        self.responseHandler = responseHandler
    }

    // MARK: - Convenience Initializers

    /// 공격적 재시도 전략으로 Provider 생성 (500 에러도 재시도)
    /// - Parameters:
    ///   - session: URLSession (기본값: .shared)
    ///   - config: 네트워크 설정 (기본값: .default)
    ///   - responseHandler: 응답 처리기 (기본값: DefaultResponseHandler)
    static func aggressive(
        session: URLSession = .shared,
        config: NetworkConfig = .default,
        responseHandler: ResponseHandler = DefaultResponseHandler()
    ) -> AsyncProvider<T> {
        return AsyncProvider(
            session: session,
            config: config,
            retryConfig: .aggressive,
            responseHandler: responseHandler
        )
    }

    /// 보수적 재시도 전략으로 Provider 생성 (500 에러 제외)
    /// - Parameters:
    ///   - session: URLSession (기본값: .shared)
    ///   - config: 네트워크 설정 (기본값: .default)
    ///   - responseHandler: 응답 처리기 (기본값: DefaultResponseHandler)
    static func conservative(
        session: URLSession = .shared,
        config: NetworkConfig = .default,
        responseHandler: ResponseHandler = DefaultResponseHandler()
    ) -> AsyncProvider<T> {
        return AsyncProvider(
            session: session,
            config: config,
            retryConfig: .conservative,
            responseHandler: responseHandler
        )
    }

    /// 최소 재시도 전략으로 Provider 생성
    /// - Parameters:
    ///   - session: URLSession (기본값: .shared)
    ///   - config: 네트워크 설정 (기본값: .default)
    ///   - responseHandler: 응답 처리기 (기본값: DefaultResponseHandler)
    static func minimal(
        session: URLSession = .shared,
        config: NetworkConfig = .default,
        responseHandler: ResponseHandler = DefaultResponseHandler()
    ) -> AsyncProvider<T> {
        return AsyncProvider(
            session: session,
            config: config,
            retryConfig: .minimal,
            responseHandler: responseHandler
        )
    }

    /// 재시도 없는 Provider 생성
    /// - Parameters:
    ///   - session: URLSession (기본값: .shared)
    ///   - config: 네트워크 설정 (기본값: .default)
    ///   - responseHandler: 응답 처리기 (기본값: DefaultResponseHandler)
    static func noRetry(
        session: URLSession = .shared,
        config: NetworkConfig = .default,
        responseHandler: ResponseHandler = DefaultResponseHandler()
    ) -> AsyncProvider<T> {
        return AsyncProvider(
            session: session,
            config: config,
            retryConfig: .none,
            responseHandler: responseHandler
        )
    }

    // MARK: - Public Methods

    /// 비동기 네트워크 요청을 실행하고 응답을 디코딩합니다.
    ///
    /// - Parameters:
    ///   - target: API 요청 정보를 담은 TargetType
    ///   - type: 디코딩할 Decodable 타입
    /// - Returns: 디코딩된 객체
    /// - Throws: 네트워크/디코딩/상태코드 에러 등
    func requestAsync<D: Decodable & Sendable>(
        _ target: T,
        decodeTo type: D.Type
    ) async throws -> D {
        let request = URLRequestBuilder.buildRequest(from: target)

        // 요청 로깅
        await URLSessionLogger.shared.logRequest(request)

        return try await executeWithRetry(
            request: request,
            decodeTo: type,
            attemptCount: 0
        )
    }

    // MARK: - Private Methods

    /// 재시도 로직을 포함한 네트워크 요청 실행
    private func executeWithRetry<D: Decodable & Sendable>(
        request: URLRequest,
        decodeTo type: D.Type,
        attemptCount: Int
    ) async throws -> D {
        do {
            // 네트워크 요청 실행
            let (data, response) = try await session.data(for: request)

            // 응답 로깅
            await URLSessionLogger.shared.logResponse(
                data: data,
                response: response,
                error: nil
            )

            // 응답 처리 및 디코딩
            return try responseHandler.handle(data: data, response: response)

        } catch {
            // 에러 로깅
            await URLSessionLogger.shared.logResponse(
                data: nil,
                response: nil,
                error: error
            )

            Log.error("Network request failed (attempt \(attemptCount + 1)): \(error.localizedDescription)")

            // 재시도 여부 판단
            let statusCode = extractStatusCode(from: error)
            let shouldRetry = retryStrategy.shouldRetry(
                statusCode: statusCode,
                error: error,
                attemptCount: attemptCount,
                maxRetryCount: config.maxRetryCount
            )

            if shouldRetry {
                // 재시도 대기
                let delay = retryStrategy.delayForRetry(
                    attemptCount: attemptCount,
                    baseDelay: config.baseRetryDelay
                )

                Log.info("Retrying request after \(delay) seconds (attempt \(attemptCount + 2))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // 재귀 호출로 재시도
                return try await executeWithRetry(
                    request: request,
                    decodeTo: type,
                    attemptCount: attemptCount + 1
                )
            } else {
                // 재시도 불가능한 경우 원래 에러 던지기
                Log.error("Request failed permanently after \(attemptCount + 1) attempts")
                throw error
            }
        }
    }

    /// 에러에서 상태 코드 추출 (있는 경우)
    private func extractStatusCode(from error: Error) -> Int? {
        if let dataError = error as? DataError {
            switch dataError {
            case .unhandledStatusCode(let code):
                return code
            default:
                return nil
            }
        }
        return nil
    }
}

// MARK: - Sendable Conformance

extension AsyncProvider: @unchecked Sendable {}