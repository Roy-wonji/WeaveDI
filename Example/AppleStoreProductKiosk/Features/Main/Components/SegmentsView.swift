//
//  SegmentsView.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import SwiftUI

public struct SegmentData: Identifiable {
  public let id: String
  public let title: String
  public let icon: String?
}

public struct SegmentsView: View {
  private let items: [SegmentData]
  @Binding private var selectedID: String

  public init(
    items: [SegmentData],
    selectedID: Binding<String>
  ) {
    self.items = items
    self._selectedID = selectedID
  }

  public var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 6) {
        ForEach(items) { item in
          Button(action: {
            withAnimation(.interactiveSpring) {
              selectedID = item.id
            }
          }) {
            Text(item.title)
              .font(.system(size: 12))
              .lineLimit(1)
              .padding(.horizontal, 12)
              .padding(.vertical, 12)
              .background(
                selectedID == item.id ? Color.blue : Color.white
              )
              .foregroundColor(
                selectedID == item.id ? .white : .primary
              )
              .overlay(
                Capsule()
                  .stroke(
                    selectedID == item.id
                      ? Color.blue : Color.gray.opacity(0.5),
                    lineWidth: 1
                  )
              )
              .clipShape(Capsule())
          }
        }
      }
      .padding(.horizontal, 8)
    }
    .scrollIndicators(.hidden)
  }
}

private struct PreviewSegment: View {
  @State var selectedSegment = "iPhone"

  var body: some View {
    SegmentsView(
      items: [
        SegmentData(id: "iPhone", title: "iPhone", icon: "iphone"),
        SegmentData(id: "iPad", title: "iPad", icon: "ipad"),
        SegmentData(id: "Mac", title: "Mac", icon: "macbook"),
        SegmentData(
          id: "Apple Watch",
          title: "Apple Watch",
          icon: "applewatch"
        ),
      ],
      selectedID: $selectedSegment
    )
  }
}

#Preview {
  PreviewSegment()
}
