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
    var subtitleTargetLanguage: String
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
    var useFP16: Bool
    var batchSize: Int
    var temperature: Double
    var bestOf: Int
    var beamSize: Int

    static let defaultAnalysisPrompt = """
你是一个专业的内容分析助手。请根据以下视频转录内容，生成结构化的分析报告。

## 转录内容：
{{transcription}}

## 分析要求：
请严格按照以下格式生成分析报告：

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

### 8. 截图引用（可选，根据视频内容判断是否需要，并插入到报告具体内容中）
使用视频截图，作为分析报告文字的形象说明，增强报告的可视化效果。

## 内容类型适配：
- 如果是教学视频：重点强调知识点、概念、例题、结论
- 如果是培训视频：重点强调流程、规范、操作要求、注意事项  
- 如果是产品演示视频：重点强调功能介绍、使用步骤、产品亮点、界面说明

请根据实际内容类型，调整各部分的侧重点和详细程度。
"""

    static let defaultMeetingPrompt = """
你是一个专业的会议纪要撰写助手。请根据以下会议转录内容生成会议纪要。

## 转录内容：
{{transcription}}

## 输出格式要求：
请严格按照以下格式输出，各部分之间保持一行间隔：

一、上次会议问题
[详细描述上次会议提出的问题及后续处理情况，如果没有则写"无"]

二、本次会议内容
[详细描述本次会议讨论的所有重要事项、细节、观点和过程，内容要详尽全面，严禁随意删减或强行截断，确保还原会议全貌]

三、本次会议决议
[详细描述本次会议形成的决议及执行要求，如果没有则写"无决议"]

## 写作要求（必须严格遵循）：
- 严禁使用markdown格式符号和emoji
- 严禁出现时间线和时间节点描述
- 抓中心抓要点：抓住会议中心思想、中心问题、中心工作，同时保留必要的讨论细节和背景信息
- 概括共同决定：以整个会议的名义表述，反映会议全貌
- 分歧处理：未形成一致意见的问题需分别论述并写明分歧
- 规范用语：使用"会议认为"、"会议指出"、"会议强调"、"与会人员一致表示"等
- 忠实原意：引用性文字必须忠实于发言原意，不能篡改
- 纪实性：如实反映会议内容，不搞再创作，确保内容的完整性
- 要点性：围绕会议主旨整理提炼，重点介绍会议成果
- 第三人称：以"会议"作为表述主体
- 内容应详实全面，真实还原会议讨论细节，避免过度冗长但也绝不能过度压缩
- 各部分的内容可通过使用1、2、3等数字编号或a, b, c等字母编号来清晰、有序地逐项列出
- 各部分的编号应从头开始，并保持类型一致，具体格式为：x. [内容]，其中x为数字或字母，内容为对应的会议内容要点
- 每个要点的内容应独立成行，确保每个要点清晰、突出

## 输出示例：
上次会议问题
无

本次会议内容
会议详细讨论了关于基础设施开发板的适配问题。会议认为需要针对性能可用性工作的优先级进行重新排序，例如上周发现的Redis服务器负载问题。基础设施团队指出，RG单元测试中存在的未限制缓存是导致该问题的根本原因。与会人员一致表示，在新功能开发阶段应尽早引入SRE团队进行审查，以评估潜在风险。会议强调，必须对资源限制进行严格考量，特别是针对单元测试和镜像数量的限制。

本次会议决议
会议决定下周完成剩余功能开发，会议强调质量必须把关，与会人员一致表示接受此安排。

现在请根据上述会议转录内容，生成完整详实的会议纪要：
"""

    init(
        whisperModel: String = "",
        modelPath: String = "",
        confidenceThreshold: Double = 0.8,
        enableDenoise: Bool = false,
        enableVAD: Bool = true,
        enableSpeakerDiarization: Bool = false,
        enableVolumeNormalize: Bool = true,
        subtitleTargetLanguage: String = "Chinese",
        llmService: String = "",
        llmModel: String = "",
        llmBaseURL: String = "",
        analysisPrompt: String = AppSettings.defaultAnalysisPrompt,
        meetingPrompt: String = AppSettings.defaultMeetingPrompt,
        templatePath: String = "",
        uploadTemplate: String = "",
        outputPath: String = "",
        enableScreenshots: Bool = true,
        autoCleanup: Bool = true,
        useFP16: Bool = true,
        batchSize: Int = 0,
        temperature: Double = 0.0,
        bestOf: Int = 5,
        beamSize: Int = 5
    ) {
        self.whisperModel = whisperModel
        self.modelPath = modelPath
        self.confidenceThreshold = confidenceThreshold
        self.enableDenoise = enableDenoise
        self.enableVAD = enableVAD
        self.enableSpeakerDiarization = enableSpeakerDiarization
        self.enableVolumeNormalize = enableVolumeNormalize
        self.subtitleTargetLanguage = subtitleTargetLanguage
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
        self.useFP16 = useFP16
        self.batchSize = batchSize
        self.temperature = temperature
        self.bestOf = bestOf
        self.beamSize = beamSize
    }

    // 验证模型是否已选择
    var isWhisperModelConfigured: Bool {
        return !whisperModel.isEmpty && !modelPath.isEmpty
    }
}