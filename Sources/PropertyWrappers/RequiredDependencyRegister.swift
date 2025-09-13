//
//  RequiredDependencyRegister.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Required Dependency Register (Improved Version)

/// 필수 의존성 전용 프로퍼티 래퍼
/// 
/// 이 프로퍼티 래퍼는 반드시 등록되어야 하는 의존성에만 사용됩니다.
/// 등록되지 않은 의존성에 접근하면 상세한 디버깅 정보와 함께 앱이 종료됩니다.
///
/// ## 사용법:
/// ```swift
/// @RequiredDependency(\.userService)
/// private var userService: UserServiceProtocol
/// ```
///
/// ## 특징:
/// - 🔒 **엄격한 등록 강제**: 등록되지 않으면 즉시 앱 종료
/// - 📊 **상세한 디버깅 정보**: 문제 해결을 위한 풍부한 정보 제공
/// - ⚡ **빠른 성능**: 복잡한 자동 등록 로직 없음
/// - 🎯 **명확한 의도**: 필수 의존성임을 코드로 명시
@propertyWrapper
public struct RequiredDependency<T: Sendable> {
    
    // MARK: - Properties
    
    /// DependencyContainer 내부의 T? 프로퍼티를 가리키는 KeyPath
    private let keyPath: KeyPath<DependencyContainer, T?>
    
    /// 의존성이 사용된 위치 정보 (디버깅용)
    private let sourceLocation: SourceLocation
    
    // MARK: - Initialization
    
    /// 필수 의존성 프로퍼티 래퍼 생성
    /// 
    /// - Parameters:
    ///   - keyPath: 의존성을 가리키는 KeyPath
    ///   - file: 호출 파일 (자동 전달)
    ///   - function: 호출 함수 (자동 전달)  
    ///   - line: 호출 라인 (자동 전달)
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        self.keyPath = keyPath
        self.sourceLocation = SourceLocation(
            file: String(describing: file),
            function: String(describing: function),
            line: Int(line)
        )
    }
    
    // MARK: - Property Wrapper Implementation
    
    /// 의존성 인스턴스를 반환합니다
    /// 등록되지 않은 경우 상세한 디버깅 정보와 함께 앱이 종료됩니다
    public var wrappedValue: T {
        // 1. 먼저 등록된 의존성 확인
        if let value = DependencyContainer.live[keyPath: keyPath] {
            #logDebug("✅ [RequiredDI] Resolved \(T.self) successfully")
            return value
        }
        
        // 2. AutoRegistrationRegistry에서 직접 확인
        if let instance = AutoRegistrationRegistry.shared.createInstance(for: T.self) {
            #logInfo("🔧 [RequiredDI] Found \(T.self) in AutoRegistrationRegistry, registering to container")
            DependencyContainer.live.register(T.self, instance: instance)
            return instance
        }
        
        // 3. 등록되지 않음 - 상세한 에러 정보와 함께 종료
        generateEnhancedError()
    }
    
    // MARK: - Enhanced Error Generation
    
    /// 향상된 에러 정보를 생성하고 앱을 종료합니다
    private func generateEnhancedError() -> Never {
        let typeName = String(describing: T.self)
        let errorInfo = DependencyErrorInfo.collect(
            for: typeName,
            sourceLocation: sourceLocation,
            keyPath: keyPath
        )
        
        let errorMessage = DependencyErrorFormatter.format(errorInfo)
        
        // 로깅
        #logError("🚨 [RequiredDI] Critical dependency error for \(typeName)")
        #logError("📍 [RequiredDI] Location: \(sourceLocation.file):\(sourceLocation.line)")
        #logError("🔍 [RequiredDI] Function: \(sourceLocation.function)")
        
        fatalError(errorMessage)
    }
}

// MARK: - Source Location Tracking

/// 의존성이 사용된 소스 위치 정보
private struct SourceLocation {
    let file: String
    let function: String  
    let line: Int
    
    var shortFileName: String {
        URL(fileURLWithPath: file).lastPathComponent
    }
}

// MARK: - Dependency Error Information

/// 의존성 에러에 대한 상세 정보
private struct DependencyErrorInfo {
    let typeName: String
    let sourceLocation: SourceLocation
    let keyPath: String
    let systemState: SystemState
    let suggestions: [String]
    let similarTypes: [SimilarType]
    
    struct SystemState {
        let registeredCount: Int
        let bundleId: String
        let appVersion: String
        let buildNumber: String
        let isMainThread: Bool
        let operatingSystem: String
    }
    
    struct SimilarType {
        let name: String
        let similarity: Double
        
        var formattedSimilarity: String {
            String(format: "%.1f%%", similarity * 100)
        }
    }
    
    static func collect<T>(
        for typeName: String,
        sourceLocation: SourceLocation,
        keyPath: KeyPath<DependencyContainer, T?>
    ) -> DependencyErrorInfo {
        
        let systemState = SystemState(
            registeredCount: AutoRegistrationRegistry.shared.registeredCount,
            bundleId: Bundle.main.bundleIdentifier ?? "Unknown",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            isMainThread: Thread.isMainThread,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString
        )
        
        let suggestions = generateSuggestions(for: typeName)
        let similarTypes = findSimilarTypes(to: typeName)
        
        return DependencyErrorInfo(
            typeName: typeName,
            sourceLocation: sourceLocation,
            keyPath: String(describing: keyPath),
            systemState: systemState,
            suggestions: suggestions,
            similarTypes: similarTypes
        )
    }
    
    private static func generateSuggestions(for typeName: String) -> [String] {
        var suggestions: [String] = []
        
        // 기본 등록 방법
        suggestions.append("AutoRegister.add(\(typeName).self) { YourImplementation() }")
        
        // 일괄 등록 방법
        suggestions.append("""
        AutoRegister.addMany {
            Registration(\(typeName).self) { YourImplementation() }
        }
        """)
        
        // 네이밍 컨벤션 기반 제안
        if typeName.hasSuffix("Interface") {
            let baseName = String(typeName.dropLast("Interface".count))
            suggestions.append("Create implementation: \(baseName)Impl or \(baseName)Repository")
        } else if typeName.hasSuffix("Protocol") {
            let baseName = String(typeName.dropLast("Protocol".count))
            suggestions.append("Create implementation: \(baseName)Impl")
        }
        
        return suggestions
    }
    
    private static func findSimilarTypes(to typeName: String) -> [SimilarType] {
        let registeredTypes = AutoRegistrationRegistry.shared.getAllRegisteredTypeNames()
        
        return registeredTypes.compactMap { registeredType in
            let similarity = calculateStringSimilarity(typeName, registeredType)
            if similarity > 0.5 {
                return SimilarType(name: registeredType, similarity: similarity)
            }
            return nil
        }.sorted { $0.similarity > $1.similarity }
    }
    
    private static func calculateStringSimilarity(_ string1: String, _ string2: String) -> Double {
        let longer = string1.count > string2.count ? string1 : string2
        let shorter = string1.count > string2.count ? string2 : string1
        
        if longer.isEmpty { return 1.0 }
        
        let editDistance = levenshteinDistance(longer, shorter)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private static func levenshteinDistance(_ string1: String, _ string2: String) -> Int {
        let empty = [Int](repeating: 0, count: string2.count)
        var last = [Int](0...string2.count)
        
        for (i, char1) in string1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in string2.enumerated() {
                current[j + 1] = char1 == char2 ? last[j] : Swift.min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        
        return last.last!
    }
}

// MARK: - Error Message Formatter

/// 의존성 에러 메시지 포매터
private enum DependencyErrorFormatter {
    
    static func format(_ info: DependencyErrorInfo) -> String {
        return """
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                      🚨 REQUIRED DEPENDENCY MISSING 🚨                       ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  TYPE: \(info.typeName.padding(toLength: 67, withPad: " ", startingAt: 0))║
        ║  LOCATION: \(info.sourceLocation.shortFileName):\(String(info.sourceLocation.line).padding(toLength: 58, withPad: " ", startingAt: 0))║  
        ║  FUNCTION: \(info.sourceLocation.function.padding(toLength: 59, withPad: " ", startingAt: 0))║
        ║  KEYPATH: \(info.keyPath.padding(toLength: 60, withPad: " ", startingAt: 0))║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                           📊 SYSTEM DIAGNOSTICS                              ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  🔢 Registered Dependencies: \(String(info.systemState.registeredCount).padding(toLength: 44, withPad: " ", startingAt: 0))║
        ║  📱 Bundle ID: \(info.systemState.bundleId.padding(toLength: 58, withPad: " ", startingAt: 0))║
        ║  📦 App Version: \(info.systemState.appVersion.padding(toLength: 56, withPad: " ", startingAt: 0))║
        ║  🔨 Build: \(info.systemState.buildNumber.padding(toLength: 62, withPad: " ", startingAt: 0))║
        ║  🧵 Main Thread: \(String(info.systemState.isMainThread).padding(toLength: 56, withPad: " ", startingAt: 0))║
        ║  💻 OS: \(info.systemState.operatingSystem.padding(toLength: 66, withPad: " ", startingAt: 0))║
        ║                                                                               ║
        \(formatSimilarTypes(info.similarTypes))
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                             🔧 QUICK FIXES                                   ║  
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  1️⃣ REGISTER IN APP STARTUP:                                               ║
        ║     AutoRegister.add(\(info.typeName).self) { YourImpl() }        ║
        ║                                                                               ║
        ║  2️⃣ BATCH REGISTRATION:                                                    ║  
        ║     AutoRegister.addMany {                                                   ║
        ║         Registration(\(info.typeName).self) { YourImpl() }         ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║  3️⃣ CHECK IMPLEMENTATION EXISTS:                                           ║
        ║     - Verify your implementation class is accessible                         ║
        ║     - Check class has public initializer                                     ║
        ║     - Ensure no circular dependencies                                        ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                          💡 DEVELOPMENT TIPS                                ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  • Use @RequiredDependency for dependencies that MUST be registered          ║
        ║  • Register dependencies in AppDelegate or App.swift                         ║
        ║  • Consider using dependency injection patterns early in app lifecycle       ║
        ║  • Check DiContainer documentation for advanced patterns                     ║
        ║                                                                               ║  
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        
        💻 Complete Example:
        
        // In AppDelegate.swift or App.swift
        override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            
            AutoRegister.addMany {
                Registration(\(info.typeName).self) { 
                    // Your implementation here
                    YourImplementationClass() 
                }
            }
            
            return true
        }
        
        🆘 Need more help? Check: https://github.com/your-repo/DiContainer/issues
        """
    }
    
    private static func formatSimilarTypes(_ similarTypes: [DependencyErrorInfo.SimilarType]) -> String {
        if similarTypes.isEmpty {
            return ""
        }
        
        var result = """
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                          🔍 SIMILAR REGISTERED TYPES                         ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        """
        
        for type in similarTypes.prefix(5) { // 최대 5개만 표시
            let line = "║  📋 \(type.name) (\(type.formattedSimilarity) similar)"
            result += line.padding(toLength: 80, withPad: " ", startingAt: 0) + "║\n"
        }
        
        result += "║                                                                               ║\n"
        
        return result
    }
}