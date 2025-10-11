# ComponentDiagnostics API

## Overview

`ComponentDiagnostics` is WeaveDI's revolutionary automatic diagnosis system. This exclusive feature, not found in other DI frameworks, automatically detects dependency configuration issues at compile time and suggests solutions.

## 🚀 Overwhelming Advantages over Needle/Swinject

| Feature | WeaveDI | Needle | Swinject |
|---------|---------|--------|----------|
| **Auto Duplicate Detection** | ✅ Fully Automatic | ❌ None | ❌ None |
| **Scope Consistency Check** | ✅ Auto Detection | ⚠️ Manual Check | ❌ None |
| **Auto Solution Suggestions** | ✅ Detailed Reports | ❌ None | ❌ None |
| **Compile-time Validation** | ✅ Instant Detection | ⚠️ Limited | ❌ Runtime Only |

## Core Features

### 🔍 Automatic Duplicate Provider Detection
```swift
// Problem: Multiple Components providing same type
@Component
struct AppComponent {
    @Provide var userService: UserService { UserServiceImpl() }
}

@Component
struct TestComponent {
    @Provide var userService: UserService { MockUserService() }  // Duplicate!
}

// Automatic detection and reporting
let diagnostics = UnifiedDI.analyzeComponentMetadata()
for issue in diagnostics.issues {
    print("⚠️ \(issue.type): \(issue.detail)")
    print("   Providers: \(issue.providers)")
}

// Output:
// ⚠️ UserService: Multiple components provide this type.
//    Providers: [AppComponent, TestComponent]
```

### ⚙️ Automatic Scope Inconsistency Check
```swift
// Problem: Same type with different scope settings
@Component
struct NetworkComponent {
    @Provide(.singleton) var apiClient: APIClient { APIClientImpl() }
}

@Component
struct CacheComponent {
    @Provide(.transient) var apiClient: APIClient { APIClientImpl() }  // Scope mismatch!
}

// Automatic detection
let diagnostics = UnifiedDI.analyzeComponentMetadata()
// Output:
// ⚠️ APIClient: Inconsistent scopes: singleton, transient
//    Providers: [NetworkComponent, CacheComponent]
```

## API Reference

### ComponentDiagnostics Struct

```swift
public struct ComponentDiagnostics: Codable, Sendable {
    public struct Issue: Codable, Sendable {
        public let type: String        // Type name with issues
        public let providers: [String] // Components providing this type
        public let detail: String?     // Detailed problem description
    }

    public let issues: [Issue]
}
```

### Metadata Analysis Method

```swift
/// Analyze compile-time Component metadata
public static func analyzeComponentMetadata() -> ComponentDiagnostics
```

**Usage:**
```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()

if diagnostics.issues.isEmpty {
    print("✅ All Component configurations are perfect!")
} else {
    print("⚠️ \(diagnostics.issues.count) issues found:")

    for issue in diagnostics.issues {
        print("\n🔍 Type: \(issue.type)")
        print("   Problem: \(issue.detail ?? "Unknown")")
        print("   Related Components: \(issue.providers.joined(separator: ", "))")

        // Solution suggestions
        if issue.providers.count > 1 {
            print("   💡 Solution: Remove all but one duplicate provider")
        }
    }
}
```

## Real-world Usage Examples

### 🏗️ CI/CD Pipeline Integration

```swift
// build-phase-script.swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()

if !diagnostics.issues.isEmpty {
    print("❌ DI Configuration issues found!")
    for issue in diagnostics.issues {
        print("   - \(issue.type): \(issue.detail ?? "")")
    }
    exit(1)  // Build failure
}

print("✅ DI Configuration validation complete!")
```

### 🧪 Test Environment Validation

```swift
class DIConfigurationTests: XCTestCase {
    func testNoDuplicateProviders() {
        let diagnostics = UnifiedDI.analyzeComponentMetadata()
        let duplicateIssues = diagnostics.issues.filter {
            $0.detail?.contains("Multiple components") == true
        }

        XCTAssertTrue(duplicateIssues.isEmpty,
                     "Duplicate providers found: \(duplicateIssues)")
    }

    func testConsistentScopes() {
        let diagnostics = UnifiedDI.analyzeComponentMetadata()
        let scopeIssues = diagnostics.issues.filter {
            $0.detail?.contains("Inconsistent scopes") == true
        }

        XCTAssertTrue(scopeIssues.isEmpty,
                     "Scope inconsistencies found: \(scopeIssues)")
    }
}
```

### 🔧 Real-time Diagnostics During Development

```swift
#if DEBUG
// AppDelegate or main.swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
if !diagnostics.issues.isEmpty {
    print("🔍 DI Configuration check:")
    for issue in diagnostics.issues {
        print("   ⚠️ \(issue.type): \(issue.detail ?? "")")
    }
}
#endif
```

## Advanced Usage

### 📊 Export Diagnostics to JSON

```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
let jsonData = try JSONEncoder().encode(diagnostics)
try jsonData.write(to: URL(fileURLWithPath: "di-diagnostics.json"))

// Creates JSON file analyzable by external tools
```

### 🎯 Check Specific Types Only

```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
let userServiceIssues = diagnostics.issues.filter { $0.type == "UserService" }

if !userServiceIssues.isEmpty {
    print("UserService configuration has issues:")
    for issue in userServiceIssues {
        print("  - \(issue.detail ?? "")")
    }
}
```

## Performance Characteristics

- **✅ Compile-time Execution**: 0% runtime overhead
- **✅ Memory Efficient**: Minimal memory usage with metadata only
- **✅ Instant Execution**: Immediate diagnosis at app startup
- **✅ Scalable**: Automatically includes new Components

## Troubleshooting Guide

### Q: Can diagnostics produce false positives?
**A:** WeaveDI uses precise compile-time metadata, so false positives are extremely rare. For intentional duplicates, use conditional registration.

### Q: Does it work fast with large projects?
**A:** Yes! It analyzes only compile-time collected metadata, so it executes instantly regardless of Component count.

### Q: Is it helpful when migrating from Needle/Swinject projects?
**A:** Very useful! It automatically finds duplicate configurations or scope inconsistencies you might miss during migration.

## Related APIs

- [`UnifiedDI.componentMetadata()`](./unifiedDI.md#componentmetadata) - Metadata query
- [`UnifiedDI.detectComponentCycles()`](./componentCycleDetection.md) - Circular dependency check
- [`UnifiedDI.performBatchRegistration()`](./batchRegistration.md) - Batch registration

---

*This feature was added in WeaveDI v3.2.1. It's an exclusive innovative feature unique to WeaveDI, not available in Needle or Swinject.*