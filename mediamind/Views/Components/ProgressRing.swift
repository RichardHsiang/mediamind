import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat

    init(progress: Double, size: CGFloat = 80) {
        self.progress = progress
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.appleBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            Text("\(Int(progress * 100))%")
                .font(.system(size: 17, weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}
