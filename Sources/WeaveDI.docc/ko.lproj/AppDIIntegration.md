# App DI Integration

애플리케이션 레벨에서 DI를 구성하고 부트스트랩하는 방법을 설명합니다.

## SwiftUI 예시
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

## UIKit(AppDelegate) 예시
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

