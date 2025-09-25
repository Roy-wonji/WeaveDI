import DiContainer

protocol GreetingService { func hello() -> String }
struct Greeting: GreetingService { func hello() -> String { "Hello" } }

// 등록
_ = UnifiedDI.register(GreetingService.self) { Greeting() }

// 사용
let svc = UnifiedDI.resolve(GreetingService.self)
print(svc?.hello() ?? "-")

