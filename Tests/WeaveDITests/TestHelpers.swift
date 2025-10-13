//
//  TestHelpers.swift
//  DiContainerTests
//
//  Lightweight utilities to reduce test flakiness by polling
//  instead of using fixed sleeps.
//

import XCTest

extension XCTestCase {
    /// Polls the given condition until it returns true or the timeout elapses.
    /// Uses an XCTestExpectation under the hood.
    func waitUntil(
        description: String = "waitUntil",
        timeout: TimeInterval = 2.0,
        pollInterval: TimeInterval = 0.05,
        condition: @escaping () -> Bool
    ) {
        let exp = expectation(description: description)
        let queue = DispatchQueue.global(qos: .userInitiated)
        let timer = DispatchSource.makeTimerSource(queue: queue)

        var fulfilled = false
        timer.schedule(deadline: .now(), repeating: pollInterval)
        timer.setEventHandler {
            if fulfilled { return }
            if condition() {
                fulfilled = true
                timer.cancel()
                exp.fulfill()
            }
        }
        timer.resume()

        wait(for: [exp], timeout: timeout)
        if !fulfilled { timer.cancel() }
    }

    /// Async variant that polls an async condition until true or timeout.
    @discardableResult
    func waitAsyncUntil(
        timeout: TimeInterval = 2.0,
        pollInterval: TimeInterval = 0.05,
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            let nanos = UInt64(pollInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }
        return await condition()
    }
}
