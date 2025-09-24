//
//  ResponseHandler.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation
import LogMacro

// MARK: - Response Handler Protocol

/// HTTP 응답 처리를 담당하는 프로토콜
///
/// 상태 코드 검증, 데이터 디코딩 등의 응답 처리 책임을 분리합니다.
protocol ResponseHandler {
    /// HTTP 응답을 처리하고 디코딩합니다
    /// - Parameters:
    ///   - data: 응답 데이터
    ///   - response: URLResponse
    /// - Returns: 디코딩된 객체
    /// - Throws: 상태 코드, 디코딩 에러 등
    func handle<T: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> T
}

// MARK: - Default Response Handler

/// 기본 응답 처리 구현체
struct DefaultResponseHandler: ResponseHandler {

    func handle<T: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("No HTTP response received")
            throw DataError.noData
        }

        let statusCode = httpResponse.statusCode
        Log.debug("Received HTTP status code: \(statusCode)")

        // 상태 코드별 처리
        switch statusCode {
        case 200...299:
            return try decodeSuccessResponse(data: data, type: T.self)

        case 400:
            Log.error("Bad Request (400) for URL: \(response.url?.absoluteString ?? "No URL")")
            throw DataError.customError("Bad Request (400)")

        case 401:
            Log.error("Unauthorized (401) - Invalid credentials")
            throw DataError.customError("Unauthorized (401)")

        case 403:
            Log.error("Forbidden (403) - Access denied")
            throw DataError.customError("Forbidden (403)")

        case 404:
            Log.error("Not Found (404) for URL: \(response.url?.absoluteString ?? "No URL")")
            throw DataError.customError("Not Found (404)")

        case 429:
            Log.error("Too Many Requests (429) - Rate limited")
            throw DataError.customError("Too Many Requests (429)")

        case 500...599:
            Log.error("Server Error (\(statusCode))")
            throw DataError.unhandledStatusCode(statusCode)

        default:
            Log.error("Unhandled status code: \(statusCode)")
            throw DataError.unhandledStatusCode(statusCode)
        }
    }

    // MARK: - Private Methods

    /// 성공 응답 디코딩
    private func decodeSuccessResponse<T: Decodable>(
        data: Data,
        type: T.Type
    ) throws -> T {
        do {
            let decodedData = try data.decoded(as: T.self)
            Log.debug("Successfully decoded response as \(T.self)")
            return decodedData
        } catch {
            Log.error("Failed to decode response: \(error.localizedDescription)")
            throw DataError.decodingError(error)
        }
    }
}

// MARK: - Lenient Response Handler

/// 관대한 응답 처리 구현체 (500 에러에서도 디코딩 시도)
struct LenientResponseHandler: ResponseHandler {

    func handle<T: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("No HTTP response received")
            throw DataError.noData
        }

        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200...299:
            return try decodeResponse(data: data, type: T.self)

        case 400...499:
            Log.error("Client Error (\(statusCode))")
            throw DataError.unhandledStatusCode(statusCode)

        case 500...599:
            Log.error("Server Error (\(statusCode)), attempting to decode response")
            // 500 에러에서도 디코딩 시도 (서버가 에러와 함께 데이터를 보낼 수 있음)
            if let decodedData = try? decodeResponse(data: data, type: T.self) {
                Log.debug("Successfully decoded response despite server error")
                return decodedData
            } else {
                Log.error("Failed to decode server error response")
                throw DataError.unhandledStatusCode(statusCode)
            }

        default:
            Log.error("Unhandled status code: \(statusCode)")
            throw DataError.unhandledStatusCode(statusCode)
        }
    }

    // MARK: - Private Methods

    private func decodeResponse<T: Decodable>(
        data: Data,
        type: T.Type
    ) throws -> T {
        do {
            return try data.decoded(as: T.self)
        } catch {
            Log.error("Decoding failed: \(error.localizedDescription)")
            throw DataError.decodingError(error)
        }
    }
}