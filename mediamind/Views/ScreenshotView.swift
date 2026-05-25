import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct ScreenshotView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedVideoURL: URL?
    @State private var videoDuration: Double = 0
    @State private var screenshotTime: String = "00:00:00"
    @State private var segmentStartTime: String = "00:00:00"
    @State private var segmentEndTime: String = "00:00:00"
    @State private var outputDirectory: URL?
    @State private var screenshots: [URL] = []
    @State private var segments: [URL] = []
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum ScreenshotMode {
        case single
        case segment
        case smart
    }
    
    @State private var selectedMode: ScreenshotMode = .single
    
    // 智能搜索相关状态
    @State private var searchQuery: String = ""
    @State private var transcriptionResult: TranscriptionResult?
    @State private var matchedSegments: [(timeRange: ClosedRange<Double>, text: String)] = []
    @State private var selectedMatchIndex: Int? = nil
    @State private var isTranscribing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                
                uploadSection
                
                if selectedVideoURL != nil {
                    modeSelectionSection
                    
                    if selectedMode == .smart {
                        smartSearchSection
                    } else {
                        timeInputSection
                        
                        if selectedMode == .single {
                            singleScreenshotSection
                        } else {
                            segmentExtractionSection
                        }
                    }
                    
                    outputDirectorySection
                    
                    actionButtons
                }
                
                if !screenshots.isEmpty {
                    resultsSection
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("视频截图与片段截取")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appleBlue, .applePurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("上传视频文件，按指定时间点截图或截取视频片段")
                .font(.system(size: 16))
                .foregroundColor(.appleGray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var uploadSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("选择视频文件")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                if selectedVideoURL != nil {
                    Button(action: clearVideoFile) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("清除")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Button(action: selectVideoFile) {
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.appleBlue)
                    
                    if let url = selectedVideoURL {
                        VStack(spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(2)
                            
                            Text("时长: \(formatDuration(videoDuration))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("点击选择视频文件")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var timeInputSection: some View {
        VStack(spacing: 16) {
            Text("时间设置")
                .font(.system(size: 18, weight: .semibold))
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("截图时间点")
                        .font(.system(size: 14, weight: .medium))
                    
                    TextField("HH:MM:SS", text: $screenshotTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("片段开始时间")
                        .font(.system(size: 14, weight: .medium))
                    
                    TextField("HH:MM:SS", text: $segmentStartTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("片段结束时间")
                        .font(.system(size: 14, weight: .medium))
                    
                    TextField("HH:MM:SS", text: $segmentEndTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                }
            }
            
            Text("提示：时间格式为 HH:MM:SS，例如 01:23:45 表示1分23秒45")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var modeSelectionSection: some View {
        VStack(spacing: 16) {
            Text("操作模式")
                .font(.system(size: 18, weight: .semibold))
            
            HStack(spacing: 12) {
                Button(action: { selectedMode = .single }) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(selectedMode == .single ? .white : .appleBlue)
                        
                        Text("单帧截图")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedMode == .single ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedMode == .single ? Color.appleBlue : Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { selectedMode = .segment }) {
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 28))
                            .foregroundColor(selectedMode == .segment ? .white : .applePurple)
                        
                        Text("片段截取")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedMode == .segment ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedMode == .segment ? Color.applePurple : Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { selectedMode = .smart }) {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 28))
                            .foregroundColor(selectedMode == .smart ? .white : .appleGreen)
                        
                        Text("智能搜索")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedMode == .smart ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedMode == .smart ? Color.appleGreen : Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var singleScreenshotSection: some View {
        VStack(spacing: 16) {
            Text("单帧截图设置")
                .font(.system(size: 16, weight: .semibold))
            
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.appleBlue)
                        Text("将在时间点 \(screenshotTime) 截取一帧画面")
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("输出格式：PNG")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("保持原始分辨率")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var segmentExtractionSection: some View {
        VStack(spacing: 16) {
            Text("片段截取设置")
                .font(.system(size: 16, weight: .semibold))
            
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.applePurple)
                        Text("将截取从 \(segmentStartTime) 到 \(segmentEndTime) 的视频片段")
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("输出格式：MP4")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("保持原始画质")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("保留原始音频")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var outputDirectorySection: some View {
        VStack(spacing: 16) {
            Text("输出目录")
                .font(.system(size: 18, weight: .semibold))
            
            Button(action: selectOutputDirectory) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let url = outputDirectory {
                            Text(url.path)
                                .font(.system(size: 14))
                                .lineLimit(2)
                        } else {
                            Text("选择输出目录")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "folder")
                        .foregroundColor(.appleBlue)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            if selectedMode == .smart {
                Button(action: {
                    Task {
                        await performSmartSearch()
                    }
                }) {
                    HStack {
                        if isTranscribing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Text(isTranscribing ? "搜索中..." : "搜索内容")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.appleGreen, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTranscribing || searchQuery.isEmpty)
                
                Button(action: {
                    Task {
                        await extractSelectedMatch()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "film")
                        }
                        
                        Text(isProcessing ? processingMessage : "截取选中片段")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.appleBlue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing || selectedMatchIndex == nil || outputDirectory == nil)
            } else {
                Button(action: executeScreenshot) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: selectedMode == .single ? "photo" : "film")
                        }
                        
                        Text(isProcessing ? processingMessage : (selectedMode == .single ? "截取画面" : "截取片段"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: selectedMode == .single ? [.appleBlue, .cyan] : [.applePurple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing || outputDirectory == nil)
            }
            
            Button(action: clearAll) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("处理结果")
                .font(.system(size: 18, weight: .semibold))
            
            if selectedMode == .single {
                ForEach(screenshots, id: \.self) { url in
                    HStack(spacing: 12) {
                        if let image = NSImage(contentsOf: url) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 80)
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 14, weight: .medium))
                            
                            Text(url.path)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }) {
                            Image(systemName: "folder")
                                .foregroundColor(.appleBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            NSWorkspace.shared.open(url)
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.appleBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            } else {
                ForEach(segments, id: \.self) { url in
                    HStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundColor(.applePurple)
                            .frame(width: 60, height: 60)
                            .background(Color.applePurple.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 14, weight: .medium))
                            
                            Text(url.path)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }) {
                            Image(systemName: "folder")
                                .foregroundColor(.appleBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            NSWorkspace.shared.open(url)
                        }) {
                            Image(systemName: "play.rectangle")
                                .foregroundColor(.appleBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func selectVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedVideoURL = url
            Task {
                await loadVideoInfo(url)
            }
        }
    }
    
    private func clearVideoFile() {
        selectedVideoURL = nil
        videoDuration = 0
        screenshotTime = "00:00:00"
        segmentStartTime = "00:00:00"
        segmentEndTime = "00:00:00"
        screenshots.removeAll()
        segments.removeAll()
        transcriptionResult = nil
        matchedSegments.removeAll()
        selectedMatchIndex = nil
        searchQuery = ""
        selectedMode = .single
    }
    
    private func loadVideoInfo(_ url: URL) async {
        do {
            let info = try await FFmpegService.shared.getVideoInfo(url)
            videoDuration = info.duration
        } catch {
            errorMessage = "无法读取视频信息: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择输出目录"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }
    
    private func executeScreenshot() {
        guard let videoURL = selectedVideoURL,
              let outputDir = outputDirectory else { return }
        
        isProcessing = true
        
        Task {
            do {
                if selectedMode == .single {
                    processingMessage = "截取画面中..."
                    let time = parseTime(screenshotTime)
                    let screenshotURL = try await FFmpegService.shared.extractFrame(
                        at: time,
                        from: videoURL,
                        outputDir: outputDir
                    )
                    await MainActor.run {
                        screenshots.append(screenshotURL)
                        isProcessing = false
                    }
                } else {
                    processingMessage = "截取片段中..."
                    let startTime = parseTime(segmentStartTime)
                    let endTime = parseTime(segmentEndTime)
                    let segmentURL = try await FFmpegService.shared.extractSegment(
                        from: videoURL,
                        startTime: startTime,
                        endTime: endTime,
                        outputDir: outputDir
                    )
                    await MainActor.run {
                        segments.append(segmentURL)
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "处理失败: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func clearAll() {
        selectedVideoURL = nil
        videoDuration = 0
        screenshotTime = "00:00:00"
        segmentStartTime = "00:00:00"
        segmentEndTime = "00:00:00"
        outputDirectory = nil
        screenshots.removeAll()
        segments.removeAll()
    }
    
    private func parseTime(_ timeString: String) -> Double {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 3 else { return 0 }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    // MARK: - 智能搜索功能
    
    private var smartSearchSection: some View {
        VStack(spacing: 16) {
            Text("智能内容搜索")
                .font(.system(size: 16, weight: .semibold))
            
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.appleGreen)
                        Text("输入关键词，自动搜索视频中相关内容并截取")
                            .font(.system(size: 14))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("搜索关键词")
                            .font(.system(size: 13, weight: .medium))
                        
                        TextField("输入要搜索的内容...", text: $searchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if isTranscribing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在转录视频内容...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if !matchedSegments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("找到 \(matchedSegments.count) 个匹配片段")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.appleGreen)
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(Array(matchedSegments.enumerated()), id: \.offset) { index, match in
                                        Button(action: {
                                            selectedMatchIndex = index
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(formatDuration(match.timeRange.lowerBound))
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.appleBlue)
                                                    Text("-")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                    Text(formatDuration(match.timeRange.upperBound))
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.appleBlue)
                                                }
                                                
                                                Text(match.text)
                                                    .font(.system(size: 12))
                                                    .lineLimit(2)
                                                    .foregroundColor(selectedMatchIndex == index ? .primary : .secondary)
                                            }
                                            .padding(8)
                                            .background(selectedMatchIndex == index ? Color.appleBlue.opacity(0.1) : Color.gray.opacity(0.05))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                }
            }
        }
    }
    
    private func performSmartSearch() async {
        guard let videoURL = selectedVideoURL, !searchQuery.isEmpty else { return }
        
        isTranscribing = true
        matchedSegments = []
        
        do {
            // 如果还没有转录结果，先进行转录
            if transcriptionResult == nil {
                let whisperService = WhisperService.shared
                
                // 创建临时输出目录
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("mediamind")
                    .appendingPathComponent("smart_search_\(UUID().uuidString)")
                
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                // 获取AppSettings
                let settings = try modelContext.fetch(FetchDescriptor<AppSettings>()).first ?? AppSettings()
                
                // 使用默认的base模型进行转录
                transcriptionResult = try await whisperService.transcribe(
                    audioURL: videoURL,
                    model: "base",
                    outputDir: tempDir,
                    settings: settings
                )
            }
            
            // 搜索匹配的片段
            if let result = transcriptionResult {
                matchedSegments = searchInTranscription(result, query: searchQuery)
            }
            
            isTranscribing = false
        } catch {
            await MainActor.run {
                errorMessage = "智能搜索失败: \(error.localizedDescription)"
                showError = true
                isTranscribing = false
            }
        }
    }
    
    private func searchInTranscription(_ result: TranscriptionResult, query: String) -> [(timeRange: ClosedRange<Double>, text: String)] {
        var matches: [(timeRange: ClosedRange<Double>, text: String)] = []
        let lowerQuery = query.lowercased()
        
        for segment in result.segments {
            if segment.text.lowercased().contains(lowerQuery) {
                // 解析时间字符串为秒数
                let startTime = parseTimeString(segment.startTime)
                let endTime = parseTimeString(segment.endTime)
                
                // 扩展时间范围，前后各加2秒
                let extendedStartTime = max(0, startTime - 2)
                let extendedEndTime = min(videoDuration, endTime + 2)
                matches.append((extendedStartTime...extendedEndTime, segment.text))
            }
        }
        
        return matches
    }
    
    private func parseTimeString(_ timeString: String) -> Double {
        let components = timeString.split(separator: ":").map { Double($0) ?? 0 }
        if components.count >= 3 {
            return components[0] * 3600 + components[1] * 60 + components[2]
        } else if components.count == 2 {
            return components[0] * 60 + components[1]
        } else {
            return components[0]
        }
    }
    
    private func extractSelectedMatch() async {
        guard let index = selectedMatchIndex,
              index < matchedSegments.count,
              let outputDir = outputDirectory else { return }
        
        let match = matchedSegments[index]
        isProcessing = true
        processingMessage = "正在截取匹配片段..."
        
        do {
            let segmentURL = try await FFmpegService.shared.extractSegment(
                from: selectedVideoURL!,
                startTime: match.timeRange.lowerBound,
                endTime: match.timeRange.upperBound,
                outputDir: outputDir
            )
            
            await MainActor.run {
                segments.append(segmentURL)
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "截取失败: \(error.localizedDescription)"
                showError = true
                isProcessing = false
            }
        }
    }
}