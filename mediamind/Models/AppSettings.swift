import Foundation
import SwiftData

@Model
final class AppSettings {
    var whisperModel: String
    var modelPath: String
    var confidenceThreshold: Double
    var enableDenoise: Bool
    var enableVAD: Bool
    var enableSpeakerDiarization: Bool
    var enableVolumeNormalize: Bool
    var enableBilingualSubtitle: Bool
    var subtitleLanguageOrder: String
    var subtitleFormats: [String]
    var llmService: String
    var llmModel: String
    var llmBaseURL: String
    var analysisPrompt: String
    var meetingPrompt: String
    var templatePath: String
    var uploadTemplate: String
    var outputPath: String
    var enableScreenshots: Bool
    var autoCleanup: Bool

    static let defaultAnalysisPrompt = """
你是一个专业的内容分析助手。请根据以下视频转录内容，生成结构化的分析报告。

## 转录内容：
{{transcription}}

## 分析要求：
请按照以下格式生成分析报告：

### 1. 视频主题与用途
简要描述视频的主要主题和用途。

### 2. 内容章节与时间线
根据内容逻辑，划分主要章节，并标注大致时间节点。

### 3. 核心知识点或功能点
提炼出视频中的核心知识点、重要概念或关键功能点。

### 4. 操作步骤与流程
如果涉及操作演示，请详细说明步骤和流程。

### 5. 重要结论与总结
总结视频的重要结论和核心观点。

### 6. 注意事项与易错点
指出需要特别注意的事项和容易出错的地方。

### 7. 可复习、可引用的关键片段
列出值得复习和引用的关键内容片段。

## 内容类型适配：
- 如果是教学视频：重点强调知识点、概念、例题、结论
- 如果是培训视频：重点强调流程、规范、操作要求、注意事项  
- 如果是产品演示视频：重点强调功能介绍、使用步骤、产品亮点、界面说明

请根据实际内容类型，调整各部分的侧重点和详细程度。
"""

    static let defaultMeetingPrompt = """
你是一个专业的会议纪要撰写助手。请根据以下会议转录内容生成会议纪要。

## 会议转录内容：
{{transcription}}

## 输出格式要求：
请严格按照以下格式输出：

上次会议问题[空格]: [详细描述上次会议提出的问题及后续处理情况，如果没有则写"无"]
本次会议内容[空格]: [详细描述本次会议讨论的主要内容，如果没有则写"（无内容）"]
本次会议决议[空格]: [详细描述本次会议形成的决议及执行要求，如果没有则写"（无决议）"]

## 写作要求（必须严格遵循）：
- 严禁使用markdown格式符号和emoji
- 严禁出现时间线和时间节点描述
- 抓中心抓要点：抓住会议中心思想、中心问题、中心工作
- 概括共同决定：以整个会议的名义表述，反映会议全貌
- 分歧处理：未形成一致意见的问题需分别论述并写明分歧
- 规范用语：使用"会议认为"、"会议指出"、"会议强调"、"与会人员一致表示"等
- 忠实原意：引用性文字必须忠实于发言原意，不能篡改
- 纪实性：如实反映会议内容，不搞再创作
- 要点性：围绕会议主旨整理提炼，重点介绍会议成果，切忌记流水账
- 第三人称：以"会议"作为表述主体
- 表述应简洁明了，避免冗长复杂的句子，突出重点，层次分明
- 使用1、2、3等数字编号或a、b、c等字母编号来清晰地列出会议内容和决议，避免使用"首先"、"其次"、"最后"等模糊的时间顺序词汇

## 输出示例：
上次会议问题[空格]: 无
本次会议内容[空格]: 会议认为需要加强项目进度管理，会议指出当前开发进度滞后两周，与会人员一致表示应加班赶工。
本次会议决议[空格]: 会议决定下周完成剩余功能开发，会议强调质量必须把关，与会人员一致表示接受此安排。

现在请根据上述会议转录内容，生成符合要求的会议纪要：
"""

    init(
        whisperModel: String = "auto",
        modelPath: String = "",
        confidenceThreshold: Double = 0.8,
        enableDenoise: Bool = false,
        enableVAD: Bool = true,
        enableSpeakerDiarization: Bool = false,
        enableVolumeNormalize: Bool = true,
        enableBilingualSubtitle: Bool = true,
        subtitleLanguageOrder: String = "cn-en",
        subtitleFormats: [String] = ["SRT", "VTT"],
        llmService: String = "ollama",
        llmModel: String = "llama3.2-vision:11b",
        llmBaseURL: String = "http://127.0.0.1:11434",
        analysisPrompt: String = AppSettings.defaultAnalysisPrompt,
        meetingPrompt: String = AppSettings.defaultMeetingPrompt,
        templatePath: String = "",
        uploadTemplate: String = "meeting",
        outputPath: String = "",
        enableScreenshots: Bool = true,
        autoCleanup: Bool = true
    ) {
        self.whisperModel = whisperModel
        self.modelPath = modelPath
        self.confidenceThreshold = confidenceThreshold
        self.enableDenoise = enableDenoise
        self.enableVAD = enableVAD
        self.enableSpeakerDiarization = enableSpeakerDiarization
        self.enableVolumeNormalize = enableVolumeNormalize
        self.enableBilingualSubtitle = enableBilingualSubtitle
        self.subtitleLanguageOrder = subtitleLanguageOrder
        self.subtitleFormats = subtitleFormats
        self.llmService = llmService
        self.llmModel = llmModel
        self.llmBaseURL = llmBaseURL
        self.analysisPrompt = analysisPrompt
        self.meetingPrompt = meetingPrompt
        self.templatePath = templatePath
        self.uploadTemplate = uploadTemplate
        self.outputPath = outputPath
        self.enableScreenshots = enableScreenshots
        self.autoCleanup = autoCleanup
    }
}