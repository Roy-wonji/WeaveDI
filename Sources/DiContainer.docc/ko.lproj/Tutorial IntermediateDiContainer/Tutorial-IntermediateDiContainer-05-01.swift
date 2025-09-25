import Foundation
import DiContainer
import LogMacro
import XCTest

// MARK: - 테스트 셋업: 격리/Mock 주입

final class IntermediateSetupTests: XCTestCase {
    @MainActor override func setUp() {
        super.setUp()
        UnifiedDI.releaseAll()
        UnifiedDI.setLogLevel(.off)
        // 샘플 Mock 등록
        _ = UnifiedDI.register(UUID.self) { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
    }
}
