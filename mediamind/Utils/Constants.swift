import Foundation
import SwiftUI

enum TaskStatus: String, CaseIterable {
    case created = "已创建"
    case pending = "等待中"
    case processing = "处理中"
    case validating = "文件校验中"
    case extractingAudio = "音频提取中"
    case transcribing = "转录中"
    case analyzing = "文本分析中"
    case generatingReport = "报告生成中"
    case completed = "已完成"
    case failed = "失败"
    case cancelled = "已取消"

    var color: Color {
        switch self {
        case .created, .pending: return .gray
        case .processing, .validating, .extractingAudio, .transcribing, .analyzing, .generatingReport:
            return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

enum OutputType: String, CaseIterable, Identifiable {
    case subtitle = "subtitle"
    case analysis = "analysis"
    case report = "report"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subtitle: return "字幕生成"
        case .analysis: return "内容解析与摘要"
        case .report: return "会议报告生成"
        }
    }

    var description: String {
        switch self {
        case .subtitle: return "生成SRT格式翻译字幕文件，支持多语言翻译"
        case .analysis: return "AI智能提取核心知识点、时间线、操作步骤"
        case .report: return "生成专业HTML报告，包含摘要、行动项、时间线"
        }
    }

    var icon: String {
        switch self {
        case .subtitle: return "captions.bubble.fill"
        case .analysis: return "brain.head.profile"
        case .report: return "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .subtitle: return .orange
        case .analysis: return .green
        case .report: return .purple
        }
    }

    var tags: [String] {
        switch self {
        case .subtitle: return ["SRT", "翻译", "单语"]
        case .analysis: return ["结构化", "时间线", "Markdown"]
        case .report: return ["HTML", "模板化", "可视化"]
        }
    }

    var outputFiles: [String] {
        switch self {
        case .subtitle: return ["translation.srt"]
        case .analysis: return ["audio_analysis.md"]
        case .report: return ["meeting_report.html"]
        }
    }
}

enum ProcessingStep: String, CaseIterable {
    case fileValidation = "文件校验"
    case audioExtraction = "音频提取"
    case whisperTranscription = "Whisper转录"
    case textAnalysis = "文本分析"
    case reportGeneration = "报告生成"

    var iconName: String {
        switch self {
        case .fileValidation: return "checkmark"
        case .audioExtraction: return "checkmark"
        case .whisperTranscription: return "arrow.triangle.2.circlepath"
        case .textAnalysis: return "clock"
        case .reportGeneration: return "clock"
        }
    }

    var displayName: String {
        switch self {
        case .fileValidation: return "文件校验"
        case .audioExtraction: return "音频提取"
        case .whisperTranscription: return "语音转录"
        case .textAnalysis: return "AI分析"
        case .reportGeneration: return "报告生成"
        }
    }

    var progressRange: ClosedRange<Double> {
        switch self {
        case .fileValidation: return 0.0...0.10
        case .audioExtraction: return 0.10...0.25
        case .whisperTranscription: return 0.25...0.60
        case .textAnalysis: return 0.60...0.82
        case .reportGeneration: return 0.82...1.0
        }
    }
}

enum StepStatus {
    case completed
    case inProgress
    case pending

    var backgroundColor: Color {
        switch self {
        case .completed: return .green
        case .inProgress: return .blue
        case .pending: return Color.gray.opacity(0.3)
        }
    }

    var textColor: Color {
        switch self {
        case .completed: return .gray
        case .inProgress: return .blue
        case .pending: return .gray
        }
    }

    var description: String {
        switch self {
        case .completed: return "完成"
        case .inProgress: return "进行中"
        case .pending: return "等待中"
        }
    }

    var progress: Double {
        switch self {
        case .completed: return 1.0
        case .inProgress: return 0.5
        case .pending: return 0.0
        }
    }

    var iconName: String {
        switch self {
        case .completed: return "checkmark"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .pending: return "clock"
        }
    }
}

enum LLMServiceType: String, CaseIterable {
    case ollama = "ollama"
    case lmstudio = "lmstudio"

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (本地)"
        case .lmstudio: return "LM Studio (本地)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://127.0.0.1:11434"
        case .lmstudio: return "http://127.0.0.1:1234"
        }
    }

    var apiPath: String {
        switch self {
        case .ollama: return "/api/generate"
        case .lmstudio: return "/v1/chat/completions"
        }
    }
}

enum ReportTemplate: String, CaseIterable {
    case custom = "custom"
    case dynamic = "dynamic"  // 用户自定义模板
    case meeting = "meeting"  // 会议纪要模板
    case analysis = "analysis" // 分析报告模板
    case summary = "summary"   // 内容摘要模板

    var displayName: String {
        switch self {
        case .custom: return "自定义模板"
        case .dynamic: return "动态模板"
        case .meeting: return "会议纪要模板"
        case .analysis: return "分析报告模板"
        case .summary: return "内容摘要模板"
        }
    }
    
    /// Built-in templates that ship with the app
    static var builtInTemplates: [ReportTemplate] {
        [.meeting, .analysis, .summary]
    }
}

/// 自定义模板选项（动态扫描）
struct CustomTemplateOption: Identifiable, Equatable {
    let id: String
    let name: String
    
    init(name: String) {
        self.id = name
        self.name = name
    }
}

struct AppConstants {
    static let supportedAudioFormats = ["mp3", "wav", "m4a", "aac", "flac", "ogg"]
    static let supportedVideoFormats = ["mp4", "mov", "mkv", "avi", "webm"]
    static let supportedFormats = supportedAudioFormats + supportedVideoFormats
    static let maxFileSize: Int64 = 2 * 1024 * 1024 * 1024 // 2GB

    static let whisperModels = ["tiny", "base", "small", "medium", "large"]
    static let subtitleTargetLanguages = ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish"]
    static let subtitleTargetLanguageDisplayNames = ["中文", "英文", "日文", "韩文", "法文", "德文", "西班牙文"]
}

extension Color {
    static let appleBlue = Color(NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0))
    static let appleGreen = Color(NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0))
    static let appleOrange = Color(NSColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0))
    static let applePurple = Color(NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1.0))
    static let applePink = Color(NSColor(red: 1.0, green: 0.176, blue: 0.333, alpha: 1.0))
    static let appleTeal = Color(NSColor(red: 0.353, green: 0.784, blue: 0.98, alpha: 1.0))
    static let appleYellow = Color(NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0))
    static let appleGray = Color(NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0))
    static let appleDark = Color(NSColor(red: 0.114, green: 0.114, blue: 0.122, alpha: 1.0))
    static let appleBackground = Color(nsColor: NSColor(name: "appleBackground", dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == .darkAqua || appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == .vibrantDark
        return isDark
            ? NSColor(red: 0.114, green: 0.114, blue: 0.122, alpha: 1.0)
            : NSColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
    }))
    static let appleCard = Color(nsColor: NSColor(name: "appleCard", dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == .darkAqua || appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == .vibrantDark
        return isDark
            ? NSColor(white: 0.25, alpha: 0.8)
            : NSColor.white.withAlphaComponent(0.85)
    }))
    static let appleBorder = Color(nsColor: NSColor(name: "appleBorder", dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == .darkAqua || appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == .vibrantDark
        return isDark
            ? NSColor(white: 0.4, alpha: 0.8)
            : NSColor(red: 0.82, green: 0.82, blue: 0.839, alpha: 1.0)
    }))
}