import Foundation
import os.lock

public struct ComponentMetadata: Sendable {
  public let componentName: String
  public let providedTypes: [String]
  public let propertyNames: [String]
  public let scopes: [String]
}

public enum ComponentMetadataRegistry {
  private static let lock = OSAllocatedUnfairLock(initialState: [ComponentMetadata]())

  public static func register(_ metadata: ComponentMetadata) {
    lock.withLockUnchecked { state in
      state.append(metadata)
    }
  }

  public static func allMetadata() -> [ComponentMetadata] {
    lock.withLock { $0 }
  }

  public static func reset() {
    lock.withLockUnchecked { state in
      state.removeAll(keepingCapacity: false)
    }
  }

  public static func dumpMetadata() -> String {
    let snapshot = allMetadata()
    guard !snapshot.isEmpty else { return "(no components registered)" }
    return snapshot.map { metadata in
      let props = zip(metadata.propertyNames, metadata.providedTypes).map { "    - \($0): \($1)" }.joined(separator: "\n")
      return "Component: \(metadata.componentName)\n  Provided:\n\(props)"
    }.joined(separator: "\n\n")
  }
}

private extension OSAllocatedUnfairLock {
  func withLockUnchecked(_ update: @Sendable (inout State) -> Void) {
    withLock { state in
      update(&state)
    }
  }
}
