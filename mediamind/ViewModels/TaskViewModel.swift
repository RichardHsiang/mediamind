import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class TaskViewModel: ObservableObject {
    @Published var currentTask: TaskItem?
    @Published var progress: Double = 0
    @Published var currentStep: ProcessingStep?
    @Published var currentTaskDescription: String = ""
    @Published var recentTasks: [TaskItem] = []
    @Published var errorMessage: String?
    @Published var outputFiles: [URL] = []
    @Published var transcriptionSegments: [TranscriptionSegment] = []

    private var processingTask: Task<Void, Never>?

    func processFile(_ fileURL: URL, outputType: OutputType, settings: AppSettings) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0

        let task = TaskItem(
            fileName: fileName,
            filePath: fileURL.path,
            fileType: fileExtension,
            fileSize: fileSize,
            outputType: outputType.rawValue,
            status: TaskStatus.created.rawValue,
            taskName: generateTaskName(for: fileName, outputType: outputType),
            processingType: outputType.displayName
        )

        self.currentTask = task
        self.progress = 0
        self.currentStep = nil
        self.errorMessage = nil
        self.outputFiles = []
        self.transcriptionSegments = []

        processingTask = Task {
            do {
                let context = ProcessingContext(
                    fileURL: fileURL,
                    outputType: outputType,
                    settings: settings
                )

                // 设置进度回调
                context.onProgressUpdate = { [weak self] progress, description in
                    Task { @MainActor in
                        self?.updateProgress(progress, description: description)
                    }
                }

                let coordinator = FileProcessingCoordinator.createDefaultCoordinator()
                try await coordinator.process(context: context)

                task.status = TaskStatus.completed.rawValue
                task.completedAt = Date()
                task.outputFiles = context.generatedFiles.map { $0.lastPathComponent }
                self.outputFiles = context.generatedFiles
                self.transcriptionSegments = context.transcriptionResult?.segments ?? []

                print("[TaskViewModel] Generated \(context.generatedFiles.count) files:")
                for file in context.generatedFiles {
                    print("[TaskViewModel]   - \(file.path) (exists: \(FileManager.default.fileExists(atPath: file.path)))")
                }

                if settings.autoCleanup, let tempDir = context.tempDir {
                    try? FileService.shared.cleanupTempDirectory(tempDir)
                }

            } catch {
                if Task.isCancelled {
                    print("[TaskViewModel] Task cancelled by user")
                    task.status = TaskStatus.cancelled.rawValue
                } else {
                    let errorDescription = error.localizedDescription
                    print("[TaskViewModel] ❌ Task failed with error: \(errorDescription)")
                    print("[TaskViewModel] Error details: \(String(describing: error))")

                    task.status = TaskStatus.failed.rawValue
                    task.errorMessage = errorDescription
                    self.errorMessage = errorDescription
                }
            }

            let isDuplicate = recentTasks.contains { $0.id == task.id }
            if !isDuplicate {
                self.recentTasks.insert(task, at: 0)
            }
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        if let task = currentTask {
            task.status = TaskStatus.cancelled.rawValue
            let isDuplicate = recentTasks.contains { $0.id == task.id }
            if !isDuplicate {
                recentTasks.insert(task, at: 0)
            }
        }
    }

    /// 根据进度值更新当前步骤和描述
    private func updateProgress(_ progress: Double, description: String) {
        self.progress = progress
        self.currentTaskDescription = description
        self.currentStep = determineStep(from: progress)
    }

    /// 根据进度值确定当前处理步骤
    private func determineStep(from progress: Double) -> ProcessingStep? {
        switch progress {
        case 0..<0.10:
            return .fileValidation
        case 0.10..<0.25:
            return .audioExtraction
        case 0.25..<0.60:
            return .whisperTranscription
        case 0.60..<0.82:
            return .textAnalysis
        case 0.82..<1.0:
            return .reportGeneration
        case 1.0:
            return nil // 完成
        default:
            return nil
        }
    }

    private func generateTaskName(for fileName: String, outputType: OutputType) -> String {
        let name = fileName.replacingOccurrences(of: ".\(URL(fileURLWithPath: fileName).pathExtension)", with: "")
        switch outputType {
        case .subtitle:
            return "\(name)字幕生成"
        case .analysis:
            return "\(name)内容分析"
        case .report:
            return "\(name)会议报告"
        }
    }
}

enum ProcessingError: Error, LocalizedError {
    case unsupportedFormat
    case fileTooLarge
    case fileValidationFailed
    case audioExtractionFailed
    case transcriptionFailed
    case analysisFailed
    case reportGenerationFailed
    case outputPathNotConfigured
    case templatePathNotConfigured

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .fileTooLarge:
            return "文件大小超过限制（最大2GB）"
        case .fileValidationFailed:
            return "文件验证失败"
        case .audioExtractionFailed:
            return "音频提取失败"
        case .transcriptionFailed:
            return "语音转录失败"
        case .analysisFailed:
            return "文本分析失败"
        case .reportGenerationFailed:
            return "报告生成失败"
        case .outputPathNotConfigured:
            return "输出目录未配置，请在设置中选择输出目录"
        case .templatePathNotConfigured:
            return "模板目录未配置，请在设置中选择模板目录"
        }
    }
}