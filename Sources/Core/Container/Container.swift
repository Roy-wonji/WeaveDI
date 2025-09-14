//
//  Container.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

// MARK: - Legacy Container (Deprecated)

/// ⚠️ **DEPRECATED**: This file contains the legacy monolithic Container implementation.
///
/// **New Structure**:
/// - `ContainerCore.swift` - Core Container actor implementation
/// - `ContainerBuildEngine.swift` - Build and performance optimized methods
/// - `ContainerDocumentation.swift` - Usage examples and documentation
///
/// **Migration Guide**:
/// No code changes required. All APIs remain the same.
/// The Container class is now split across multiple files for better maintainability.
///
/// **Deprecated Date**: 2025-09-14
/// **Removal Date**: To be determined
/// **Reason**: Code organization and maintainability improvement
@available(*, deprecated, message: "This monolithic file has been split into ContainerCore, ContainerBuildEngine, and ContainerDocumentation for better organization. Functionality remains unchanged.")
private enum LegacyContainerImplementation {
    // This enum serves as a marker that the implementation has been moved to separate files
}
