//
//  UnifiedRegistryFixTests.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import XCTest
@testable import WeaveDI

// MARK: - Test Services

protocol TestUnifiedRegistryService: Sendable {
  func getName() -> String
}

final class TestUnifiedRegistryServiceImpl: TestUnifiedRegistryService {
  private let name: String

  init(name: String = "test_unified_registry_service") {
    self.name = name
  }

  func getName() -> String { name }
}

// MARK: - Tests

final class UnifiedRegistryFixTests: XCTestCase {

  @MainActor
  override func setUp() async throws {
    try await super.setUp()
    UnifiedDI.releaseAll()
  }

  func testRegistrySeparationIssueFixed() async throws {
    // Given: 이전에는 DIContainer와 GlobalUnifiedRegistry가 분리되어 있었음

    // When: UnifiedDI를 통해 등록
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "registry_fix_test")
    }

    // Wait for async registration to complete
    await UnifiedDI.waitForRegistration()

    // Then: 같은 레지스트리를 사용하므로 해결 가능해야 함
    let resolvedService = UnifiedDI.resolve(TestUnifiedRegistryService.self)
    XCTAssertNotNil(resolvedService)
    XCTAssertEqual(resolvedService?.getName(), "registry_fix_test")

    // And: GlobalUnifiedRegistry에서도 직접 해결 가능해야 함
    let globalResolved = await GlobalUnifiedRegistry.resolveAsync(TestUnifiedRegistryService.self)
    XCTAssertNotNil(globalResolved)
    XCTAssertEqual(globalResolved?.getName(), "registry_fix_test")
  }

  func testDuplicateRegistrationPrevention() async throws {
    // Given: 서비스 등록
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "first_registration")
    }

    await UnifiedDI.waitForRegistration()

    // When: 동일한 타입을 다시 등록 (중복 등록)
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "second_registration")
    }

    await UnifiedDI.waitForRegistration()

    // Then: 최신 등록이 적용되어야 함 (중복 경고는 로그에 출력됨)
    let resolvedService = UnifiedDI.resolve(TestUnifiedRegistryService.self)
    XCTAssertNotNil(resolvedService)
    XCTAssertEqual(resolvedService?.getName(), "second_registration")
  }

  func testDetailedResolutionDiagnostics() async throws {
    // Given: 등록되지 않은 타입 해결 시도

    // When: 존재하지 않는 타입 해결 시도
    let nonExistentService = await GlobalUnifiedRegistry.resolveAsync(TestUnifiedRegistryService.self)

    // Then: 상세한 진단 정보가 로그에 출력되어야 함 (nil 반환)
    XCTAssertNil(nonExistentService)

    // And: 실제로 등록한 후에는 해결되어야 함
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "diagnostics_test")
    }

    await UnifiedDI.waitForRegistration()

    let resolvedService = await GlobalUnifiedRegistry.resolveAsync(TestUnifiedRegistryService.self)
    XCTAssertNotNil(resolvedService)
    XCTAssertEqual(resolvedService?.getName(), "diagnostics_test")
  }

  func testRegistryHealthVerification() async throws {
    // Given: 빈 레지스트리 상태
    let initialHealth = await UnifiedDI.getRegistryHealthScore()

    // When: 서비스들을 등록
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "health_test")
    }

    await UnifiedDI.waitForRegistration()

    // Then: 건강성 점수가 개선되어야 함
    let finalHealth = await UnifiedDI.getRegistryHealthScore()
    XCTAssertGreaterThanOrEqual(finalHealth, initialHealth)

    // And: 상세한 건강성 보고서 확인
    let report = await UnifiedDI.verifyRegistryHealth()
    XCTAssertGreaterThan(report.totalRegistrations, 0)
    XCTAssertGreaterThan(report.totalTypes, 0)
    XCTAssertGreaterThan(report.healthScore, 80.0) // 건강한 상태
  }

  func testOptimizationPathIntegration() async throws {
    // Given: 최적화 비활성화 상태
    await GlobalUnifiedRegistry.disableOptimization()

    // When: 서비스 등록 및 해결
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "optimization_test")
    }

    await UnifiedDI.waitForRegistration()

    let resolved = UnifiedDI.resolve(TestUnifiedRegistryService.self)
    XCTAssertNotNil(resolved)
    XCTAssertEqual(resolved?.getName(), "optimization_test")

    // And: 최적화 활성화 후에도 정상 작동
    await GlobalUnifiedRegistry.enableOptimization()

    let optimizedResolved = UnifiedDI.resolve(TestUnifiedRegistryService.self)
    XCTAssertNotNil(optimizedResolved)
    XCTAssertEqual(optimizedResolved?.getName(), "optimization_test")
  }

  func testRegistryAutoFix() async throws {
    // Given: 여러 타입 등록으로 복잡한 상태 생성
    _ = UnifiedDI.register(TestUnifiedRegistryService.self) {
      TestUnifiedRegistryServiceImpl(name: "auto_fix_test")
    }

    await UnifiedDI.waitForRegistration()

    // When: 자동 복구 시도
    let fixReport = await UnifiedDI.autoFixRegistry()

    // Then: 복구 보고서가 생성되어야 함
    XCTAssertGreaterThanOrEqual(fixReport.finalHealthScore, fixReport.originalHealthScore)

    // And: 복구 후 건강성 확인
    let finalReport = await UnifiedDI.verifyRegistryHealth()
    XCTAssertGreaterThan(finalReport.healthScore, 80.0)
  }
}
