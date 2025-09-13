//
//  KeyPathContainerRegister.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// KeyPath 기반 의존성 등록 시스템
/// 
/// ## 사용법:
/// ```swift
/// // 1. 기본 등록
/// ContainerRegister.register(\.userService) { UserServiceImpl() }
/// 
/// // 2. 조건부 등록
/// ContainerRegister.registerIf(\.analyticsService, condition: !isDebug) { 
///     AnalyticsServiceImpl() 
/// }
/// 
/// // 3. 비동기 등록
/// await ContainerRegister.registerAsync(\.networkService) { 
///     await NetworkServiceImpl() 
/// }
/// 
/// // 4. 인스턴스 등록
/// let sharedCache = CacheServiceImpl()
/// ContainerRegister.registerInstance(\.cacheService, instance: sharedCache)
/// ```
public enum ContainerRegister {
    
    // MARK: - Core Registration Methods
    
    /// KeyPath 기반 기본 등록
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - factory: 인스턴스를 생성하는 팩토리 클로저
    nonisolated public static func register<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let keyPathName = extractKeyPathName(keyPath)
        let typeInfo = TypeInfo(
            type: T.self,
            keyPath: keyPath,
            keyPathName: keyPathName,
            sourceLocation: SourceLocation(file: file, function: function, line: line)
        )
        
        #logInfo("📝 [ContainerRegister] Registering \(keyPathName) -> \(T.self)")
        
        let registration = Registration(T.self) {
            let instance = factory()
            #logInfo("✅ [ContainerRegister] Created instance for \(keyPathName): \(type(of: instance))")
            return instance
        }
        
        Task {
            await DependencyContainer.shared.registerWithTypeInfo(registration, typeInfo: typeInfo)
        }
    }
    
    /// KeyPath 기반 조건부 등록
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - condition: 등록 조건 (true일 때만 등록)
    ///   - factory: 인스턴스를 생성하는 팩토리 클로저
    nonisolated public static func registerIf<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let keyPathName = extractKeyPathName(keyPath)
        
        guard condition else {
            #logInfo("⏭️ [ContainerRegister] Skipping \(keyPathName) -> \(T.self) (condition: false)")
            return
        }
        
        #logInfo("✅ [ContainerRegister] Condition met for \(keyPathName) -> \(T.self)")
        register(keyPath, factory: factory, file: file, function: function, line: line)
    }
    
    /// KeyPath 기반 비동기 등록
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - factory: 인스턴스를 생성하는 비동기 팩토리 클로저
    public static func registerAsync<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () async -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) async {
        let keyPathName = extractKeyPathName(keyPath)
        let typeInfo = TypeInfo(
            type: T.self,
            keyPath: keyPath,
            keyPathName: keyPathName,
            sourceLocation: SourceLocation(file: file, function: function, line: line)
        )
        
        #logInfo("🔄 [ContainerRegister] Async registering \(keyPathName) -> \(T.self)")
        
        let registration = Registration(T.self) {
            let instance = await factory()
            #logInfo("✅ [ContainerRegister] Created async instance for \(keyPathName): \(type(of: instance))")
            return instance
        }
        
        await DependencyContainer.shared.registerWithTypeInfo(registration, typeInfo: typeInfo)
    }
    
    /// KeyPath 기반 인스턴스 등록 (이미 생성된 인스턴스 사용)
    /// - Parameters:
    ///   - keyPath: 의존성을 식별하는 KeyPath
    ///   - instance: 등록할 인스턴스
    nonisolated public static func registerInstance<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        instance: T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let keyPathName = extractKeyPathName(keyPath)
        let typeInfo = TypeInfo(
            type: T.self,
            keyPath: keyPath,
            keyPathName: keyPathName,
            sourceLocation: SourceLocation(file: file, function: function, line: line)
        )
        
        #logInfo("📦 [ContainerRegister] Registering instance \(keyPathName) -> \(type(of: instance))")
        
        let registration = Registration(T.self) {
            #logInfo("🎯 [ContainerRegister] Returning registered instance for \(keyPathName)")
            return instance
        }
        
        Task {
            await DependencyContainer.shared.registerWithTypeInfo(registration, typeInfo: typeInfo)
        }
    }
    
    // MARK: - Batch Registration
    
    /// 여러 의존성을 한 번에 등록
    nonisolated public static func registerMany(@RegistrationBuilder _ registrations: () -> [RegistrationItem]) {
        #logInfo("📦 [ContainerRegister] Starting batch registration...")
        let items = registrations()
        
        Task {
            for item in items {
                await item.execute()
            }
            #logInfo("✅ [ContainerRegister] Batch registration complete (\(items.count) items)")
        }
    }
    
    // MARK: - Debugging and Utilities
    
    /// 등록된 모든 KeyPath 의존성 디버깅 정보 출력
    nonisolated public static func debugPrintRegistrations() {
        Task {
            await DependencyContainer.shared.debugPrintKeyPathRegistrations()
        }
    }
    
    /// 특정 KeyPath의 등록 상태 확인
    nonisolated public static func isRegistered<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Bool {
        let keyPathName = extractKeyPathName(keyPath)
        #logInfo("🔍 [ContainerRegister] Checking registration for \(keyPathName)")
        return DependencyContainer.shared.isTypeRegistered(T.self)
    }
    
    /// KeyPath에서 이름 추출
    nonisolated private static func extractKeyPathName<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> String {
        let keyPathString = String(describing: keyPath)
        
        // KeyPath 문자열에서 프로퍼티 이름 추출
        // 예: \DependencyContainer.userService -> userService
        if let dotIndex = keyPathString.lastIndex(of: ".") {
            let propertyName = String(keyPathString[keyPathString.index(after: dotIndex)...])
            return propertyName
        }
        
        return keyPathString
    }
}

// MARK: - Supporting Types

/// 등록 아이템 (배치 등록용)
public struct RegistrationItem {
    private let executeBlock: @Sendable () async -> Void
    
    init<T>(
        keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        self.executeBlock = {
            await ContainerRegister.register(keyPath, factory: factory, file: file, function: function, line: line)
        }
    }
    
    init<T>(
        keyPath: KeyPath<DependencyContainer, T?>,
        instance: T,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        self.executeBlock = {
            await ContainerRegister.registerInstance(keyPath, instance: instance, file: file, function: function, line: line)
        }
    }
    
    func execute() async {
        await executeBlock()
    }
}

/// Registration Result Builder
@resultBuilder
public enum RegistrationBuilder {
    public static func buildBlock(_ components: RegistrationItem...) -> [RegistrationItem] {
        Array(components)
    }
    
    public static func buildExpression<T>(_ expression: (KeyPath<DependencyContainer, T?>, @Sendable () -> T)) -> RegistrationItem {
        RegistrationItem(keyPath: expression.0, factory: expression.1)
    }
    
    public static func buildExpression<T>(_ expression: (KeyPath<DependencyContainer, T?>, T)) -> RegistrationItem {
        RegistrationItem(keyPath: expression.0, instance: expression.1)
    }
}

/// 타입 정보 (디버깅용)
private struct TypeInfo {
    let type: Any.Type
    let keyPath: AnyKeyPath
    let keyPathName: String
    let sourceLocation: SourceLocation
}

/// 소스 위치 정보
private struct SourceLocation {
    let file: String
    let function: String
    let line: Int
    
    var description: String {
        let fileName = (file as NSString).lastPathComponent
        return "\(fileName):\(line) in \(function)"
    }
}

// MARK: - DependencyContainer Extensions

extension DependencyContainer {
    /// 타입 정보와 함께 등록
    fileprivate func registerWithTypeInfo<T>(_ registration: Registration<T>, typeInfo: TypeInfo) async {
        await register(registration)
        await storeTypeInfo(typeInfo)
    }
    
    /// 타입 정보 저장 (디버깅용)
    private func storeTypeInfo(_ typeInfo: TypeInfo) async {
        // 타입 정보를 내부적으로 저장하여 디버깅에 활용
        await keyPathTypeInfos.write { infos in
            infos[typeInfo.keyPathName] = typeInfo
        }
    }
    
    /// KeyPath 등록 정보 디버깅 출력
    fileprivate func debugPrintKeyPathRegistrations() async {
        let infos = await keyPathTypeInfos.read { $0 }
        
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                        🔍 KEYPATH REGISTRATIONS DEBUG                        ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        """)
        
        if infos.isEmpty {
            #logInfo("║  No KeyPath registrations found                                               ║")
        } else {
            for (keyPath, info) in infos.sorted(by: { $0.key < $1.key }) {
                #logInfo("║  \(keyPath.padding(toLength: 25, withPad: " ", startingAt: 0)) -> \(String(describing: info.type).padding(toLength: 30, withPad: " ", startingAt: 0)) ║")
                #logInfo("║      📍 \(info.sourceLocation.description.padding(toLength: 60, withPad: " ", startingAt: 0)) ║")
            }
        }
        
        #logInfo("""
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// KeyPath 타입 정보 저장소
    private var keyPathTypeInfos: SafeAsyncDictionary<String, TypeInfo> {
        if let existing = objc_getAssociatedObject(self, &keyPathTypeInfosKey) as? SafeAsyncDictionary<String, TypeInfo> {
            return existing
        }
        let new = SafeAsyncDictionary<String, TypeInfo>()
        objc_setAssociatedObject(self, &keyPathTypeInfosKey, new, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return new
    }
}

// Associated Object Key
private var keyPathTypeInfosKey: UInt8 = 0

/// 스레드 안전한 비동기 Dictionary
private actor SafeAsyncDictionary<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    
    func write<T>(_ operation: (inout [Key: Value]) -> T) -> T {
        return operation(&storage)
    }
    
    func read<T>(_ operation: ([Key: Value]) -> T) -> T {
        return operation(storage)
    }
}