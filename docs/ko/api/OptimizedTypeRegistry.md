---
title: OptimizedTypeRegistry
lang: ko-KR
---

# OptimizedTypeRegistry

타입에 대한 고유 정수 식별자

```swift
public struct TypeID: Hashable, Sendable {
  internal let id: Int
}
```

TypeID 매핑 관리자 - ObjectIdentifier → Int 슬롯 할당
  /// ObjectIdentifier를 TypeID로 매핑하거나 새로 할당
  /// 타입으로부터 TypeID 획득
불변 스토리지 스냅샷
  /// 빈 스토리지 생성
런타임 핫패스 최적화된 타입 레지스트리
핵심 최적화:
- TypeID + 인덱스 접근: 딕셔너리 → 배열 슬롯으로 O(1) 접근
- 락-프리 읽기: 불변 Storage 스냅샷으로 읽기 경합 제거
- 직접 호출 경로: 팩토리 체이닝 없는 인라인 호출
  /// 인스턴스 직접 등록 (싱글톤)
  /// 팩토리 등록 (트랜지언트)
  /// 락-프리 해결 (핫패스 최적화)
  /// 해제
  /// 배열 용량 확보
Once 초기화 지원을 위한 원자적 플래그
스코프별 최적화된 저장소
  /// 스코프에 따른 등록
  /// 스코프에 따른 해결
  /// 스코프 클리어 (request/session)
