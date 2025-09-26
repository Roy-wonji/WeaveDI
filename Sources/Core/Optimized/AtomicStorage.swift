//
//  AtomicStorage.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

// MARK: - Atomic Storage System

/// 원자적 포인터 교체를 지원하는 스토리지 관리자
internal final class AtomicStorageManager<T>: @unchecked Sendable {
    private var storagePointer: UnsafeMutablePointer<T>
    private let lock = NSLock()

    init(initialValue: T) {
        storagePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        storagePointer.initialize(to: initialValue)
    }

    deinit {
        storagePointer.deinitialize(count: 1)
        storagePointer.deallocate()
    }

    /// 락-프리 읽기: 현재 스토리지 스냅샷 복사
    @inlinable
    @inline(__always)
    func load() -> T {
        return storagePointer.pointee
    }

    /// 원자적 스토리지 교체 (쓰기만 락 보호)
    @inlinable
    func store(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        storagePointer.pointee = newValue
    }

    /// Compare-and-swap 연산
    @inlinable
    func compareAndSwap(expected: T, new: T, compare: (T, T) -> Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if compare(storagePointer.pointee, expected) {
            storagePointer.pointee = new
            return true
        }
        return false
    }
}

// MARK: - Enhanced Storage with Copy-on-Write

/// 개선된 Storage 클래스 - 불변성과 COW 지원
internal final class EnhancedStorage {
    private let _instances: [Any?]
    private let _factories: [(() -> Any)?]
    private let _version: Int

    var instances: [Any?] { _instances }
    var factories: [(() -> Any)?] { _factories }
    var version: Int { _version }

    init(instances: [Any?] = [], factories: [(() -> Any)?] = [], version: Int = 0) {
        self._instances = instances
        self._factories = factories
        self._version = version
    }

    /// Copy-on-write 방식으로 새 스토리지 생성
    func copyWithUpdate(at index: Int, instance: Any?, factory: (() -> Any)?) -> EnhancedStorage {
        var newInstances = _instances
        var newFactories = _factories

        // 배열 크기 확장
        while newInstances.count <= index {
            newInstances.append(nil)
            newFactories.append(nil)
        }

        newInstances[index] = instance
        newFactories[index] = factory

        return EnhancedStorage(
            instances: newInstances,
            factories: newFactories,
            version: _version + 1
        )
    }

    /// 특정 인덱스 제거
    func copyWithRemoval(at index: Int) -> EnhancedStorage {
        guard index < _instances.count else { return self }

        var newInstances = _instances
        var newFactories = _factories

        newInstances[index] = nil
        newFactories[index] = nil

        return EnhancedStorage(
            instances: newInstances,
            factories: newFactories,
            version: _version + 1
        )
    }

    static func empty() -> EnhancedStorage {
        return EnhancedStorage()
    }
}

// MARK: - Ultra-Optimized Registry

/// 최고 성능 최적화를 적용한 레지스트리
internal final class UltraOptimizedRegistry: @unchecked Sendable {

    // MARK: - Properties

    private let typeIDMapper = TypeIDMapper()
    private let storageManager: AtomicStorageManager<EnhancedStorage>

    // 성능 통계 (옵션)
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private let statsLock = NSLock()

    // MARK: - Initialization

    init() {
        self.storageManager = AtomicStorageManager(initialValue: EnhancedStorage.empty())
    }

    // MARK: - Hot Path APIs

    /// 초고속 해결 - 핫패스 전용
    @inlinable
    @inline(__always)
    func fastResolve<T>(_ type: T.Type) -> T? {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        let storage = storageManager.load() // 락-프리 스냅샷

        // 인덱스 범위 체크
        guard typeID.id < storage.instances.count else {
            incrementMissCount()
            return nil
        }

        // 1. 인스턴스 캐시 체크 (싱글톤 경로)
        if let instance = storage.instances[typeID.id] as? T {
            incrementHitCount()
            return instance
        }

        // 2. 팩토리 실행 (트랜지언트 경로)
        if let factory = storage.factories[typeID.id] {
            incrementHitCount()
            return factory() as? T
        }

        incrementMissCount()
        return nil
    }

    /// 고성능 인스턴스 등록
    @inlinable
    func fastRegister<T>(_ type: T.Type, instance: T) {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        let currentStorage = storageManager.load()
        let newStorage = currentStorage.copyWithUpdate(
            at: typeID.id,
            instance: instance,
            factory: nil
        )
        storageManager.store(newStorage)
    }

    /// 고성능 팩토리 등록
    @inlinable
    func fastRegister<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        let currentStorage = storageManager.load()
        let newStorage = currentStorage.copyWithUpdate(
            at: typeID.id,
            instance: nil,
            factory: { factory() }
        )
        storageManager.store(newStorage)
    }

    /// 고성능 해제
    @inlinable
    func fastRelease<T>(_ type: T.Type) {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        let currentStorage = storageManager.load()
        let newStorage = currentStorage.copyWithRemoval(at: typeID.id)
        storageManager.store(newStorage)
    }

    // MARK: - Performance Monitoring

    @inlinable
    private func incrementHitCount() {
        statsLock.lock()
        hitCount += 1
        statsLock.unlock()
    }

    @inlinable
    private func incrementMissCount() {
        statsLock.lock()
        missCount += 1
        statsLock.unlock()
    }

    /// 성능 통계 반환
    func getPerformanceStats() -> (hits: Int, misses: Int, hitRatio: Double) {
        statsLock.lock()
        defer { statsLock.unlock() }

        let total = hitCount + missCount
        let ratio = total > 0 ? Double(hitCount) / Double(total) : 0.0
        return (hits: hitCount, misses: missCount, hitRatio: ratio)
    }

    /// 통계 초기화
    func resetStats() {
        statsLock.lock()
        defer { statsLock.unlock() }
        hitCount = 0
        missCount = 0
    }
}

// MARK: - Specialized Factory Types

/// 타입별 특화된 팩토리
internal enum SpecializedFactory {
    case instance(Any) // 직접 인스턴스
    case syncFactory(() -> Any) // 동기 팩토리
    case asyncFactory(() async -> Any) // 비동기 팩토리

    /// 팩토리 실행
    @inlinable
    func execute() -> Any? {
        switch self {
        case .instance(let value):
            return value
        case .syncFactory(let factory):
            return factory()
        case .asyncFactory:
            // 비동기는 별도 경로에서 처리
            return nil
        }
    }
}

/// 특화된 팩토리를 사용하는 레지스트리
internal final class SpecializedFactoryRegistry: @unchecked Sendable {
    private let typeIDMapper = TypeIDMapper()
    private let storageManager: AtomicStorageManager<[SpecializedFactory?]>

    init() {
        self.storageManager = AtomicStorageManager(initialValue: [])
    }

    /// 특화된 해결
    @inlinable
    @inline(__always)
    func resolve<T>(_ type: T.Type) -> T? {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        let factories = storageManager.load()

        guard typeID.id < factories.count,
              let factory = factories[typeID.id] else {
            return nil
        }

        return factory.execute() as? T
    }

    /// 특화된 등록
    @inlinable
    func register<T>(_ type: T.Type, instance: T) {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        var factories = storageManager.load()

        // 배열 확장
        while factories.count <= typeID.id {
            factories.append(nil)
        }

        factories[typeID.id] = .instance(instance)
        storageManager.store(factories)
    }

    /// 특화된 팩토리 등록
    @inlinable
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let typeID = typeIDMapper.getOrCreateTypeID(for: type)
        var factories = storageManager.load()

        while factories.count <= typeID.id {
            factories.append(nil)
        }

        factories[typeID.id] = .syncFactory { factory() }
        storageManager.store(factories)
    }
}