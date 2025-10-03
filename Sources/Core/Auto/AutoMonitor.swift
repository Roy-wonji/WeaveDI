import Foundation
import LogMacro

/// 자동 모듈 모니터링 시스템
/// 모듈 등록 시 자동으로 그래프와 상태를 보여주는 간단한 시스템
@DIActor
public final class AutoMonitor {

  public static let shared = AutoMonitor()

#if DEBUG
  /// 런타임에서 모니터링을 끌 수 있는 플래그 (테스트 중에는 비활성화)
  public static var isEnabled: Bool = {
    // 테스트 환경에서는 자동으로 비활성화
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      return false
    }
    // 일반 DEBUG 환경에서는 활성화
    return true
  }()
#else
  /// 릴리즈 빌드에서는 기본적으로 비활성화
  public static var isEnabled = false
#endif

  // MARK: - 간단한 상태 저장

  private var modules: [String] = []
  private var dependencies: [(from: String, to: String)] = []
  private var moduleStates: [String: String] = [:]

  private init() {}

  // MARK: - 모듈 등록 시 자동 처리

  /// 모듈이 등록될 때마다 자동으로 호출됨
  public func onModuleRegistered<T>(_ type: T.Type) {
    guard Self.isEnabled else { return }
    let moduleName = String(describing: type)

    // 모듈 추가
    if !modules.contains(moduleName) {
      modules.append(moduleName)
      moduleStates[moduleName] = "등록됨"
    }

    emitSummary()
  }

  /// 의존성이 추가될 때마다 자동으로 호출됨
  public func onDependencyAdded<From, To>(from: From.Type, to: To.Type) {
    guard Self.isEnabled else { return }
    let fromName = String(describing: from)
    let toName = String(describing: to)

    dependencies.append((from: fromName, to: toName))

    emitSummary()
  }

  // MARK: - 자동 출력 시스템

  /// 현재 상태를 자동으로 보여줌
  private func showStatus() {
#if DEBUG
    guard Self.isEnabled else { return }
    #logInfo("\n🔍 === 모듈 상태 모니터링 ===")
    #logInfo("📦 등록된 모듈: \(modules.count)개")

    for (index, module) in modules.enumerated() {
      let state = moduleStates[module] ?? "알 수 없음"
      #logInfo("  \(index + 1). \(module) → \(state)")
    }

    #logInfo("🔗 의존성 연결: \(dependencies.count)개")
    #logInfo("========================\n")
#endif
  }

  /// 의존성 그래프를 자동으로 보여줌
  private func showGraph() {
#if DEBUG
    guard Self.isEnabled else { return }
    #logInfo("\n📊 === 의존성 그래프 ===")

    if dependencies.isEmpty {
      #logInfo("📋 아직 의존성이 없습니다")
    } else {
      #logInfo("🔗 의존성 관계:")
      for (index, dep) in dependencies.enumerated() {
        #logInfo("  \(index + 1). \(dep.from) → \(dep.to)")
      }
    }

    #logInfo("====================\n")
#endif
  }

  /// 간단한 현황 요약만 출력
  private func emitSummary() {
#if DEBUG
    guard Self.isEnabled else { return }
    #logInfo("[AutoMonitor] modules=\(modules.count) dependencies=\(dependencies.count) active=\(moduleStates.values.filter { $0 == "실행중" }.count)")
#endif
  }

  // MARK: - 상태 업데이트

  /// 모듈 상태 변경
  public func updateModuleState(_ moduleName: String, state: String) {
    moduleStates[moduleName] = state
    emitSummary()
  }

  // MARK: - 간단한 조회 API

  /// 전체 모듈 목록
  public func getModules() -> [String] {
    return modules
  }

  /// 의존성 목록
  public func getDependencies() -> [(from: String, to: String)] {
    return dependencies
  }

  /// 모듈 상태
  public func getModuleStates() -> [String: String] {
    return moduleStates
  }

  /// 간단한 요약 정보
  public func getSummary() -> String {
    return """
        📊 모듈 요약:
        • 등록된 모듈: \(modules.count)개
        • 의존성 연결: \(dependencies.count)개
        • 활성 모듈: \(moduleStates.values.filter { $0 == "실행중" }.count)개
        """
  }

  // MARK: - 초기화

  /// 모든 데이터 초기화
  public func reset() {
    modules.removeAll()
    dependencies.removeAll()
    moduleStates.removeAll()

#if DEBUG
    if Self.isEnabled {
      #logInfo("🔄 모니터링 시스템이 초기화되었습니다")
    }
#endif
  }
}

// MARK: - 쉬운 사용을 위한 확장

extension AutoMonitor {

  /// 한 번에 모든 정보 보기
  public func showAll() {
#if DEBUG
    guard Self.isEnabled else { return }
    showStatus()
    showGraph()
    #logInfo(getSummary())
#endif
  }

  /// 특정 모듈의 의존성만 보기
  public func showDependenciesFor(module: String) -> [String] {
#if DEBUG
    guard Self.isEnabled else { return [] }
    let deps = dependencies.filter { $0.from == module || $0.to == module }

    #logInfo("\n🔍 \(module)의 의존성:")
    for dep in deps {
      if dep.from == module {
        #logInfo("  → \(dep.to) (의존함)")
      } else {
        #logInfo("  ← \(dep.from) (의존받음)")
      }
    }

    return deps.map { $0.from == module ? $0.to : $0.from }
#else
    return []
#endif
  }
}
