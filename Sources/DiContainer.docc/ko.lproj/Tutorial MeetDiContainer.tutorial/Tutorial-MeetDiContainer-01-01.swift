import SwiftUI

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("DiContainer 카운터")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)

            HStack(spacing: 20) {
                Button("-") {
                    count -= 1
                }
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Circle())

                Button("+") {
                    count += 1
                }
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Circle())
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}