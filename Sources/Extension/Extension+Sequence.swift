//
//  Extension+Sequence.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/25/25.
//

import Foundation

// MARK: - Sequence + AsyncForEach

/// `Sequence`에 비동기 순회를 지원하는 기능을 추가하는 확장입니다.
///
/// # 개요
/// `asyncForEach`는 시퀀스를 순회하면서 주어진 비동기 클로저를
/// 각 요소마다 **순차적으로** 실행할 수 있게 합니다.
/// 이전 요소 처리가 완료될 때까지 다음 요소는 실행되지 않습니다.
///
/// - 클로저 내부에서 에러가 발생하면 즉시 순회가 중단되고 에러가 전파됩니다.
/// - `async rethrows`로 선언되어 있으므로, 호출 측은 발생 가능한 에러를 처리해야 하지만
///   오류가 발생하지 않는 클로저를 사용할 때는 별도의 `try`가 필요하지 않습니다.
///
/// ## 동시성
/// - 이 메서드는 **순차적**으로 실행됩니다. 병렬 실행이 필요하다면
///   `TaskGroup` 또는 `async let`을 사용하는 것이 적합합니다.
/// - 각 요소에 대한 클로저 호출이 완료될 때까지 다음 요소로 넘어가지 않습니다.
///
/// ## 예시
/// ```swift
/// let numbers = [1, 2, 3, 4, 5]
///
/// try await numbers.asyncForEach { number in
///     try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
///     print("처리된 숫자:", number)
/// }
/// ```
///
/// 위 코드는 배열의 각 숫자를 0.1초 간격으로 순차적으로 출력합니다.
///
/// ## 참고
/// - `asyncForEach`는 실행 순서가 중요하거나, 동시에 실행되면 안 되는 경우에 적합합니다.
/// - 독립적인 작업을 동시에 실행해야 한다면 `TaskGroup`을 사용하는 것이 더 효율적입니다.
public extension Sequence {
  
  /// 시퀀스를 비동기로 순회하며 주어진 클로저를 순차적으로 실행합니다.
  ///
  /// - Parameter body: 각 요소를 받아 비동기 작업을 수행하는 클로저.
  /// - Throws: 클로저 내부에서 발생한 에러가 호출자에게 전파됩니다.
  ///
  /// ```swift
  /// let words = ["apple", "banana", "cherry"]
  ///
  /// try await words.asyncForEach { word in
  ///     try await Task.sleep(nanoseconds: 200_000_000) // 0.2초 대기
  ///     print("단어:", word)
  /// }
  /// ```
  ///
  /// ## 중요
  /// 이 메서드는 **순차적**으로 실행됩니다.
  /// 각 요소가 끝나기 전까지 다음 요소가 실행되지 않습니다.
  func asyncForEach(_ body: (Element) async throws -> Void) async rethrows {
    for element in self {
      try await body(element)
    }
  }
}
