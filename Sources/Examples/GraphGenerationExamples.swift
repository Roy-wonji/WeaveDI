//
//  GraphGenerationExamples.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Graph Generation Examples

/// 그래프 생성 예제
public struct GraphGenerationExamples {

    // MARK: - Quick Start Examples

    /// 가장 간단한 그래프 생성 예제
    public static func quickGraphGeneration() async {
        #logInfo("🎨 Quick Graph Generation Example")

        // 1. 의존성 등록
        registerSampleDependencies()

        // 2. 자동 그래프 생성
        do {
            try AutoGraphGenerator.quickGenerate()
            #logInfo("✅ 그래프 생성 완료! dependency_graphs/ 폴더를 확인하세요.")
        } catch {
            #logError("❌ 그래프 생성 실패: \(error)")
        }
    }

    /// 실시간 모니터링 예제
    public static func realtimeGraphMonitoring() {
        #logInfo("🔄 Realtime Graph Monitoring Example")

        let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("live_graphs")

        // 5초마다 그래프 업데이트
        AutoGraphGenerator.shared.startRealtimeGraphMonitoring(
            outputDirectory: outputDir,
            refreshInterval: 5.0
        )

        #logInfo("📊 실시간 모니터링이 시작되었습니다.")
        #logInfo("💡 Ctrl+C로 중단할 수 있습니다.")
    }

    /// 순환 의존성 탐지 및 리포트 생성
    public static func circularDependencyDetection() async {
        #logInfo("🔍 Circular Dependency Detection Example")

        // 의존성 탐지 활성화
        CircularDependencyDetector.shared.setDetectionEnabled(true)

        // 순환 의존성 생성 (테스트용)
        createCircularDependencies()

        // 탐지 및 리포트 생성
        do {
            let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            try AutoGraphGenerator.shared.generateCircularDependencyReport(outputDirectory: outputDir)

            #logInfo("📋 순환 의존성 리포트가 생성되었습니다.")
        } catch {
            #logError("❌ 리포트 생성 실패: \(error)")
        }
    }

    /// 다양한 포맷으로 그래프 생성
    public static func multiFormatGraphGeneration() async {
        #logInfo("📊 Multi-format Graph Generation Example")

        registerSampleDependencies()

        let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("multi_format_graphs")

        do {
            try AutoGraphGenerator.shared.generateAllGraphs(
                outputDirectory: outputDir,
                formats: [.dot, .mermaid, .text, .json],
                options: GraphVisualizationOptions(
                    direction: .leftToRight,
                    nodeShape: .circle,
                    highlightCycles: true
                )
            )

            #logInfo("✅ 다중 포맷 그래프 생성 완료!")
            #logDebug("📁 출력 위치: \(outputDir.path)")
        } catch {
            #logError("❌ 그래프 생성 실패: \(error)")
        }
    }

    /// 의존성 트리 콘솔 출력
    public static func dependencyTreeConsoleOutput() {
        #logDebug("🌳 Dependency Tree Console Output Example")

        registerSampleDependencies()

        // 텍스트 기반 의존성 트리 출력
        #logDebug("\n📦 UserServiceProtocol 의존성 트리:")
        let tree = DependencyGraphVisualizer.shared.generateDependencyTree(
            "UserServiceProtocol",
            maxDepth: 4
        )
        #logDebug(tree)

        // ASCII 그래프 출력
        #logDebug("\n📊 전체 의존성 그래프:")
        let asciiGraph = DependencyGraphVisualizer.shared.generateASCIIGraph(maxWidth: 60)
        #logDebug(asciiGraph)
    }

    /// DOT 그래프 생성 및 이미지 변환
    public static func dotGraphWithImageConversion() async {
        #logDebug("🖼️ DOT Graph with Image Conversion Example")

        registerSampleDependencies()

        let dotGraph = DependencyGraphVisualizer.shared.generateDOTGraph(
            title: "DiContainer Dependencies",
            options: GraphVisualizationOptions(
                direction: .topToBottom,
                nodeShape: .box,
                backgroundColor: "#f8f9fa",
                edgeColor: "#6c757d"
            )
        )

        // DOT 파일 저장
        let dotURL = URL(fileURLWithPath: "dependency_graph.dot")
        do {
            try dotGraph.write(to: dotURL, atomically: true, encoding: .utf8)
            #logInfo("📄 DOT 파일 생성: \(dotURL.path)")

            #logDebug("\n💡 이미지 변환 명령어:")
            #logDebug("   PNG: dot -Tpng dependency_graph.dot -o graph.png")
            #logDebug("   SVG: dot -Tsvg dependency_graph.dot -o graph.svg")
            #logDebug("   PDF: dot -Tpdf dependency_graph.dot -o graph.pdf")
        } catch {
            #logError("❌ DOT 파일 저장 실패: \(error)")
        }
    }

    /// Mermaid 그래프 생성
    public static func mermaidGraphGeneration() {
        #logDebug("🧜‍♀️ Mermaid Graph Generation Example")

        registerSampleDependencies()

        let mermaidGraph = DependencyGraphVisualizer.shared.generateMermaidGraph(
            title: "DiContainer Mermaid Graph"
        )

        #logDebug("\n📋 Mermaid 그래프 (GitHub/Notion에서 사용 가능):")
        #logDebug("```mermaid")
        #logDebug(mermaidGraph)
        #logDebug("```")

        #logDebug("\n💡 온라인에서 확인하기: https://mermaid.live")
    }

    // MARK: - Private Helpers

    static func registerSampleDependencies() {
        // 기본 서비스들 등록
        UnifiedDI.register(UserService.self) { UserServiceImpl() }
        UnifiedDI.register(NetworkService.self) { URLSessionNetworkService() }
        UnifiedDI.register(LoggerService.self) { ConsoleLoggerService() }

        // 의존성 관계 기록 (그래프 생성용)
        CircularDependencyDetector.shared.recordDependency(
            from: "UserServiceProtocol",
            to: "NetworkServiceProtocol"
        )
        CircularDependencyDetector.shared.recordDependency(
            from: "UserServiceProtocol",
            to: "LoggerProtocol"
        )
        CircularDependencyDetector.shared.recordDependency(
            from: "NetworkServiceProtocol",
            to: "DatabaseService"
        )
    }

    private static func createCircularDependencies() {
        // 테스트용 순환 의존성 생성
        CircularDependencyDetector.shared.recordDependency(from: "ServiceA", to: "ServiceB")
        CircularDependencyDetector.shared.recordDependency(from: "ServiceB", to: "ServiceC")
        CircularDependencyDetector.shared.recordDependency(from: "ServiceC", to: "ServiceA")

        #logInfo("⚠️  테스트용 순환 의존성이 생성되었습니다: A → B → C → A")
    }
}

// MARK: - Demo Runner

/// 그래프 생성 데모 실행기
public struct GraphGenerationDemoRunner {

    public static func runAllExamples() async {
        #logInfo("🚀 Graph Generation Examples 시작\n")

        await GraphGenerationExamples.quickGraphGeneration()
        #logDebug("\n" + String(repeating: "─", count: 50) + "\n")

        GraphGenerationExamples.dependencyTreeConsoleOutput()
        #logDebug("\n" + String(repeating: "─", count: 50) + "\n")

        await GraphGenerationExamples.dotGraphWithImageConversion()
        #logDebug("\n" + String(repeating: "─", count: 50) + "\n")

        GraphGenerationExamples.mermaidGraphGeneration()
        #logDebug("\n" + String(repeating: "─", count: 50) + "\n")

        await GraphGenerationExamples.circularDependencyDetection()
        #logDebug("\n" + String(repeating: "─", count: 50) + "\n")

        await GraphGenerationExamples.multiFormatGraphGeneration()
        #logDebug("\n" + String(repeating: "─", count: 50) + "\n")

        #logInfo("🎉 모든 Graph Generation Examples 완료!")
        #logInfo("\n💡 TIP: 생성된 파일들을 확인해보세요:")
        #logInfo("   • dependency_graphs/ - 자동 생성된 그래프들")
        #logDebug("   • multi_format_graphs/ - 다양한 포맷의 그래프들")
        #logDebug("   • dependency_graph.dot - DOT 형식 그래프")
    }

    /// 간단한 CLI 도구
    public static func quickCLI() async {
        #logInfo("🎨 DiContainer Graph Generator")
        #logDebug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 의존성 등록
        GraphGenerationExamples.registerSampleDependencies()

        // 메뉴
        #logInfo("1️⃣  빠른 그래프 생성")
        #logDebug("2️⃣  의존성 트리 출력")
        #logDebug("3️⃣  순환 의존성 검사")
        #logInfo("4️⃣  모든 포맷 생성")

        // 모든 작업 실행
        await runAllExamples()
    }
}
