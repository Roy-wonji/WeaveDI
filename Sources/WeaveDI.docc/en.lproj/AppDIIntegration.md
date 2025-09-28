# App DI Integration

Explains how to configure and bootstrap DI at the application level.

## SwiftUI Example
```swift
@main
struct MyApp: App {
  init() {
    Task { await WeaveDI.Container.bootstrap { c in
      c.register(LoggerProtocol.self) { ConsoleLogger() }
    }}
  }
  var body: some Scene { WindowGroup { ContentView() } }
}
```

## UIKit (AppDelegate) Example
```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Task { await WeaveDI.Container.bootstrapAsync { c in
      let db = await Database.initialize()
      c.register(Database.self, instance: db)
    }}
    return true
  }
}
```

---

📖 **Documentation**: [한국어](../ko.lproj/AppDIIntegration) | [English](AppDIIntegration)
