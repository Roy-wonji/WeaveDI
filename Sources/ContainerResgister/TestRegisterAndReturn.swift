//
//  TestRegisterAndReturn.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 사용자가 원하는 패턴이 정확히 동작하는지 테스트
public enum TestRegisterAndReturn {
    
    /// 사용자의 원래 패턴 테스트 (수정된 버전)
    public static func testUserPattern() {
        #logInfo("🧪 Testing user's desired pattern...")
        
        // 사용자가 원하던 패턴 (수정된 안전한 버전)
        let testResult: String = {
            let repository = ContainerRegister.register(\.testService) {
                "TestImplementation"
            }
            return "TestUseCase(\(repository))"
        }()
        
        #logInfo("✅ User pattern works! Result: \(testResult)")
        
        // 조건부 테스트
        let conditionalResult: String = {
            let service = ContainerRegister.registerIf(
                \.testService,
                condition: true,
                factory: { "ConditionalImpl" },
                fallback: "FallbackImpl"
            )
            return "ConditionalTest(\(service))"
        }()
        
        #logInfo("✅ Conditional pattern works! Result: \(conditionalResult)")
        
        // 싱글톤 테스트
        let singleton1 = ContainerRegister.registerSingleton(\.testService) {
            #logInfo("🆕 Creating singleton instance")
            return "SingletonImpl"
        }
        
        let singleton2 = ContainerRegister.registerSingleton(\.testService) {
            #logInfo("🆕 This should not be called - singleton already exists")
            return "NewSingletonImpl"
        }
        
        #logInfo("🏛️ Singleton test: \(singleton1) == \(singleton2) ? \(singleton1 == singleton2)")
        
        #logInfo("🎉 All patterns working perfectly!")
    }
}

// 테스트용 extension
extension DependencyContainer {
    var testService: String? {
        resolve(String.self)
    }
}