//
//  SafeDependencyKey.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 안전한 DependencyKey 패턴을 위한 확장
/// 
/// ## 문제가 있는 패턴:
/// ```swift
/// extension BookListUseCaseImpl: DependencyKey {
///     public static var liveValue: BookListInterface = {
///         // 🚨 이런 식으로 사용하면 안됨
///         let repository = SimpleKeyPathRegistry.register(\.bookListInterface) { ... }
///         return BookListUseCaseImpl(repository: repository as! BookListInterface)
///     }()
/// }
/// ```
/// 
/// ## ✅ 안전한 패턴들:
public enum SafeDependencyKeyPatterns {
    
    /// 방법 1: 앱 시작 시 사전 등록 + 해결
    public static let preRegistrationPattern = """
    // AppDelegate 또는 App.swift에서
    func setupDependencies() {
        // 🔒 먼저 의존성들을 등록
        SimpleKeyPathRegistry.register(\\.bookListInterface) {
            BookListRepositoryImpl()
        }
    }

    // DependencyKey 구현
    extension BookListUseCaseImpl: DependencyKey {
        public static var liveValue: BookListInterface = {
            // ✅ 이미 등록된 의존성 사용
            guard let repository = DependencyContainer.shared.resolve(BookListInterface.self) else {
                #logInfo("⚠️ BookListInterface not registered, using default")
                return DefaultBookListRepositoryImpl()
            }
            return BookListUseCaseImpl(repository: repository)
        }()
        
        public static var testValue: BookListInterface = DefaultBookListRepositoryImpl()
    }
    """
    
    /// 방법 2: Factory 지연 초기화 패턴
    public static let factoryPattern = """
    // Factory로 지연 초기화
    extension BookListUseCaseImpl: DependencyKey {
        public static var liveValue: BookListInterface = BookListUseCaseFactory.create()
        public static var testValue: BookListInterface = DefaultBookListRepositoryImpl()
    }

    private enum BookListUseCaseFactory {
        static func create() -> BookListInterface {
            // ✅ 안전한 해결
            @ContainerInject(\\.bookListInterface)
            var repository: BookListInterface?
            
            guard let repository = repository else {
                #logInfo("⚠️ BookListInterface not available, using default")
                return DefaultBookListRepositoryImpl()
            }
            
            return BookListUseCaseImpl(repository: repository)
        }
    }
    """
    
    /// 방법 3: Task 기반 비동기 등록 패턴
    public static let asyncPattern = """
    // 비동기 등록 후 사용
    extension BookListUseCaseImpl: DependencyKey {
        public static var liveValue: BookListInterface = {
            // ✅ 비동기로 등록하고 기본값 반환
            Task {
                await SimpleKeyPathRegistry.registerAsync(\\.bookListInterface) {
                    BookListRepositoryImpl()
                }
            }
            
            // 임시로 기본 구현 반환
            return DefaultBookListRepositoryImpl()
        }()
        
        public static var testValue: BookListInterface = DefaultBookListRepositoryImpl()
    }
    """
}

// MARK: - 안전한 DependencyKey 헬퍼

/// 안전한 DependencyKey 등록을 위한 헬퍼
public enum SafeDependencyRegister {
    
    /// 앱 시작 시 DependencyKey용 의존성 등록
    public static func setupForDependencyKeys() {
        #logInfo("🔧 Setting up dependencies for DependencyKey patterns...")
        
        // 일반적인 의존성들을 미리 등록
        // 예시: 실제 프로젝트에 맞게 수정
        // SimpleKeyPathRegistry.registerMany {
        //     (\.bookListInterface, { BookListRepositoryImpl() })
        //     (\.userService, { UserServiceImpl() })
        // }
        
        #logInfo("✅ DependencyKey dependencies setup complete")
    }
    
    /// KeyPath로 안전하게 의존성 해결
    public static func safeResolve<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> T? {
        let keyPathName = SimpleKeyPathRegistry.extractKeyPathName(keyPath)
        
        // DependencyContainer를 통해 의존성 해결
        if let resolved: T = DependencyContainer.live[keyPath: keyPath] {
            #logInfo("✅ [SafeDependencyRegister] Resolved \(keyPathName): \(type(of: resolved))")
            return resolved
        } else {
            #logInfo("⚠️ [SafeDependencyRegister] Failed to resolve \(keyPathName)")
            return nil
        }
    }
    
    /// KeyPath로 의존성 해결 (기본값 포함)
    public static func resolveWithFallback<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>, 
        fallback: @autoclosure () -> T
    ) -> T {
        if let resolved = safeResolve(keyPath) {
            return resolved
        } else {
            let fallbackInstance = fallback()
            let keyPathName = SimpleKeyPathRegistry.extractKeyPathName(keyPath)
            #logInfo("🔄 [SafeDependencyRegister] Using fallback for \(keyPathName): \(type(of: fallbackInstance))")
            return fallbackInstance
        }
    }
}

// MARK: - DependencyKey 확장

extension DependencyContainer {
    /// DependencyKey 지원을 위한 안전한 resolver
    func resolveSafely<T>(_ type: T.Type) -> T? {
        // 등록 여부 확인 후 안전하게 해결
        let resolved = resolve(type)
        if resolved != nil {
            #logInfo("✅ [DependencyContainer] Successfully resolved \(type)")
        } else {
            #logInfo("⚠️ [DependencyContainer] Type \(type) not registered")
        }
        return resolved
    }
}

// MARK: - 마이그레이션 가이드

public enum DependencyKeyMigrationGuide {
    public static func printMigrationSteps() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                    🔄 DEPENDENCYKEY MIGRATION GUIDE                          ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ ❌ BEFORE (문제가 있는 패턴):                                                ║
        ║ ─────────────────────────────────                                           ║
        ║                                                                               ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║   public static var liveValue: BookListInterface = {                        ║
        ║     let repository = SimpleKeyPathRegistry.register(\\.bookListInterface) {      ║
        ║       BookListRepositoryImpl()                                               ║
        ║     }                                                                        ║
        ║     return BookListUseCaseImpl(repository: repository as! BookListInterface) ║
        ║   }()                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 🚨 문제점:                                                                   ║
        ║ • MainActor 격리 위반                                                        ║
        ║ • 등록과 사용의 혼동 (register는 등록용, 값 반환용 아님)                    ║
        ║ • 강제 캐스팅 위험                                                           ║
        ║ • Static 초기화에서 비동기 작업 불가                                         ║
        ║                                                                               ║
        ║ ✅ AFTER (안전한 패턴):                                                     ║
        ║ ────────────────────────                                                     ║
        ║                                                                               ║
        ║ // 1. AppDelegate에서 사전 등록                                              ║
        ║ func setupDependencies() {                                                   ║
        ║   SimpleKeyPathRegistry.register(\\.bookListInterface) {                         ║
        ║     BookListRepositoryImpl()                                                 ║
        ║   }                                                                          ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 2. DependencyKey에서 안전한 해결                                          ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║   public static var liveValue: BookListInterface = {                        ║
        ║     return SafeDependencyRegister.resolveWithFallback(                      ║
        ║       \\.bookListInterface,                                                  ║
        ║       fallback: DefaultBookListRepositoryImpl()                             ║
        ║     )                                                                        ║
        ║   }()                                                                        ║
        ║                                                                               ║
        ║   public static var testValue: BookListInterface =                          ║
        ║     DefaultBookListRepositoryImpl()                                          ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 💡 핵심 원칙:                                                               ║
        ║ • 등록은 앱 시작 시 (AppDelegate/App.swift)                                  ║
        ║ • 사용은 필요한 곳에서 (ViewController/ViewModel)                            ║
        ║ • DependencyKey는 이미 등록된 것을 해결만                                    ║
        ║ • 항상 fallback 제공으로 안전성 확보                                        ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
}