import Foundation
import DiContainer
import LogMacro

// MARK: - Circular Dependency Resolver

/// 순환 의존성을 감지하고 자동으로 해결하는 시스템

final class CircularDependencyResolver: @unchecked Sendable {
    private let accessQueue = DispatchQueue(label: "CircularDependencyResolver.access", attributes: .concurrent)
    private var _resolutionStack: [String] = []
    private var _detectedCycles: Set<String> = []
    private var _resolutionCache: [String: Any] = [:]

    /// 순환 의존성을 감지하면서 의존성을 해결합니다
    func resolveWithCycleDetection<T>(_ type: T.Type, container: DIContainer) async throws -> T {
        let typeName = String(describing: type)

        return try await accessQueue.sync {
            // 이미 해결 중인 타입인지 확인
            if _resolutionStack.contains(typeName) {
                _detectedCycles.insert(typeName)
                #logError("🔄 [CycleResolver] 순환 의존성 감지: \(typeName)")
                #logError("📍 [CycleResolver] 현재 스택: \(_resolutionStack.joined(separator: " -> "))")
                throw CircularDependencyError.cycleDetected(typeName: typeName, stack: _resolutionStack)
            }

            // 캐시에서 확인
            if let cached = _resolutionCache[typeName] as? T {
                #logInfo("💾 [CycleResolver] 캐시에서 반환: \(typeName)")
                return cached
            }

            // 해결 스택에 추가
            _resolutionStack.append(typeName)
            #logInfo("📥 [CycleResolver] 해결 시작: \(typeName)")

            defer {
                // 해결 완료 후 스택에서 제거
                _resolutionStack.removeAll { $0 == typeName }
                #logInfo("📤 [CycleResolver] 해결 완료: \(typeName)")
            }

            // 실제 의존성 해결
            guard let resolved = await container.resolve(type) else {
                throw CircularDependencyError.resolutionFailed(typeName: typeName)
            }

            // 캐시에 저장
            _resolutionCache[typeName] = resolved

            return resolved
        }
    }

    /// 감지된 순환 의존성 목록을 반환합니다
    func getDetectedCycles() -> [String] {
        return accessQueue.sync { Array(_detectedCycles) }
    }

    /// 해결책을 제안합니다
    func suggestSolutions(for cycles: [String]) -> [CircularDependencySolution] {
        var solutions: [CircularDependencySolution] = []

        for cycle in cycles {
            solutions.append(.useWeakReference(typeName: cycle))
            solutions.append(.introduceLazyLoading(typeName: cycle))
            solutions.append(.refactorWithInterface(typeName: cycle))
        }

        return solutions
    }

    /// 리셋
    func reset() {
        accessQueue.async(flags: .barrier) {
            self._resolutionStack.removeAll()
            self._detectedCycles.removeAll()
            self._resolutionCache.removeAll()
        }
    }
}

enum CircularDependencyError: Error, LocalizedError {
    case cycleDetected(typeName: String, stack: [String])
    case resolutionFailed(typeName: String)

    var errorDescription: String? {
        switch self {
        case .cycleDetected(let typeName, let stack):
            return "순환 의존성 감지: \(typeName), 스택: \(stack.joined(separator: " -> "))"
        case .resolutionFailed(let typeName):
            return "의존성 해결 실패: \(typeName)"
        }
    }
}

enum CircularDependencySolution: Sendable {
    case useWeakReference(typeName: String)
    case introduceLazyLoading(typeName: String)
    case refactorWithInterface(typeName: String)

    var description: String {
        switch self {
        case .useWeakReference(let typeName):
            return "약한 참조 사용: \(typeName)"
        case .introduceLazyLoading(let typeName):
            return "지연 로딩 도입: \(typeName)"
        case .refactorWithInterface(let typeName):
            return "인터페이스 분리: \(typeName)"
        }
    }
}

// MARK: - Usage Example

final class CircularDependencyExample {
    private let resolver = CircularDependencyResolver()
    private let container = DIContainer.shared

    func demonstrateCycleResolution() async {
        #logInfo("🔄 [CycleExample] 순환 의존성 해결 예제 시작")

        do {
            // 순환 의존성이 있는 타입을 해결 시도
            let _ = try await resolver.resolveWithCycleDetection(OrderProcessingUseCase.self, container: container)

        } catch let error as CircularDependencyError {
            #logError("❌ [CycleExample] 순환 의존성 오류: \(error.localizedDescription)")

            // 해결책 제안
            let cycles = resolver.getDetectedCycles()
            let solutions = resolver.suggestSolutions(for: cycles)

            #logInfo("💡 [CycleExample] 해결책 제안:")
            for solution in solutions {
                #logInfo("  • \(solution.description)")
            }
        }
    }
}