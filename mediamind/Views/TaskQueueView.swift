import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TaskQueueView: View {
    @StateObject private var queueManager = TaskQueueManager.shared
    @State private var selectedFiles: [URL] = []
    @State private var selectedOption: OutputType?
    @Query private var settingsList: [AppSettings]
    
    var settings: AppSettings {
        settingsList.first ?? AppSettings()
    }
    
    @State private var showTemplatePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                
                // 配置缺失提示
                if queueManager.showConfigurationAlert {
                    configurationAlertSection
                }
                
                // 模板缺失提示
                if queueManager.showTemplateMissingAlert {
                    templateMissingAlertSection
                }
                
                uploadSection
                
                optionsSection
                
                queueControlSection
                
                if queueManager.currentTask != nil {
                    currentTaskSection
                }
                
                if !queueManager.queue.isEmpty {
                    waitingQueueSection
                }
                
                if !queueManager.completedTasks.isEmpty {
                    completedTasksSection
                }
                
                if !queueManager.failedTasks.isEmpty {
                    failedTasksSection
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            print("[TaskQueueView] ========== 拖拽到主视图 ==========")
            print("[TaskQueueView] 提供商数量: \(providers.count)")
            handleGlobalDrop(providers: providers)
            return true
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet { selectedPath in
                queueManager.resumeWithTemplatePath(selectedPath)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("智能音视频处理")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appleBlue, .applePurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("上传音频或视频文件，自动完成转录、分析与报告生成")
                .font(.system(size: 16))
                .foregroundColor(.appleGray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var uploadSection: some View {
        VStack(spacing: 16) {
            Text("选择文件")
                .font(.system(size: 18, weight: .semibold))
            
            MultiUploadView(selectedFiles: $selectedFiles)
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 16) {
            Text("处理选项")
                .font(.system(size: 18, weight: .semibold))
            
            OptionsView(selectedOption: $selectedOption)
        }
    }
    
    private var queueControlSection: some View {
        VStack(spacing: 16) {
            Text("队列控制")
                .font(.system(size: 18, weight: .semibold))
            
            HStack(spacing: 16) {
                Button(action: addToQueue) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加到队列")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appleBlue)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedFiles.isEmpty || selectedOption == nil)
                
                Button(action: {
                    if queueManager.isProcessing {
                        queueManager.pauseProcessing()
                    } else {
                        queueManager.startProcessing()
                    }
                }) {
                    HStack {
                        Image(systemName: queueManager.isProcessing ? "pause.circle.fill" : "play.circle.fill")
                        Text(queueManager.isProcessing ? "暂停处理" : "开始处理")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(queueManager.isProcessing ? Color.orange : Color.green)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(queueManager.queue.isEmpty && queueManager.currentTask == nil)
                
                Button(action: {
                    queueManager.clearAll()
                    selectedFiles.removeAll()
                }) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text("清空队列")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(queueManager.isProcessing)
            }
            
            HStack(spacing: 12) {
                queueStatusBadge("等待中", count: queueManager.queue.count, color: .orange)
                queueStatusBadge("处理中", count: queueManager.currentTask != nil ? 1 : 0, color: .blue)
                queueStatusBadge("已完成", count: queueManager.completedTasks.count, color: .green)
                queueStatusBadge("失败", count: queueManager.failedTasks.count, color: .red)
            }
        }
    }
    
    private func queueStatusBadge(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(title): \(count)")
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var configurationAlertSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("缺少必要配置")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("处理此任务前需要完成以下配置")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 显示缺失的配置项列表
            VStack(alignment: .leading, spacing: 8) {
                ForEach(queueManager.configurationMissingItems) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.item.rawValue)
                                .font(.system(size: 13, weight: .medium))
                            
                            Text(item.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button(action: {
                    // 打开设置页面
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("前往设置")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.appleBlue)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // 用户配置完成后继续
                    queueManager.resumeAfterConfiguration()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("已完成配置")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // 跳过当前任务
                    queueManager.showConfigurationAlert = false
                    if let task = queueManager.configurationMissingTask {
                        queueManager.configurationMissingTask = nil
                        task.status = .failed
                        task.errorMessage = "配置不完整，用户跳过"
                        queueManager.failedTasks.append(task)
                    }
                    queueManager.configurationMissingItems.removeAll()
                    queueManager.startProcessing()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text("跳过此任务")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var templateMissingAlertSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("需要配置报告模板")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("生成会议报告需要 HTML 模板文件，请选择模板目录")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    showTemplatePicker = true
                }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("选择模板目录")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.appleBlue)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // 跳过当前任务，继续处理队列中的其他任务
                    queueManager.showTemplateMissingAlert = false
                    if let task = queueManager.templateMissingTask {
                        queueManager.templateMissingTask = nil
                        task.status = .failed
                        task.errorMessage = "模板未配置，用户跳过"
                        queueManager.failedTasks.append(task)
                    }
                    queueManager.startProcessing()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text("跳过此任务")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var currentTaskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前任务")
                .font(.system(size: 18, weight: .semibold))
            
            if let currentTask = queueManager.currentTask {
                currentTaskCard(currentTask)
            }
        }
    }
    
    private var waitingQueueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("等待队列 (\(queueManager.queue.count))")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                if !queueManager.isProcessing {
                    Button("清空队列") {
                        queueManager.queue.removeAll()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                }
            }
            
            ForEach(queueManager.queue) { task in
                miniTaskCard(task)
            }
        }
    }
    
    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("已完成任务")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button("清空") {
                    queueManager.clearCompleted()
                }
                .font(.system(size: 13))
                .foregroundColor(.red)
            }
            
            ForEach(queueManager.completedTasks) { task in
                completedTaskCard(task)
            }
        }
    }
    
    private var failedTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("失败任务")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button("清空") {
                    queueManager.clearFailed()
                }
                .font(.system(size: 13))
                .foregroundColor(.red)
            }
            
            ForEach(queueManager.failedTasks) { task in
                failedTaskCard(task)
            }
        }
    }
    
    private func currentTaskCard(_ task: QueuedTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.fileName)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)

                    Text(task.fileSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if task.progress < 1.0 && task.progress > 0 {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    Text("\(Int(task.progress * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appleBlue)
                        .frame(minWidth: 36, alignment: .trailing)
                }

                Button(action: {
                    queueManager.pauseProcessing()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("停止处理")
            }

            // 自定义进度条，带渐变和动画
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)

                    // 进度填充 - 使用渐变
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: progressGradientColors(for: task.progress),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(task.progress)), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: task.progress)

                    // 进度指示点
                    if task.progress > 0 && task.progress < 1.0 {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: max(0, geometry.size.width * CGFloat(task.progress) - 6))
                            .animation(.easeInOut(duration: 0.3), value: task.progress)
                    }
                }
            }
            .frame(height: 12)

            // 步骤指示器
            HStack(spacing: 4) {
                ForEach(ProcessingStep.allCases, id: \.self) { step in
                    let stepStatus = stepStatus(for: step, progress: task.progress)
                    Circle()
                        .fill(stepStatus.color)
                        .frame(width: stepStatus == .current ? 10 : 6, height: stepStatus == .current ? 10 : 6)
                        .overlay(
                            Circle()
                                .stroke(stepStatus.color.opacity(0.3), lineWidth: stepStatus == .current ? 2 : 0)
                                .frame(width: stepStatus == .current ? 14 : 6, height: stepStatus == .current ? 14 : 6)
                        )
                        .animation(.easeInOut(duration: 0.3), value: task.progress)

                    if step != ProcessingStep.allCases.last {
                        Rectangle()
                            .fill(stepStatus == .completed ? Color.green.opacity(0.5) : Color.gray.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 20)

            HStack {
                Text(task.currentDescription.isEmpty ? "准备中..." : task.currentDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                // 显示当前步骤名称
                if let currentStep = currentStepFromProgress(task.progress) {
                    Text(currentStep.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.appleBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.appleBlue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }

    private func progressGradientColors(for progress: Double) -> [Color] {
        switch progress {
        case 0..<0.25:
            return [.orange, .yellow]
        case 0.25..<0.60:
            return [.yellow, .green]
        case 0.60..<0.85:
            return [.green, .appleBlue]
        case 0.85...1.0:
            return [.appleBlue, .purple]
        default:
            return [.gray]
        }
    }

    private enum StepStatus {
        case pending, current, completed

        var color: Color {
            switch self {
            case .pending: return Color.gray.opacity(0.3)
            case .current: return Color.appleBlue
            case .completed: return Color.green
            }
        }
    }

    private func stepStatus(for step: ProcessingStep, progress: Double) -> StepStatus {
        let stepProgress = step.progressRange
        if progress >= stepProgress.upperBound {
            return .completed
        } else if progress >= stepProgress.lowerBound {
            return .current
        } else {
            return .pending
        }
    }

    private func currentStepFromProgress(_ progress: Double) -> ProcessingStep? {
        for step in ProcessingStep.allCases {
            if progress >= step.progressRange.lowerBound && progress < step.progressRange.upperBound {
                return step
            }
        }
        return nil
    }
    
    private func miniTaskCard(_ task: QueuedTask) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Text(task.fileSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(task.outputType.displayName)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            
            Button(action: {
                queueManager.removeTask(task)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func completedTaskCard(_ task: QueuedTask) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                if let completedAt = task.completedAt {
                    Text("完成于 \(completedAt.formatted())")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !task.generatedFiles.isEmpty {
                Button("查看结果") {
                    if let firstFile = task.generatedFiles.first {
                        NSWorkspace.shared.activateFileViewerSelecting([firstFile])
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func failedTaskCard(_ task: QueuedTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    
                    Text(task.fileSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("重试") {
                    queueManager.retryTask(task)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(6)
            }
            
            if let errorMessage = task.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func addToQueue() {
        guard !selectedFiles.isEmpty, let option = selectedOption else { 
            print("[TaskQueueView] Cannot add to queue: files=\(selectedFiles.count), option=\(selectedOption != nil)")
            return 
        }
        
        print("[TaskQueueView] Adding \(selectedFiles.count) files to queue with option: \(option.displayName)")
        queueManager.addTasks(selectedFiles, outputType: option, settings: settings)
        selectedFiles.removeAll()
        selectedOption = nil
        print("[TaskQueueView] Files added successfully, queue size: \(queueManager.queue.count)")
    }
    
    private func handleGlobalDrop(providers: [NSItemProvider]) {
        print("[TaskQueueView] ========== 处理全局拖拽 ==========")
        
        var validFiles: [URL] = []
        let group = DispatchGroup()
        
        for (index, provider) in providers.enumerated() {
            group.enter()
            
            print("[TaskQueueView] 处理提供商 \(index + 1)/\(providers.count)")
            print("[TaskQueueView] 提供商类型: \(provider.registeredTypeIdentifiers)")
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                print("[TaskQueueView] ✅ 提供商支持文件URL类型")
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("[TaskQueueView] ❌ 加载项目失败: \(error.localizedDescription)")
                        return
                    }
                    
                    var fileURL: URL?
                    
                    if let data = item as? Data {
                        fileURL = URL(dataRepresentation: data, relativeTo: nil)
                        print("[TaskQueueView] 📄 从Data加载URL: \(fileURL?.lastPathComponent ?? "未知")")
                    } else if let url = item as? URL {
                        fileURL = url
                        print("[TaskQueueView] 📄 直接获取URL: \(url.lastPathComponent)")
                    } else {
                        print("[TaskQueueView] ❌ 未知的项目类型: \(type(of: item))")
                    }
                    
                    if let url = fileURL {
                        if isValidFile(url) {
                            DispatchQueue.main.async {
                                validFiles.append(url)
                                print("[TaskQueueView] ✅ 有效文件: \(url.lastPathComponent)")
                            }
                        } else {
                            print("[TaskQueueView] ⚠️ 无效文件类型: \(url.lastPathComponent)")
                        }
                    } else {
                        print("[TaskQueueView] ❌ 无法解析文件URL")
                    }
                }
            } else {
                print("[TaskQueueView] ⚠️ 提供商不支持文件URL类型")
                print("[TaskQueueView] 支持的类型: \(provider.registeredTypeIdentifiers)")
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("[TaskQueueView] ========== 全局拖拽处理完成 ==========")
            print("[TaskQueueView] 有效文件数量: \(validFiles.count)")
            
            if !validFiles.isEmpty {
                selectedFiles.append(contentsOf: validFiles)
                print("[TaskQueueView] ✅ 已添加 \(validFiles.count) 个文件到选择列表，总计: \(selectedFiles.count)")
            } else {
                print("[TaskQueueView] ❌ 没有有效文件被添加")
            }
        }
    }
    
    private func isValidFile(_ url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            print("[TaskQueueView] ⚠️ 无法访问安全作用域资源: \(url.lastPathComponent)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let pathExtension = url.pathExtension.lowercased()
        let validExtensions = ["mp3", "wav", "m4a", "mp4", "mov", "mkv", "avi", "flv", "webm", "aac", "ogg", "wma"]
        
        let isValid = validExtensions.contains(pathExtension)
        print("[TaskQueueView] 文件验证: \(url.lastPathComponent) - 扩展名: \(pathExtension) - 有效: \(isValid)")
        
        return isValid
    }
}