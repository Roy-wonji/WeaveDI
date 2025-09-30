---
title: Scopes
lang: en-US
---

# Scopes Guide (Screen / Session / Request)

WeaveDI provides scope functionality to isolate and cache dependencies by context units such as screen/session/request.

## Why Do We Need Scopes?
- State that should only be maintained within one screen (e.g., screen cache)
- Data that should disappear with user session (e.g., user-specific services)
- Objects reused per request (e.g., RequestContext)

## Core Types
- `ScopeKind`: `.screen`, `.session`, `.request`
- `ScopeContext`: Current scope ID management (`setCurrent(_:, id:)`, `clear(_:)`, `currentID(for:)`)
- `registerScoped` / `registerAsyncScoped`: Scope-based registration

## Usage Examples

### Screen Scope
```swift
// On screen entry
ScopeContext.shared.setCurrent(.screen, id: "Home")

await GlobalUnifiedRegistry.registerScoped(HomeViewModel.self, scope: .screen) {
    HomeViewModel()
}

let vm = UnifiedDI.resolve(HomeViewModel.self)

// On screen exit
ScopeContext.shared.clear(.screen)
```

### Session Scope
```swift
// On login success
ScopeContext.shared.setCurrent(.session, id: user.id)
await GlobalUnifiedRegistry.registerScoped(UserSession.self, scope: .session) {
    UserSession(user: user)
}

// Reuse anywhere within session
let session = UnifiedDI.resolve(UserSession.self)

// On logout
ScopeContext.shared.clear(.session)
```

### Request Scope
```swift
ScopeContext.shared.setCurrent(.request, id: UUID().uuidString)
await GlobalUnifiedRegistry.registerAsyncScoped(RequestContext.self, scope: .request) {
    await RequestContext.create()
}
let ctx = await UnifiedDI.resolveAsync(RequestContext.self)
ScopeContext.shared.clear(.request)
```

## Lifecycle Helpers (Recommended Patterns)
- iOS screens: Set `.screen` in `viewWillAppear`, release in `viewDidDisappear`
- Sessions: Set/release `.session` on login/logout events
- Server/backend-like architecture: Set `.request` on request reception, release on completion

> Note: If scope ID is not set, scope registration behaves as one-time creation (no caching).

## Troubleshooting
- "Scope is not applied" → Check if `ScopeContext.shared.currentID(for:)` is nil
- "Memory leak?" → Check if `clear(_:)` was called on screen/session termination
- "Concurrency safety?" → UnifiedRegistry is actor-based and scope cache is safely synchronized internally.

---

📖 **Documentation**: [한국어](../ko.lproj/Scopes) | [English](Scopes)
