import Foundation
import Combine

@MainActor
class TaskQueueManager: ObservableObject {
    static let shared = TaskQueueManager()
    
    @Published var queue: [QueuedTask] = []
    @Published var isProcessing: Bool = false
    @Published var currentTask: QueuedTask?
    @Published var completedTasks: [QueuedTask] = []
    @Published var failedTasks: [QueuedTask] = []
    
    // 模板缺失提示状态
    @Published var showTemplateMissingAlert: Bool = false
    @Published var templateMissingTask: QueuedTask?
    
    // 配置缺失提示状态
    @Published var showConfigurationAlert: Bool = false
    @Published var configurationMissingItems: [ConfigurationCheckResult.MissingConfiguration] = []
    @Published var configurationMissingTask: QueuedTask?
    
    private var processingTask: Task<Void, Never>?
    private var pendingTemplatePath: String?
    
    private init() {}
    
    func addTasks(_ files: [URL], outputType: OutputType, settings: AppSettings) {
        let newTasks = files.map { file in
            QueuedTask(
                id: UUID(),
                fileURL: file,
                outputType: outputType,
                settings: settings,
                status: .pending,
                progress: 0,
                createdAt: Date()
            )
        }
        
        queue.append(contentsOf: newTasks)
        print("[TaskQueueManager] Added \(newTasks.count) tasks to queue")
        
        if !isProcessing {
            startProcessing()
        }
    }
    
    func startProcessing() {
        guard !isProcessing, !queue.isEmpty else { return }
        
        isProcessing = true
        processingTask = Task {
            await processQueue()
        }
    }
    
    func pauseProcessing() {
        processingTask?.cancel()
        isProcessing = false
        print("[TaskQueueManager] Processing paused")
    }
    
    func clearCompleted() {
        completedTasks.removeAll()
        print("[TaskQueueManager] Cleared completed tasks")
    }
    
    func clearFailed() {
        failedTasks.removeAll()
        print("[TaskQueueManager] Cleared failed tasks")
    }
    
    func clearAll() {
        pauseProcessing()
        queue.removeAll()
        currentTask = nil
        completedTasks.removeAll()
        failedTasks.removeAll()
        print("[TaskQueueManager] Cleared all tasks")
    }
    
    func removeTask(_ task: QueuedTask) {
        if let index = queue.firstIndex(where: { $0.id == task.id }) {
            queue.remove(at: index)
            print("[TaskQueueManager] Removed task from queue: \(task.fileURL.lastPathComponent)")
        }
    }
    
    func retryTask(_ task: QueuedTask) {
        let retryTaskInstance = task
        retryTaskInstance.status = .pending
        retryTaskInstance.progress = 0
        retryTaskInstance.errorMessage = nil
        
        if let index = failedTasks.firstIndex(where: { $0.id == task.id }) {
            failedTasks.remove(at: index)
        }
        
        queue.insert(retryTaskInstance, at: 0)
        print("[TaskQueueManager] Retrying task: \(task.fileURL.lastPathComponent)")
        
        if !isProcessing {
            startProcessing()
        }
    }
    
    /// 当模板缺失时暂停队列并显示提示
    func pauseForTemplateSelection(task: QueuedTask) {
        pauseProcessing()
        templateMissingTask = task
        showTemplateMissingAlert = true
        print("[TaskQueueManager] Paused for template selection, task: \(task.fileURL.lastPathComponent)")
    }
    
    /// 用户设置模板路径后继续处理
    func resumeWithTemplatePath(_ templatePath: String) {
        pendingTemplatePath = templatePath
        showTemplateMissingAlert = false
        
        // 更新当前任务和队列中所有任务的设置
        if let task = templateMissingTask {
            task.settings.templatePath = templatePath
            
            // 将任务重新放回队列头部
            task.status = .pending
            task.progress = 0
            task.errorMessage = nil
            queue.insert(task, at: 0)
            templateMissingTask = nil
        }
        
        // 同时更新队列中其他任务的模板路径
        for queuedTask in queue {
            queuedTask.settings.templatePath = templatePath
        }
        
        print("[TaskQueueManager] Resuming with template path: \(templatePath)")
        startProcessing()
    }
    
    /// 当配置不完整时暂停队列并显示提示
    func pauseForConfiguration(items: [ConfigurationCheckResult.MissingConfiguration], task: QueuedTask) {
        pauseProcessing()
        configurationMissingItems = items
        configurationMissingTask = task
        showConfigurationAlert = true
        print("[TaskQueueManager] Paused for configuration, missing: \(items.map { $0.item.rawValue }.joined(separator: ", "))")
    }
    
    /// 用户完成配置后继续处理
    func resumeAfterConfiguration() {
        showConfigurationAlert = false
        
        // 将任务重新放回队列头部
        if let task = configurationMissingTask {
            task.status = .pending
            task.progress = 0
            task.errorMessage = nil
            queue.insert(task, at: 0)
            configurationMissingTask = nil
        }
        
        configurationMissingItems.removeAll()
        print("[TaskQueueManager] Resuming after configuration")
        startProcessing()
    }
    
    private func processQueue() async {
        while !queue.isEmpty && !Task.isCancelled {
            guard let task = queue.first else { break }
            
            currentTask = task
            task.status = .processing
            queue.removeFirst()
            
            print("[TaskQueueManager] Processing task: \(task.fileURL.lastPathComponent)")
            
            do {
                try await processSingleTask(task)
                
                await MainActor.run {
                    task.status = .completed
                    task.progress = 1.0
                    task.completedAt = Date()
                    completedTasks.append(task)
                }
                print("[TaskQueueManager] Task completed: \(task.fileURL.lastPathComponent)")
            } catch let error as ProcessingError {
                // 处理配置缺失错误 - 暂停队列并提示用户
                if case .configurationIncomplete(let items, _) = error {
                    await MainActor.run {
                        // 将任务放回队列头部
                        task.status = .pending
                        task.progress = 0
                        task.errorMessage = nil
                        queue.insert(task, at: 0)
                        // 暂停并显示配置提示
                        pauseForConfiguration(items: items, task: task)
                    }
                    print("[TaskQueueManager] Task paused for configuration: \(task.fileURL.lastPathComponent)")
                    // 退出当前处理循环，等待用户配置
                    break
                } else if case .templatePathNotConfigured = error {
                    // 模板缺失错误 - 暂停队列并提示用户选择模板
                    await MainActor.run {
                        task.status = .pending
                        task.progress = 0
                        task.errorMessage = nil
                        queue.insert(task, at: 0)
                        pauseForTemplateSelection(task: task)
                    }
                    print("[TaskQueueManager] Task paused for template selection: \(task.fileURL.lastPathComponent)")
                    break
                } else {
                    await MainActor.run {
                        task.status = .failed
                        task.errorMessage = error.localizedDescription
                        failedTasks.append(task)
                    }
                    print("[TaskQueueManager] Task failed: \(task.fileURL.lastPathComponent) - \(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    task.status = .failed
                    task.errorMessage = error.localizedDescription
                    failedTasks.append(task)
                }
                print("[TaskQueueManager] Task failed: \(task.fileURL.lastPathComponent) - \(error.localizedDescription)")
            }
            
            await MainActor.run {
                currentTask = nil
            }
            
            // 任务完成后强制清理内存
            await forceCleanupAllResources()
            
            if Task.isCancelled {
                break
            }
            
            // 任务之间添加短暂延迟，确保资源完全释放
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟
        }
        
        await MainActor.run {
            isProcessing = false
            currentTask = nil
        }
        print("[TaskQueueManager] Queue processing finished")
    }
    
    private func processSingleTask(_ task: QueuedTask) async throws {
        let context = ProcessingContext(
            fileURL: task.fileURL,
            outputType: task.outputType,
            settings: task.settings
        )
        
        context.onProgressUpdate = { progress, description in
            Task { @MainActor in
                task.progress = progress
                task.currentDescription = description
            }
        }
        
        let coordinator = FileProcessingCoordinator.createDefaultCoordinator()
        try await coordinator.process(context: context)
        
        await MainActor.run {
            task.generatedFiles = context.generatedFiles
        }
    }
    
    private func forceCleanupAllResources() async {
        print("[TaskQueueManager] 开始强制清理所有资源...")
        
        // 在后台线程执行清理操作，避免阻塞主线程
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .background).async {
                // 1. 清理 URLSession 缓存
                URLCache.shared.removeAllCachedResponses()
                
                // 2. 简单延迟等待
                Thread.sleep(forTimeInterval: 0.5)
                
                // 3. 清理 autorelease pool
                autoreleasepool { }
                
                print("[TaskQueueManager] 强制清理完成")
                continuation.resume()
            }
        }
    }
}

class QueuedTask: ObservableObject, Identifiable {
    let id: UUID
    let fileURL: URL
    let outputType: OutputType
    let settings: AppSettings
    @Published var status: TaskStatus
    @Published var progress: Double
    @Published var currentDescription: String
    @Published var errorMessage: String?
    var createdAt: Date
    var completedAt: Date?
    var generatedFiles: [URL] = []
    
    init(
        id: UUID = UUID(),
        fileURL: URL,
        outputType: OutputType,
        settings: AppSettings,
        status: TaskStatus = .pending,
        progress: Double = 0,
        currentDescription: String = "",
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        generatedFiles: [URL] = []
    ) {
        self.id = id
        self.fileURL = fileURL
        self.outputType = outputType
        self.settings = settings
        self.status = status
        self.progress = progress
        self.currentDescription = currentDescription
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.generatedFiles = generatedFiles
    }
    
    var fileName: String {
        fileURL.lastPathComponent
    }
    
    var fileSize: String {
        let bytes = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        return formatFileSize(bytes)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}