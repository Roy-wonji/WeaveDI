import Foundation

/// 등록 시 생성되는 여러 모니터링 태스크를 하나의 배치 파이프라인으로 모읍니다.
final class RegistrationMetricsDispatcher: @unchecked Sendable {
  typealias Job = @Sendable () async -> Void

  static let shared = RegistrationMetricsDispatcher()

  private let lock = NSLock()
  private var pending: [Job] = []
  private var isScheduled = false

  private init() {}

  func enqueueRegistration<T>(_ type: T.Type) where T: Sendable {
    guard let hook = OptimizationHooks.trackRegistration else { return }
    enqueue {
      hook(type)
    }
  }

  private func enqueue(_ job: @escaping Job) {
    var shouldSchedule = false
    lock.lock()
    pending.append(job)
    if !isScheduled {
      isScheduled = true
      shouldSchedule = true
    }
    lock.unlock()

    if shouldSchedule {
      Task(priority: .utility) {
        await self.flush()
      }
    }
  }

  private func flush() async {
    while true {
      let jobs = nextBatch()
      if jobs.isEmpty { break }
      for job in jobs {
        await job()
      }
    }
  }

  private func nextBatch() -> [Job] {
    lock.lock()
    let jobs = pending
    pending.removeAll()
    if pending.isEmpty {
      isScheduled = false
    }
    lock.unlock()
    return jobs
  }
}
