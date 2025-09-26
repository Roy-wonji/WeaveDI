import Foundation
import WeaveDI

// MARK: - 1. 서비스 정의

protocol GreetingService: Sendable {
    func greet(name: String) -> String
    func farewell(name: String) -> String
}

final class SimpleGreetingService: GreetingService {
    func greet(name: String) -> String {
        return "안녕하세요, \(name)님!"
    }

    func farewell(name: String) -> String {
        return "안녕히 가세요, \(name)님!"
    }
}

// MARK: - 2. 서비스 등록

// 싱글톤으로 등록 (기본값)
let greetingService = UnifiedDI.register(GreetingService.self) {
    SimpleGreetingService()
}

// MARK: - 3. 기본 사용법

// 직접 해결
let service = UnifiedDI.resolve(GreetingService.self)
let message = service?.greet(name: "개발자") ?? "서비스를 찾을 수 없습니다"

print("📝 기본 사용: \(message)")