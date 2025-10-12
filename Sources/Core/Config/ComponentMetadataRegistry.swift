import Foundation

public struct ComponentMetadata: Sendable {
  public let componentName: String
  public let providedTypes: [String]
  public let propertyNames: [String]
  public let scopes: [String]
}

public enum ComponentMetadataRegistry {
  private static var storage: [ComponentMetadata] = []
  private static let lock = NSLock()

  public static func register(_ metadata: ComponentMetadata) {
    lock.lock()
    storage.append(metadata)
    lock.unlock()
  }

  public static func allMetadata() -> [ComponentMetadata] {
    lock.lock()
    let snapshot = storage
    lock.unlock()
    return snapshot
  }

  public static func reset() {
    lock.lock()
    storage.removeAll(keepingCapacity: false)
    lock.unlock()
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
