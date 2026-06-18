import SwiftUI

struct ResultsView: View {
    @ObservedObject var viewModel: TaskViewModel
    @State private var showTranscriptionPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("处理结果")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button(showTranscriptionPreview ? "隐藏转录" : "查看转录") {
                    withAnimation {
                        showTranscriptionPreview.toggle()
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.appleBlue)

                Button("下载全部") {
                    downloadAllFiles()
                }
                .font(.system(size: 14))
                .foregroundColor(.appleBlue)
            }

            // All cards in one row
            allCardsRow

            if showTranscriptionPreview {
                TranscriptionPreviewView(segments: viewModel.transcriptionSegments)
            }
        }
    }

    private var allCardsRow: some View {
        let outputType = viewModel.currentTask?.outputType ?? OutputType.analysis.rawValue

        // Debug: print all output files
        print("[ResultsView] outputFiles count: \(viewModel.outputFiles.count)")
        for file in viewModel.outputFiles {
            print("[ResultsView] outputFile: \(file.path), exists: \(FileManager.default.fileExists(atPath: file.path))")
        }

        // Filter existing files only
        let existingFiles = viewModel.outputFiles.filter { FileManager.default.fileExists(atPath: $0.path) }

        return HStack(spacing: 16) {
            if outputType == OutputType.subtitle.rawValue {
                // Subtitle output - show subtitle files + audio.md + metadata.json
                if let subtitleFile = existingFiles.first(where: {
                    ["srt", "vtt", "ass"].contains($0.pathExtension.lowercased())
                }) {
                    ResultCard(
                        title: subtitleFile.lastPathComponent,
                        description: "字幕文件",
                        tag: "字幕",
                        tagColor: .orange,
                        iconColor: .orange,
                        fileURL: subtitleFile,
                        onDownload: { url in
                            downloadFile(url)
                        }
                    )
                }

                ResultCard(
                    title: "audio.md",
                    description: "完整转录文本与时间戳",
                    tag: "原始",
                    tagColor: .gray,
                    iconColor: .purple,
                    fileURL: existingFiles.first { $0.lastPathComponent == "audio.md" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )

                ResultCard(
                    title: "metadata.json",
                    description: "处理日志与元数据信息",
                    tag: "元数据",
                    tagColor: .gray,
                    iconColor: .orange,
                    fileURL: existingFiles.first { $0.lastPathComponent == "metadata.json" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )
            } else if outputType == OutputType.analysis.rawValue {
                // Analysis output
                ResultCard(
                    title: "audio_analysis.md",
                    description: "结构化内容分析与摘要",
                    tag: "主输出",
                    tagColor: .green,
                    iconColor: .blue,
                    fileURL: existingFiles.first { $0.lastPathComponent == "audio_analysis.md" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )

                ResultCard(
                    title: "audio.md",
                    description: "完整转录文本与时间戳",
                    tag: "原始",
                    tagColor: .gray,
                    iconColor: .purple,
                    fileURL: existingFiles.first { $0.lastPathComponent == "audio.md" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )

                ResultCard(
                    title: "metadata.json",
                    description: "处理日志与元数据信息",
                    tag: "元数据",
                    tagColor: .gray,
                    iconColor: .orange,
                    fileURL: existingFiles.first { $0.lastPathComponent == "metadata.json" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )
            } else if outputType == OutputType.report.rawValue {
                // Report output
                ResultCard(
                    title: "meeting_report.html",
                    description: "会议纪要与报告",
                    tag: "报告",
                    tagColor: .purple,
                    iconColor: .purple,
                    fileURL: existingFiles.first { $0.lastPathComponent == "meeting_report.html" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )

                ResultCard(
                    title: "audio.md",
                    description: "完整转录文本与时间戳",
                    tag: "原始",
                    tagColor: .gray,
                    iconColor: .purple,
                    fileURL: existingFiles.first { $0.lastPathComponent == "audio.md" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )

                ResultCard(
                    title: "metadata.json",
                    description: "处理日志与元数据信息",
                    tag: "元数据",
                    tagColor: .gray,
                    iconColor: .orange,
                    fileURL: existingFiles.first { $0.lastPathComponent == "metadata.json" },
                    onDownload: { url in
                        downloadFile(url)
                    }
                )
            }
        }
    }

    private func downloadFile(_ url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let destinationURL = panel.url {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("[ResultsView] Downloaded to: \(destinationURL.path)")
            } catch {
                print("[ResultsView] Download failed: \(error)")
            }
        }
    }

    private func downloadAllFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择保存位置"
        panel.message = "选择下载目录"

        if panel.runModal() == .OK, let destinationDir = panel.url {
            for fileURL in viewModel.outputFiles {
                let destinationURL = destinationDir.appendingPathComponent(fileURL.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                } catch {
                    print("[ResultsView] Failed to download \(fileURL.lastPathComponent): \(error)")
                }
            }
            print("[ResultsView] Downloaded all files to: \(destinationDir.path)")
        }
    }
}

struct TranscriptionPreviewView: View {
    let segments: [TranscriptionSegment]
    @State private var filterLowConfidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("转录预览")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Toggle("仅显示低置信度", isOn: $filterLowConfidence)
                    .font(.system(size: 12))
                    .toggleStyle(CheckboxToggleStyle())
            }

            ConfidenceLegend()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        if !filterLowConfidence || segment.isLowConfidence {
                            TranscriptionSegmentRow(segment: segment)
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 400)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

struct ResultCard: View {
    let title: String
    let description: String
    let tag: String
    let tagColor: Color
    let iconColor: Color
    let fileURL: URL?
    let onDownload: (URL) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.gradient)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )

                    Spacer()

                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tagColor.opacity(0.1))
                        .foregroundColor(tagColor)
                        .cornerRadius(8)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.appleGray)

                Button("下载") {
                    if let url = fileURL {
                        onDownload(url)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(fileURL == nil ? Color.gray : Color.appleBlue)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                .disabled(fileURL == nil)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }
}
