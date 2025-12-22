import Foundation
import WeaveDICore

public struct ComponentMetadata: Sendable {
  public let componentName: String
  public let providedTypes: [String]
  public let propertyNames: [String]
  public let scopes: [String]
}

private final class MetadataStorage: @unchecked Sendable {
  private var snapshot: [ComponentMetadata]
  private let lock = NSLock()

  init(_ initial: [ComponentMetadata] = []) {
    snapshot = initial
  }

  func withLock<T>(_ body: (inout [ComponentMetadata]) -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body(&snapshot)
  }
}

public enum ComponentMetadataRegistry {
  private static let storage = MetadataStorage()

  public static func register(_ metadata: ComponentMetadata) {
    storage.withLock { $0.append(metadata) }
  }

  public static func allMetadata() -> [ComponentMetadata] {
    storage.withLock { $0 }
  }

  public static func reset() {
    storage.withLock { $0.removeAll(keepingCapacity: false) }
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
