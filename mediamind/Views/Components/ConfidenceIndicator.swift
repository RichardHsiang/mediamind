import SwiftUI

struct ConfidenceIndicator: View {
    let confidence: Double
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(level.color)
            .frame(width: size, height: size)
            .overlay(
                Text("\(Int(confidence * 100))%")
                    .font(.system(size: size * 0.6, weight: .medium))
                    .foregroundColor(.white)
            )
            .help("置信度: \(level.displayName) (\(Int(confidence * 100))%)")
    }

    private var level: ConfidenceLevel {
        if confidence >= 0.9 { return .high }
        else if confidence >= 0.7 { return .medium }
        else { return .low }
    }
}

struct ConfidenceLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("置信度图例:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            ConfidenceItem(color: .green, label: "高 (≥90%)")
            ConfidenceItem(color: .orange, label: "中 (70-89%)")
            ConfidenceItem(color: .red, label: "低 (<70%)")
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct ConfidenceItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct TranscriptionSegmentRow: View {
    let segment: TranscriptionSegment
    var showConfidence: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showConfidence {
                ConfidenceIndicator(confidence: segment.confidence)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("[\(segment.startTime) - \(segment.endTime)]")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .monospacedDigit()

                    if !segment.speaker.isEmpty {
                        Text(segment.speaker)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if segment.isLowConfidence && showConfidence {
                        Text("⚠️ 低置信度")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                }

                Text(segment.text)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(segment.isLowConfidence && showConfidence ? Color.red.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }
}
