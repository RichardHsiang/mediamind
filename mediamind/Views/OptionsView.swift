import SwiftUI

struct OptionsView: View {
    @Binding var selectedOption: OutputType?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择输出类型")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Text("每次只能选择一个")
                    .font(.system(size: 12))
                    .foregroundColor(.appleGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
            }

            HStack(spacing: 16) {
                ForEach(OutputType.allCases) { option in
                    OptionCard(
                        option: option,
                        isSelected: selectedOption == option
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedOption = option
                        }
                    }
                }
            }
        }
    }
}

struct OptionCard: View {
    let option: OutputType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(option.color.gradient)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: option.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )

                    Spacer()

                    if isSelected {
                        Circle()
                            .fill(Color.appleBlue)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(option.displayName)
                    .font(.system(size: 17, weight: .semibold))

                Text(option.description)
                    .font(.system(size: 13))
                    .foregroundColor(.appleGray)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ForEach(option.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(option.color.opacity(0.1))
                            .foregroundColor(option.color)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.appleBlue : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: action)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
