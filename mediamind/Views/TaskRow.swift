import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    var onSave: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor.gradient)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.taskName.isEmpty ? task.fileName : task.taskName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Text("\(task.processingType) · \(timeAgoString(from: task.createdAt))")
                    .font(.system(size: 13))
                    .foregroundColor(.appleGray)
            }

            Spacer()

            // Status
            Text(task.status)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.1))
                .foregroundColor(statusColor)
                .cornerRadius(12)

            // Actions
            HStack(spacing: 8) {
                if let onSave = onSave {
                    Button("保存") {
                        onSave()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .buttonStyle(PlainButtonStyle())
                }

                if let onDelete = onDelete {
                    Button("删除") {
                        onDelete()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.85))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 2)
    }

    private var iconName: String {
        switch task.outputType {
        case OutputType.subtitle.rawValue:
            return "captions.bubble.fill"
        case OutputType.analysis.rawValue:
            return "brain.head.profile"
        case OutputType.report.rawValue:
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch task.outputType {
        case OutputType.subtitle.rawValue:
            return .orange
        case OutputType.analysis.rawValue:
            return .green
        case OutputType.report.rawValue:
            return .purple
        default:
            return .blue
        }
    }

    private var statusColor: Color {
        if let status = TaskStatus(rawValue: task.status) {
            return status.color
        }
        return .gray
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
