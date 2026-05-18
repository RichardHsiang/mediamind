import SwiftUI

struct StepIndicator: View {
    let title: String
    let status: StepStatus
    let progress: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.backgroundColor)
                    .frame(width: 32, height: 32)

                Image(systemName: status.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))

                    Spacer()

                    Text(status.description)
                        .font(.system(size: 13))
                        .foregroundColor(status.textColor)
                }

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(status.progressColor)
                                .frame(width: geo.size.width * progress)
                            , alignment: .leading
                        )
                }
                .frame(height: 4)
            }
        }
    }
}

extension StepStatus {
    var progressColor: Color {
        switch self {
        case .completed: return .green
        case .inProgress: return .blue
        case .pending: return Color.gray.opacity(0.2)
        }
    }
}
