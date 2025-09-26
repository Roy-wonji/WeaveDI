import Foundation
import WeaveDI
import LogMacro

// MARK: - Graph Changes (최근 변경 추적)

enum GraphChangeReader {
    static func show(limit: Int = 5) async {
        // 샘플 변화 기록: 의존성 엣지 추가하여 변경 이력에 항목이 생기도록 함
        struct NodeA: Sendable {}
        struct NodeB: Sendable {}
        await DependencyGraph.shared.addEdge(from: NodeA.self, to: NodeB.self, label: "uses")

        let changes = await UnifiedDI.getGraphChanges(limit: limit)
        for (ts, diff) in changes {
            #logInfo("🕒 [Graph] \(ts): \(diff)")
        }
    }
}
