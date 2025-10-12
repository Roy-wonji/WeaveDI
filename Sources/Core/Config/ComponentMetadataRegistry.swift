import Foundation

public struct ComponentMetadata: Sendable {
  public let componentName: String
  public let providedTypes: [String]
  public let propertyNames: [String]
  public let scopes: [String]
}

public enum ComponentMetadataRegistry {
  private static let state = ManagedCriticalState([ComponentMetadata]())

  public static func register(_ metadata: ComponentMetadata) {
    state.withCriticalRegion { storage in
      storage.append(metadata)
    }
  }

  public static func allMetadata() -> [ComponentMetadata] {
    state.withCriticalRegion { $0 }
  }

  public static func reset() {
    state.withCriticalRegion { storage in
      storage.removeAll(keepingCapacity: false)
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
