import WeaveDI

// MARK: - DI Container Setup

extension UnifiedDI {
    /// 앱의 모든 의존성을 설정합니다
    static func setupAppDependencies() {
        // 🌐 Network Layer
        _ = register(NetworkService.self) {
            DefaultNetworkService()
        }

        // 👤 Business Logic Layer
        _ = register(UserService.self) {
            DefaultUserService()
        }

        print("🚀 WeaveDI 설정 완료!")
        print("📦 등록된 서비스: NetworkService, UserService")
    }
}

// MARK: - App.swift에서 사용

import SwiftUI

@main
struct WeaveDIApp: App {

    init() {
        UnifiedDI.setupAppDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}