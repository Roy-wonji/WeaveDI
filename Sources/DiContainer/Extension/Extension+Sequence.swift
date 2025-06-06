//
//  Extension+Sequence.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/25/25.
//

import Foundation

/// `Sequence` 타입에 비동기 순회(async-forEach) 기능을 추가하는 확장입니다.
///
/// - 설명:
///   - 이 메서드는 시퀀스의 각 요소에 대해 주어진 비동기 클로저를 순차적으로 실행합니다.
///   - 모든 요소 처리 중 예외가 발생하면 즉시 throw됩니다.
///   - `async rethrows`를 사용하여, 호출 측에서는 발생 가능한 오류를 처리할 수 있습니다.
public extension Sequence {
    
    /// 비동기로 시퀀스의 각 요소를 순회하며 클로저를 실행합니다.
    ///
    /// - Parameters:
    ///   - body: 각 요소에 대해 실행할 비동기 클로저. 요소를 인자로 받아 비동기 작업을 수행합니다.
    /// - Throws: 클로저 내부에서 발생하는 에러를 호출자에게 전파합니다.
    ///
    /// ```swift
    /// let numbers = [1, 2, 3, 4, 5]
    /// await numbers.asyncForEach { number in
    ///     // 요소마다 0.1초씩 대기
    ///     try await Task.sleep(nanoseconds: UInt64(number) * 100_000_000)
    ///     print("Processed number: \(number)")
    /// }
    /// ```
    ///
    /// 위 예시에서는 배열 `numbers`의 각 요소마다 0.1초씩 대기한 뒤 값을 출력합니다.
    ///
    /// - Note: 클로저는 순차적으로 실행되며, 다음 요소로 넘어가기 전에 이전 호출이 완료되어야 합니다.
    func asyncForEach(_ body: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await body(element)
        }
    }
}

/// ## 사용 예시
///
/// 1. 배열에서 `asyncForEach` 호출
/// ```swift
/// import Foundation
///
/// @main
/// struct MyApp {
///     static func main() async {
///         let words = ["apple", "banana", "cherry"]
///
///         do {
///             await words.asyncForEach { word in
///                 // 각 단어마다 0.2초 대기 후 출력
///                 try await Task.sleep(nanoseconds: 200_000_000)
///                 print("Word: \(word)")
///             }
///         } catch {
///             print("Error during iteration:", error)
///         }
///
///         print("All words processed.")
///     }
/// }
/// ```
///
/// 2. URL 목록을 비동기적으로 다운로드할 때 사용
/// ```swift
/// import Foundation
///
/// struct Downloader {
///     func download(from url: URL) async throws -> Data {
///         let (data, _) = try await URLSession.shared.data(from: url)
///         return data
///     }
/// }
///
/// @main
/// struct DownloadApp {
///     static func main() async {
///         let urls = [
///             URL(string: "https://example.com/file1")!,
///             URL(string: "https://example.com/file2")!
///         ]
///         let downloader = Downloader()
///
///         do {
///             try await urls.asyncForEach { url in
///                 let data = try await downloader.download(from: url)
///                 print("Downloaded \(data.count) bytes from \(url)")
///             }
///         } catch {
///             print("Download error:", error)
///         }
///
///         print("All downloads completed.")
///     }
/// }
/// ```
