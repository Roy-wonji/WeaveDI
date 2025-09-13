//
//  SimplifiedTests.swift  
//  DiContainerTests
//
//  Created by Claude on 2025-09-14.
//

//import XCTest
//@testable import DiContainer
//
//// MARK: - Simple Test Infrastructure
//
//protocol SimpleService: Sendable {
//    func getValue() -> String
//}
//
//final class SimpleServiceImpl: SimpleService, @unchecked Sendable {
//    func getValue() -> String {
//        return "simple_test_value"
//    }
//}
//
//// MARK: - Basic DI Container Tests
//
//final class SimplifiedDITests: XCTestCase {
//    
//    private var container: DependencyContainer!
//    
//    override func setUp() {
//        super.setUp()
//        container = DependencyContainer()
//    }
//    
//    override func tearDown() {
//        container = nil
//        super.tearDown()
//    }
//    
//    // MARK: - Core Functionality Tests
//    
//    func testBasicRegistrationAndResolution() {
//        // Given
//        container.register(SimpleService.self) { SimpleServiceImpl() }
//        
//        // When
//        let service = container.resolve(SimpleService.self)
//        
//        // Then
//        XCTAssertNotNil(service)
//        XCTAssertEqual(service?.getValue(), "simple_test_value")
//    }
//    
//    func testResolutionWithoutRegistration() {
//        // When
//        let service = container.resolve(SimpleService.self)
//        
//        // Then
//        XCTAssertNil(service, "Should return nil when no registration exists")
//    }
//    
//    func testInstanceRegistration() {
//        // Given
//        let sharedInstance = SimpleServiceImpl()
//        container.register(SimpleService.self, instance: sharedInstance)
//        
//        // When
//        let service1 = container.resolve(SimpleService.self)
//        let service2 = container.resolve(SimpleService.self)
//        
//        // Then
//        XCTAssertNotNil(service1)
//        XCTAssertNotNil(service2)
//        XCTAssertTrue(service1 as AnyObject === service2 as AnyObject, "Should return same instance")
//    }
//    
//    func testFactoryRegistration() {
//        // Given
//        container.register(SimpleService.self) { SimpleServiceImpl() }
//        
//        // When
//        let service1 = container.resolve(SimpleService.self)
//        let service2 = container.resolve(SimpleService.self)
//        
//        // Then
//        XCTAssertNotNil(service1)
//        XCTAssertNotNil(service2)
//        XCTAssertFalse(service1 as AnyObject === service2 as AnyObject, "Should return different instances")
//    }
//    
//    func testDependencyRelease() {
//        // Given
//        container.register(SimpleService.self) { SimpleServiceImpl() }
//        XCTAssertNotNil(container.resolve(SimpleService.self))
//        
//        // When
//        container.release(SimpleService.self)
//        
//        // Then
//        XCTAssertNil(container.resolve(SimpleService.self), "Should be nil after release")
//    }
//    
//    // MARK: - Thread Safety Tests
//    
//    func testConcurrentRegistration() {
//        let expectation = XCTestExpectation(description: "Concurrent registration")
//        expectation.expectedFulfillmentCount = 100
//        
//        // When - Register same type concurrently
//        DispatchQueue.concurrentPerform(iterations: 100) { _ in
//            self.container.register(SimpleService.self) { SimpleServiceImpl() }
//            expectation.fulfill()
//        }
//        
//        wait(for: [expectation], timeout: 10.0)
//        
//        // Then - Should still be able to resolve
//        let service = container.resolve(SimpleService.self)
//        XCTAssertNotNil(service)
//    }
//    
//    func testConcurrentResolution() {
//        // Given
//        container.register(SimpleService.self) { SimpleServiceImpl() }
//        
//        let expectation = XCTestExpectation(description: "Concurrent resolution")
//        expectation.expectedFulfillmentCount = 100
//        
//        // When - Resolve concurrently
//        DispatchQueue.concurrentPerform(iterations: 100) { _ in
//            let service = self.container.resolve(SimpleService.self)
//            XCTAssertNotNil(service)
//            expectation.fulfill()
//        }
//        
//        wait(for: [expectation], timeout: 10.0)
//    }
//    
//    // MARK: - RegisterAndReturn Tests
//    
//    func testRegisterAndReturnBasic() {
//        // When - Use ContainerRegister alias
//      let service = DI.register(SimpleService.self) {
//            SimpleServiceImpl()
//        }
//        
//        // Then
//        XCTAssertNotNil(service)
//        XCTAssertEqual(service, "simple_test_value")
//        
//        // Should also be registered in AutoRegister system
//        let resolved = DependencyContainer.live.resolve(SimpleService.self)
//        XCTAssertNotNil(resolved)
//    }
//    
////    // MARK: - AutoRegister Integration Tests
////    
////    func testAutoRegisterBasic() {
////        // When
////        AutoRegister.add(SimpleService.self) { SimpleServiceImpl() }
////        
////        // Then
////        let service = DependencyContainer.live.resolve(SimpleService.self)
////        XCTAssertNotNil(service)
////        XCTAssertEqual(service?.getValue(), "simple_test_value")
////    }
////    
////    func testAutoRegisterBulkRegistration() {
////        // When
////        AutoRegister.addMany {
////            Registration(SimpleService.self) { SimpleServiceImpl() }
////        }
////        
////        // Then
////        let service = DependencyContainer.live.resolve(SimpleService.self)
////        XCTAssertNotNil(service)
////    }
////    
////    // MARK: - Property Wrapper Tests (Simplified)
////    
////    func testContainerInjectPropertyWrapper() {
////        // Given - Register dependency
////        DependencyContainer.live.register(SimpleService.self) { SimpleServiceImpl() }
////        
////        // Create test class inline to avoid complex setup
////        final class TestClass {
////            @ContainerInject(\.testService)
////            var service: SimpleService?
////        }
////        
////        // When
////        let testInstance = TestClass()
////        
////        // Then
////        XCTAssertNotNil(testInstance.service)
////        XCTAssertEqual(testInstance.service?.getValue(), "simple_test_value")
////        
////        // Cleanup
////        DependencyContainer.live.release(SimpleService.self)
////    }
//}
//
//// MARK: - DependencyContainer Extension for Tests
//
//extension DependencyContainer {
//    var testService: SimpleService? {
//         resolve(SimpleService.self)
//    }
//}
