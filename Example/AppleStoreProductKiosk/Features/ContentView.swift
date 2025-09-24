//
//  ContentView.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import SwiftUI
import ComposableArchitecture

struct ContentView: View {
  @Perception.Bindable var store: StoreOf<ProductListFeature>
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
          store.send(.view(.onAppear))
        }
    }
}

//#Preview {
//    ContentView()
//}
