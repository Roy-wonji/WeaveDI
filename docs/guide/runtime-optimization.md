# Runtime Hot-Path Optimization

Learn about the high-performance runtime optimization system introduced in WeaveDI v3.2.0.

## Overview

Runtime hot-path optimization is an advanced optimization system designed to eliminate performance bottlenecks in dependency injection.

### Core Optimization Techniques

1. **TypeID + Index Access**
   - `ObjectIdentifier` → `Int` slot mapping
   - O(1) array index access instead of dictionary lookup
   - Memory access pattern optimization

2. **Snapshot/Lock-Free Reads**
   - Immutable Storage class-based snapshot approach
   - Complete elimination of read contention
   - Locking only during writes

3. **Inline Optimization**
   - Applied `@inlinable` + `@inline(__always)`
   - Cross-module optimization with `@_alwaysEmitIntoClient`
   - Reduced function call overhead

4. **Factory Chain Elimination**
   - Direct call paths without intermediate factory steps
   - Dependency chain flattening
   - Removal of multi-stage factory costs

5. **Scope-Specific Static Storage**
   - Separation of singleton/session/request scopes
   - Atomic once initialization
   - Race condition elimination

## Usage

### Enable Optimization

```swift
import WeaveDI

// Enable optimization mode
await UnifiedRegistry.shared.enableOptimization()

// Existing code gets performance improvements without changes
let service = await UnifiedDI.resolve(UserService.self)
```

### Check Optimization

```swift
// Check optimization status
let isOptimized = await UnifiedRegistry.shared.isOptimizationEnabled
print("Optimization enabled: \(isOptimized)")

// Disable optimization
await UnifiedRegistry.shared.disableOptimization()
```

## Performance Improvements

| Scenario | Improvement | Description |
|----------|-------------|-------------|
| Single-threaded resolve | 50-80% faster | TypeID + direct access |
| Multi-threaded reads | 2-3x throughput | Lock-free snapshots |
| Complex dependencies | 20-40% faster | Chain flattening |

## Benchmarks

Run the included benchmarks to measure performance improvements:

```bash
swift run -c release Benchmarks --count 100k --quick
```

## Compatibility

- **100% API compatibility**: No changes to existing code
- **Opt-in optimization**: Enable/disable anytime
- **Gradual migration**: Phased adoption support
- **Zero breaking changes**: Complete preservation of existing behavior

## Internal Implementation

Optimizations are implemented in the following files:

- `OptimizedTypeRegistry.swift` - TypeID system
- `AtomicStorage.swift` - Lock-free storage
- `DirectCallRegistry.swift` - Direct call paths
- `OptimizedScopeStorage.swift` - Scope optimization

## See Also

- [Performance Optimization Guide](/guide/runtime-optimization)
- [Benchmarks Documentation](/guide/benchmarks)
- [UnifiedDI API](/guide/unified-di)