//
//  DeveloperTools.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Developer Tools (Debug Only)

#if DEBUG

/// 개발자 전용 도구 모음
public struct DeveloperTools {

    // MARK: - Graph Generation Tools

    /// 의존성 그래프 생성 메뉴
    public static func showGraphGenerationMenu() {
        #logInfo("""
        🎨 DiContainer 개발자 도구
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        1️⃣  빠른 그래프 생성
        2️⃣  의존성 트리 출력
        3️⃣  순환 의존성 검사
        4️⃣  실시간 모니터링 시작
        5️⃣  문서 링크 검증
        0️⃣  종료

        사용법:
        DeveloperTools.generateQuickGraph()
        DeveloperTools.printDependencyTree()
        DeveloperTools.checkCircularDependencies()
        """)
    }

    /// 1️⃣ 빠른 그래프 생성
    public static func generateQuickGraph() {
        Task {
            do {
                #logInfo("🎨 빠른 그래프 생성 중...")
                try AutoGraphGenerator.quickGenerate()
                #logInfo("✅ 완료! dependency_graphs/ 폴더를 확인하세요.")
            } catch {
                #logError("❌ 생성 실패: \(error)")
            }
        }
    }

    /// 2️⃣ 의존성 트리 출력
    public static func printDependencyTree() {
        #logDebug("🌳 의존성 트리:")
        let tree = DependencyGraphVisualizer.shared.generateASCIIGraph(maxWidth: 60)
        #logDebug(tree)
    }

    /// 3️⃣ 순환 의존성 검사
    public static func checkCircularDependencies() {
        CircularDependencyDetector.shared.setDetectionEnabled(true)
        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()

        if cycles.isEmpty {
            #logInfo("✅ 순환 의존성이 발견되지 않았습니다.")
        } else {
            #logWarning("⚠️ \(cycles.count)개의 순환 의존성 발견:")
            for (index, cycle) in cycles.enumerated() {
                #logDebug("   \(index + 1). \(cycle.description)")
            }
        }
    }

    /// 4️⃣ 실시간 모니터링 시작
    public static func startRealtimeMonitoring() {
        let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("live_graphs")

        #logInfo("🔄 실시간 모니터링 시작...")
        #logDebug("📁 출력 디렉토리: \(outputDir.path)")
        #logDebug("⏱️ 5초마다 업데이트")

        AutoGraphGenerator.shared.startRealtimeGraphMonitoring(
            outputDirectory: outputDir,
            refreshInterval: 5.0
        )
    }

    /// 5️⃣ 문서 링크 검증
    public static func validateDocumentation() {
        Task {
            do {
                #logInfo("🔍 문서 링크 검증 중...")
                try DocumentationValidator.quickValidate(autoFix: false)
            } catch {
                #logError("❌ 검증 실패: \(error)")
            }
        }
    }

    // MARK: - Debugging Tools

    /// DI 컨테이너 상태 출력
    public static func printContainerStatus() {
        let statistics = CircularDependencyDetector.shared.getGraphStatistics()
        #logInfo("📊 DI 컨테이너 상태:")
        #logDebug(statistics.summary)
    }

    /// 성능 통계 출력
    public static func printPerformanceStats() {
        let stats = SimplePerformanceOptimizer.getStats()
        #logDebug("⚡ 성능 통계:")
        #logDebug(stats.summary)
    }

    // MARK: - Quick Access Commands

    /// 모든 도구를 한 번에 실행
    public static func runAllTools() {
        Task {
            #logDebug("🚀 모든 개발자 도구 실행 중...\n")

            printContainerStatus()
            print()

            checkCircularDependencies()
            print()

            printDependencyTree()
            print()

            generateQuickGraph()
            print()

            #logInfo("🎉 모든 도구 실행 완료!")
        }
    }
}

// MARK: - AppDelegate Integration

public extension DeveloperTools {

    /// AppDelegate에서 개발자 도구 설정
    static func setupForAppDelegate() {
        #logInfo("""
        🛠️ DiContainer 개발자 도구가 준비되었습니다!

        콘솔에서 다음 명령어를 사용하세요:
        • DeveloperTools.showGraphGenerationMenu()
        • DeveloperTools.runAllTools()
        • DeveloperTools.generateQuickGraph()

        또는 Xcode 디버그 콘솔에서:
        (lldb) po DeveloperTools.generateQuickGraph()
        """)
    }

    /// 조건부 도구 활성화 (환경변수 기반)
    static func enableIfRequested() {
        if ProcessInfo.processInfo.environment["ENABLE_DI_TOOLS"] == "true" {
            setupForAppDelegate()
        }
    }
}

#else

// Release 빌드에서는 빈 구현
public struct DeveloperTools {
    public static func setupForAppDelegate() {
        // Release 빌드에서는 아무것도 하지 않음
    }

    public static func enableIfRequested() {
        // Release 빌드에서는 아무것도 하지 않음
    }
}

#endif