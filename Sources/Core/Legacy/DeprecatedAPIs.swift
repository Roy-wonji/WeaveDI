//
//  DeprecatedAPIs.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Deprecated Property Wrapper Aliases

// Note: ContainerInject and RequiredDependency already exist as separate property wrappers
// We'll mark them as deprecated in their own files instead of creating typealias conflicts

// MARK: - Deprecated Registration Methods

// Note: Deprecated methods are marked in their original files to avoid conflicts

public extension RegisterAndReturn {
    /// ❌ DEPRECATED: Use DI.register() which returns the registered instance
    @available(*, deprecated, message: "Use DI.register() instead. RegisterAndReturn.register() will be removed in v2.0. Note: DI.register() doesn't return the instance - use DI.resolve() after registration.")
    static func register<T: Sendable>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T
    ) -> T {
        let instance = factory()
        DI.register(T.self, factory: { instance })
        return instance
    }
}

// MARK: - Migration Guide

/// 📖 Migration Guide from Complex API to Simplified API
/// 
/// ## Old Complex Patterns → New Simple Patterns
/// 
/// ### Registration
/// ```swift
/// // ❌ Old (5 different ways):
/// AutoRegister.add(ServiceProtocol.self) { ServiceImpl() }
/// RegisterAndReturn.register(\.service) { ServiceImpl() }
/// ContainerRegister.register(\.service) { ServiceImpl() }
/// container.register(ServiceProtocol.self) { ServiceImpl() }
/// FactoryValues.current.customFactory = CustomFactory()
/// 
/// // ✅ New (1 simple way):
/// DI.register(ServiceProtocol.self) { ServiceImpl() }
/// ```
/// 
/// ### Property Wrappers
/// ```swift
/// // ❌ Old (4 different ways):
/// @ContainerInject(\.service) var service: ServiceProtocol?
/// @RequiredDependency(\.service) var service: ServiceProtocol
/// @ContainerRegisterWrapper(\.service) var service: ServiceProtocol?
/// @Factory(\.serviceFactory) var factory: ServiceFactory
/// 
/// // ✅ New (1 flexible way):
/// @Inject(\.service) var service: ServiceProtocol?     // Optional
/// @Inject(\.service) var service: ServiceProtocol      // Required
/// ```
/// 
/// ### Resolution
/// ```swift
/// // ❌ Old (multiple ways):
/// let service = DependencyContainer.live.resolve(ServiceProtocol.self)
/// let service = container.resolve(ServiceProtocol.self)
/// let service = AutoRegistrationRegistry.shared.createInstance(for: ServiceProtocol.self)
/// 
/// // ✅ New (1 simple way):
/// let service = DI.resolve(ServiceProtocol.self)
/// let service = DI.requireResolve(ServiceProtocol.self)  // For required deps
/// ```
/// 
/// ### Bulk Registration
/// ```swift
/// // ❌ Old:
/// AutoRegister.addMany {
///     Registration(ServiceA.self) { ServiceAImpl() }
///     Registration(ServiceB.self) { ServiceBImpl() }
/// }
/// 
/// // ✅ New:
/// DI.registerMany {
///     DIRegistration(ServiceA.self) { ServiceAImpl() }
///     DIRegistration(ServiceB.self) { ServiceBImpl() }
/// }
/// ```
public enum MigrationGuide {
    
    /// Shows the recommended migration path for each deprecated API
    public static let migrationSteps = """
    📋 DiContainer API Migration Steps:
    
    1. Replace Property Wrappers:
       @ContainerInject → @Inject
       @RequiredDependency → @Inject
       @ContainerRegisterWrapper → @Inject
       
    2. Replace Registration:
       AutoRegister.add() → DI.register()
       RegisterAndReturn.register() → DI.register()
       
    3. Replace Resolution:
       DependencyContainer.live.resolve() → DI.resolve()
       
    4. Simplify Bulk Registration:
       AutoRegister.addMany → DI.registerMany
       Registration → DIRegistration
       
    5. Remove Unused Imports:
       Remove imports of specific modules, use unified DiContainer
    """
    
    /// Validates that migration is complete by checking for usage of deprecated APIs
    public static func validateMigration() {
        #if DEBUG
        print("🔍 Migration Validation:")
        print("✅ If you see no deprecation warnings, migration is complete!")
        print("⚠️  Check for any remaining @ContainerInject, @RequiredDependency usage")
        print("⚠️  Check for any remaining AutoRegister.add() calls")  
        print("⚠️  Check for direct DependencyContainer.live usage")
        #endif
    }
}