---
title: PropertyWrappers
lang: ko-KR
---

# PropertyWrappers

## 🏭 @Factory - 팩토리 패턴 주입
매번 새로운 인스턴스를 생성하는 팩토리 패턴 Property Wrapper입니다.
상태를 공유하지 않는 독립적인 객체가 필요할 때 사용합니다.
### 사용법:
```swift
class ReportService {
    @Factory var pdfGenerator: PDFGenerator          // 매번 새 인스턴스
    @Factory(\.emailSender) var email: EmailSender   // KeyPath로 팩토리
}
```

```swift
public struct Factory<T> {
}
```

  /// KeyPath를 사용한 팩토리 초기화
  /// - Parameter keyPath: 팩토리가 등록된 KeyPath
  /// 직접 팩토리 함수를 제공하는 초기화
  /// - Parameter factory: 인스턴스를 생성하는 클로저
  /// 매번 새로운 인스턴스를 반환합니다
