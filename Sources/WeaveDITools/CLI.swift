import Foundation
import WeaveDINeedleCompat
import WeaveDI

enum Command: String {
  case dumpMetadata = "dump-metadata"
  case diagnoseComponents = "diagnose-components"
  case checkComponentCycles = "check-cycles"
  case help = "help"
}

@main
struct WeaveDIToolsCLI {
  static func main() async {
    WeaveDIConfiguration.applyFromEnvironment()

    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let commandName = arguments.first,
          let command = Command(rawValue: commandName) else {
      printUsage()
      return
    }

    switch command {
    case .dumpMetadata:
      await runDumpMetadata()
    case .diagnoseComponents:
      await runDiagnoseComponents(showJSON: arguments.contains("--json"))
    case .checkComponentCycles:
      await runCheckComponentCycles(showJSON: arguments.contains("--json"))
    case .help:
      printUsage()
    }
  }

  private static func runDumpMetadata() async {
    await UnifiedDI.flushPendingRegistrations()
    let dump = UnifiedDI.dumpComponentMetadata()
    print(dump)
  }

  private static func runDiagnoseComponents(showJSON: Bool) async {
    await UnifiedDI.flushPendingRegistrations()
    let report = UnifiedDI.analyzeComponentMetadata()

    if showJSON {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      if let data = try? encoder.encode(report) {
        print(String(decoding: data, as: UTF8.self))
      } else {
        print("{}")
      }
      return
    }

    if report.issues.isEmpty {
      print("✅ Component diagnostics passed. No issues found.")
    } else {
      print("⚠️ Component diagnostics detected issues:")
      for issue in report.issues {
        print("- Type: \(issue.type)")
        print("  Providers: \(issue.providers.joined(separator: ", "))")
        if let detail = issue.detail {
          print("  Detail: \(detail)")
        }
      }
    }
  }

  private static func runCheckComponentCycles(showJSON: Bool) async {
    await UnifiedDI.flushPendingRegistrations()
    let report = UnifiedDI.detectComponentCycles()

    struct Payload: Codable {
      let cycles: [[String]]
      let componentCount: Int
      let edgeCount: Int
    }

    if showJSON {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let payload = Payload(
        cycles: report.cycles,
        componentCount: report.componentCount,
        edgeCount: report.edgeCount
      )
      if let data = try? encoder.encode(payload) {
        print(String(decoding: data, as: UTF8.self))
      } else {
        print("{}")
      }
      return
    }

    if report.cycles.isEmpty {
      print("✅ No component cycles detected (\(report.componentCount) components, \(report.edgeCount) edges).")
      return
    }

    print("⚠️ Detected component cycles: \(report.cycles.count)")
    for (index, cycle) in report.cycles.enumerated() {
      let path = cycle.joined(separator: " -> ")
      print("\(index + 1). \(path)")
    }
  }

  private static func printUsage() {
    print(
      """
      Usage: weaveditools <command> [options]

        dump-metadata             Dump registered component metadata in a readable form
        diagnose-components       Run duplicate/scope diagnostics (pass --json for JSON output)
        check-cycles              Detect simple component-level cycles from compile-time metadata
        help                      Show this help
      """
    )
  }
}
