import Dependencies

public extension DependencyValues {
  /// Provide an unlabeled subscript to avoid ambiguous overloads in Swift 6.1.
  subscript<Key: TestDependencyKey>(_ key: Key.Type) -> Key.Value {
    get { self[key: key] }
    set { self[key: key] = newValue }
  }
}
