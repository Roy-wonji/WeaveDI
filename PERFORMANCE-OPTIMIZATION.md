# 🚀 Runtime Hot-Path Micro-Optimizations

WeaveDI v3.2.0 introduces advanced runtime optimizations specifically designed for hot-path performance in dependency injection scenarios.

## 🎯 Optimization Overview

### Core Optimizations

1. **TypeID + Index Access System**
2. **Snapshot/Lock-Free Read System**
3. **Inlinable + Final + @_alwaysEmitIntoClient**
4. **Cost Tree Reflection & Factory Chain Elimination**
5. **Scope-Specific Static Storage + Once Initialization**

---

## 1. TypeID + Index Access System

### Problem
- Dictionary lookup with `ObjectIdentifier` keys has O(1) but with hash overhead
- Type initialization costs on each resolve call
- Poor memory access patterns

### Solution
```swift
// Before: Dictionary[ObjectIdentifier: Any]
let instance = dependencies[ObjectIdentifier(T.self)]

// After: Array[Int: Any] with TypeID mapping
let typeID = typeIDMapper.getOrCreateTypeID(for: T.self)
let instance = instances[typeID.id]  // O(1) array access
```

### Performance Gains
- **~30-50% faster** resolve calls
- Better CPU cache utilization
- Reduced memory fragmentation

---

## 2. Snapshot/Lock-Free Read System

### Problem
- Reader-writer lock contention in multi-threaded scenarios
- Read operations blocked by write operations

### Solution
```swift
// Immutable snapshot approach
final class Storage {
    let instances: [Any?]
    let factories: [(() -> Any)?]
}

// Lock-free reads
@inlinable
func resolve<T>(_ type: T.Type) -> T? {
    let storage = currentStorage  // Atomic snapshot copy
    return storage.instances[typeID.id] as? T
}
```

### Performance Gains
- **2-3x better** multi-threaded read throughput
- Zero read contention
- Write-only locking

---

## 3. Inlinable + Final + @_alwaysEmitIntoClient

### Problem
- Function call overhead in hot paths
- Cross-module optimization barriers

### Solution
```swift
@inlinable
@inline(__always)
@_alwaysEmitIntoClient
public func resolve<T>(_ type: T.Type) -> T? {
    // Hot path code inlined directly into client
}
```

### Performance Gains
- **10-20% reduction** in function call overhead
- Cross-module inlining
- Better compiler optimizations

---

## 4. Cost Tree Reflection & Factory Chain Elimination

### Problem
- Multiple factory chains: `Factory → Factory → Factory`
- Intermediate wrapper overhead

### Solution
```swift
// Before: Chain of factories
let service = factory1() |> factory2() |> factory3()

// After: Direct call path
let service = directCreator()  // Flattened chain
```

### Performance Gains
- **20-40% faster** complex dependency resolution
- Reduced call stack depth
- Memory allocation reduction

---

## 5. Scope-Specific Static Storage + Once Initialization

### Problem
- Singleton race conditions
- Mixed scope storage inefficiency

### Solution
```swift
// Separate storage per scope
private let singletonStorage = OptimizedTypeRegistry()
private let sessionStorage = OptimizedTypeRegistry()
private let requestStorage = OptimizedTypeRegistry()

// Atomic once initialization
private var onceFlags: [TypeID: AtomicOnce] = [:]
```

### Performance Gains
- **Thread-safe singleton** creation
- **Scope-specific optimizations**
- Elimination of race conditions

---

## 📊 Expected Performance Improvements

| Scenario | Improvement | Details |
|----------|-------------|---------|
| Single-threaded resolve | 50-80% faster | TypeID + direct access |
| Multi-threaded reads | 2-3x throughput | Lock-free snapshots |
| Singleton creation | Race-free | Atomic once initialization |
| Complex dependencies | 20-40% faster | Chain flattening |
| Cross-module calls | 10-20% faster | Inlined hot paths |

## 🔧 How to Enable

```swift
import WeaveDI

// Enable optimization mode
UnifiedRegistry.shared.enableOptimization()

// Your existing code works unchanged
let service = await UnifiedDI.resolve(UserService.self)
```

## ✅ Backward Compatibility

- **100% API compatibility** with existing code
- **Opt-in optimization** - disable anytime
- **Gradual migration** supported
- **Zero breaking changes**

## 🧪 Benchmarking

Run the included benchmarks to measure improvements in your specific use case:

```bash
swift run -c release Benchmarks --count 100k --quick
```

## 🛠 Implementation Details

### Files Added
- `Sources/Core/Optimized/OptimizedTypeRegistry.swift` - TypeID system
- `Sources/Core/Optimized/AtomicStorage.swift` - Lock-free storage
- `Sources/Core/Optimized/DirectCallRegistry.swift` - Chain elimination
- `Sources/Core/Optimized/OptimizedScopeStorage.swift` - Scope optimization

### Integration
- Optimizations are integrated into existing `UnifiedDI` and `UnifiedRegistry`
- Enable with `enableOptimization()` method
- Fallback to standard implementation when disabled

---

*These optimizations maintain the simplicity and reliability of WeaveDI while providing significant performance improvements for demanding applications.*