////
////  SimplifiedAPITests.swift
////  DiContainerTests
////
////  Created by Claude on 2025-09-14.
////
//
//import XCTest
//@testable import DiContainer
//
//// MARK: - Test Services
//
//protocol TestNetworkService: Sendable {
//    func fetchData() -> String
//}
//
//final class TestNetworkServiceImpl: TestNetworkService, @unchecked Sendable {
//    func fetchData() -> String {
//        return "network_data"
//    }
//}
//
//final class MockNetworkService: TestNetworkService, @unchecked Sendable {
//    func fetchData() -> String {
//        return "mock_data"
//    }
//}
//
//// MARK: - Simplified API Tests
//
//final class SimplifiedAPITests: XCTestCase {
//    
//    override func setUp() {
//        super.setUp()
//        // Clean slate for each test
//        DI.releaseAll()
//    }
//    
//    override func tearDown() {
//        DI.releaseAll()
//        super.tearDown()
//    }
//    
//    // MARK: - Basic Registration and Resolution Tests
//    
//    func testBasicRegistrationAndResolution() {
//        // When
//        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//        
//        // Then
//        let service = DI.resolve(TestNetworkService.self)
//        XCTAssertNotNil(service)
//        XCTAssertEqual(service?.fetchData(), "network_data")
//    }
//    
//    func testSingletonRegistration() {
//        // Given
//        let sharedInstance = TestNetworkServiceImpl()
//        
//        // When
//        DI.registerSingleton(TestNetworkService.self, instance: sharedInstance)
//        
//        // Then
//        let service1 = DI.resolve(TestNetworkService.self)
//        let service2 = DI.resolve(TestNetworkService.self)
//        
//        XCTAssertNotNil(service1)
//        XCTAssertNotNil(service2)
//        XCTAssertTrue(service1 as AnyObject === service2 as AnyObject)
//    }
//    
//    func testConditionalRegistration() {
//        // When - True condition
//        DI.registerIf(
//            TestNetworkService.self,
//            condition: true,
//            factory: { TestNetworkServiceImpl() },
//            fallback: { MockNetworkService() }
//        )
//        
//        // Then
//        let service = DI.resolve(TestNetworkService.self)
//        XCTAssertEqual(service?.fetchData(), "network_data")
//        
//        // Clean up and test false condition
//        DI.releaseAll()
//        
//        // When - False condition
//        DI.registerIf(
//            TestNetworkService.self,
//            condition: false,
//            factory: { TestNetworkServiceImpl() },
//            fallback: { MockNetworkService() }
//        )
//        
//        // Then
//        let mockService = DI.resolve(TestNetworkService.self)
//        XCTAssertEqual(mockService?.fetchData(), "mock_data")
//    }
//    
//    func testRequiredResolution() {
//        // Given
//        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//        
//        // When
//        let service = DI.requireResolve(TestNetworkService.self)
//        
//        // Then
//        XCTAssertEqual(service.fetchData(), "network_data")
//    }
//    
//    func testRequiredResolutionFailure() {
//        // When/Then - Should crash with meaningful message
//        // Note: This is hard to test since it causes fatalError
//        // In a real test, we'd use a different error handling mechanism
//        
//        // For now, we'll just test that it doesn't exist
//        let service = DI.resolve(TestNetworkService.self)
//        XCTAssertNil(service)
//    }
//    
//    func testResolutionWithDefault() {
//        // When - No registration
//        let service = DI.resolve(TestNetworkService.self, default: MockNetworkService())
//        
//        // Then
//        XCTAssertEqual(service.fetchData(), "mock_data")
//        
//        // When - With registration
//        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//        let registeredService = DI.resolve(TestNetworkService.self, default: MockNetworkService())
//        
//        // Then
//        XCTAssertEqual(registeredService.fetchData(), "network_data")
//    }
//    
//    // MARK: - Bulk Registration Tests
//    
//    func testBulkRegistration() {
//        // When
//        DI.registerMany {
//            DIRegistration(TestNetworkService.self) { TestNetworkServiceImpl() }
//            DIRegistration(SimpleService.self) { SimpleServiceImpl() }
//        }
//        
//        // Then
//        let networkService = DI.resolve(TestNetworkService.self)
//        let simpleService = DI.resolve(SimpleService.self)
//        
//        XCTAssertNotNil(networkService)
//        XCTAssertNotNil(simpleService)
//        XCTAssertEqual(networkService?.fetchData(), "network_data")
//        XCTAssertEqual(simpleService?.getValue(), "simple_test_value")
//    }
//    
//    // MARK: - Property Wrapper Tests
//    
////    func testInjectPropertyWrapper() {
////        // Given
////        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
////        
////        // When
////        final class TestClass {
////            @Inject(\.networkService) var service: TestNetworkService?
////            
////            func getData() -> String? {
////                return service?.fetchData()
////            }
////        }
////        
////        let testInstance = TestClass()
////        
////        // Then
////        XCTAssertNotNil(testInstance.service)
////        XCTAssertEqual(testInstance.getData(), "network_data")
////    }
//    
//    func testInjectPropertyWrapperRequired() {
//        // Given
//        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//        
//        // When
//        final class TestClass {
//            @Inject(\.networkService) var service: TestNetworkService
//            
//            func getData() -> String {
//                return service.fetchData()
//            }
//        }
//        
//        let testInstance = TestClass()
//        
//        // Then - Should not be nil for required dependency
//        XCTAssertEqual(testInstance.getData(), "network_data")
//    }
//    
//    // MARK: - Release and Cleanup Tests
//    
//    func testRelease() {
//        // Given
//        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//        XCTAssertNotNil(DI.resolve(TestNetworkService.self))
//        
//        // When
//        DI.release(TestNetworkService.self)
//        
//        // Then
//        XCTAssertNil(DI.resolve(TestNetworkService.self))
//    }
//    
//    func testReleaseAll() {
//        // Given
//        DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//        DI.register(SimpleService.self) { SimpleServiceImpl() }
//        
//        XCTAssertNotNil(DI.resolve(TestNetworkService.self))
//        XCTAssertNotNil(DI.resolve(SimpleService.self))
//        
//        // When
//        DI.releaseAll()
//        
//        // Then
//        XCTAssertNil(DI.resolve(TestNetworkService.self))
//        XCTAssertNil(DI.resolve(SimpleService.self))
//    }
//    
//    // MARK: - Thread Safety Tests
//    
//    func testConcurrentRegistrationAndResolution() {
//        let expectation = XCTestExpectation(description: "Concurrent operations")
//        expectation.expectedFulfillmentCount = 200 // 100 registrations + 100 resolutions
//        
//        // Concurrent registration
//        DispatchQueue.concurrentPerform(iterations: 100) { _ in
//            DI.register(TestNetworkService.self) { TestNetworkServiceImpl() }
//            expectation.fulfill()
//        }
//        
//        // Concurrent resolution
//        DispatchQueue.concurrentPerform(iterations: 100) { _ in
//            let service = DI.resolve(TestNetworkService.self)
//            XCTAssertNotNil(service) // Most should resolve successfully
//            expectation.fulfill()
//        }
//        
//        wait(for: [expectation], timeout: 10.0)
//        
//        // Final verification
//        let finalService = DI.resolve(TestNetworkService.self)
//        XCTAssertNotNil(finalService)
//    }
//    
//    // MARK: - Integration Tests
//    
////    func testCompleteWorkflow() {
////        // 1. Registration
////        DI.registerMany {
////            DIRegistration(TestNetworkService.self) { TestNetworkServiceImpl() }
////            DIRegistration(SimpleService.self) { SimpleServiceImpl() }
////        }
////        
////        // 2. Property wrapper injection
////        final class IntegratedTestClass {
////            @Inject(\.networkService) var networkService: TestNetworkService?
////            @Inject(\.testService) var testService: SimpleService?
////            
////            func performIntegratedOperation() -> String {
////                let networkData = networkService?.fetchData() ?? "no_network"
////                let testData = testService?.getValue() ?? "no_test"
////                return "\(networkData)_\(testData)"
////            }
////        }
////        
////        let integrated = IntegratedTestClass()
////        
////        // 3. Verification
////        let result = integrated.performIntegratedOperation()
////        XCTAssertEqual(result, "network_data_simple_test_value")
////        
////        // 4. Manual resolution
////        let manualNetwork = DI.requireResolve(TestNetworkService.self)
////        XCTAssertEqual(manualNetwork.fetchData(), "network_data")
////        
////        // 5. Cleanup
////        DI.releaseAll()
////        
////        // 6. Verify cleanup
////        XCTAssertNil(DI.resolve(TestNetworkService.self))
////        XCTAssertNil(DI.resolve(SimpleService.self))
////    }
//}
//
//// MARK: - DependencyContainer Extensions for Tests
//
//extension DependencyContainer {
//    var networkService: TestNetworkService? {
//        return resolve(TestNetworkService.self)
//    }
//}
