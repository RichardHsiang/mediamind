import Foundation

/// 配置检查结果
struct ConfigurationCheckResult {
    let isValid: Bool
    let missingItems: [MissingConfiguration]
    
    struct MissingConfiguration: Identifiable {
        let id = UUID()
        let item: ConfigItem
        let description: String
        let action: ConfigAction
        
        enum ConfigItem: String {
            case whisperModel = "Whisper模型"
            case templatePath = "报告模板"
            case outputPath = "输出目录"
            case llmService = "LLM服务"
            case llmModel = "LLM模型"
            case llmBaseURL = "LLM服务地址"
        }
        
        enum ConfigAction {
            case openSettings
            case selectFolder
            case selectModel
            case selectTemplate
        }
    }
}

class ProcessingContext {
    let fileURL: URL
    let outputType: OutputType
    let settings: AppSettings

    var tempDir: URL?
    var audioURL: URL?
    var audioSegmentURLs: [URL] = []
    var useSegmentedProcessing: Bool = false
    var transcriptionResult: TranscriptionResult?
    var analysis: String?
    var generatedFiles: [URL] = []
    var screenshotURLs: [URL] = []

    // 进度回调
    var onProgressUpdate: ((Double, String) -> Void)?

    var fileName: String { fileURL.lastPathComponent }
    var fileExtension: String { fileURL.pathExtension.lowercased() }
    var baseName: String { fileURL.deletingPathExtension().lastPathComponent }
    var fileSize: Int64 {
        (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    init(fileURL: URL, outputType: OutputType, settings: AppSettings) {
        self.fileURL = fileURL
        self.outputType = outputType
        self.settings = settings
    }

    /// 发送进度更新
    func reportProgress(_ progress: Double, description: String) {
        onProgressUpdate?(progress, description)
    }
    
    /// 检查处理所需的配置是否完整
    func checkRequiredConfiguration() -> ConfigurationCheckResult {
        var missingItems: [ConfigurationCheckResult.MissingConfiguration] = []
        
        // 1. 检查Whisper模型
        if settings.whisperModel.isEmpty {
            missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                item: .whisperModel,
                description: "未选择Whisper转录模型，请在设置中选择",
                action: .openSettings
            ))
        }
        
        // 2. 检查输出路径
        if settings.outputPath.isEmpty {
            missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                item: .outputPath,
                description: "未设置输出目录，请在设置中选择",
                action: .selectFolder
            ))
        }
        
        // 3. 根据输出类型检查额外配置
        switch outputType {
        case .report:
            // 会议报告需要模板
            if settings.templatePath.isEmpty {
                missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                    item: .templatePath,
                    description: "生成会议报告需要HTML模板，请在设置中选择模板目录",
                    action: .selectTemplate
                ))
            }
            
            // 会议报告需要LLM服务
            if settings.llmService.isEmpty {
                missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                    item: .llmService,
                    description: "生成会议报告需要LLM服务，请在设置中配置",
                    action: .openSettings
                ))
            }
            
        case .analysis:
            // 分析报告需要LLM服务
            if settings.llmService.isEmpty {
                missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                    item: .llmService,
                    description: "生成分析报告需要LLM服务，请在设置中配置",
                    action: .openSettings
                ))
            }
            
        case .subtitle:
            // 字幕生成不需要额外配置
            break
        }
        
        // 4. 如果配置了LLM服务，检查具体参数
        if !settings.llmService.isEmpty {
            if settings.llmModel.isEmpty {
                missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                    item: .llmModel,
                    description: "未选择LLM模型，请在设置中选择",
                    action: .openSettings
                ))
            }
            
            // 检查Ollama和LM Studio的地址
            let service = LLMServiceType(rawValue: settings.llmService)
            if service == .ollama || service == .lmstudio {
                if settings.llmBaseURL.isEmpty {
                    missingItems.append(ConfigurationCheckResult.MissingConfiguration(
                        item: .llmBaseURL,
                        description: "未配置LLM服务地址，请在设置中填写",
                        action: .openSettings
                    ))
                }
            }
        }
        
        return ConfigurationCheckResult(
            isValid: missingItems.isEmpty,
            missingItems: missingItems
        )
    }
}