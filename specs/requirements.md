# MediaMind 功能需求规格文档

## 1. 文件上传与任务创建

### REQ-1.1 文件上传
**需求**: 系统应支持用户通过拖拽或文件选择器上传音视频文件
**验收标准**:
- 支持拖拽文件到上传区域
- 支持点击上传区域打开文件选择器
- 支持文件类型：mp3, wav, m4a, aac, flac, ogg, mp4, mov, mkv, avi, webm
- 显示文件图标、名称、大小信息
- 支持删除已选文件

### REQ-1.2 文件识别与校验
**需求**: 系统自动识别文件类型并进行完整性校验
**验收标准**:
- 自动区分音频/视频文件
- 校验文件是否可读取
- 校验文件是否为空
- 校验文件格式是否受支持
- 校验文件大小是否超出限制（默认 2GB）
- 校验失败时显示明确错误信息

### REQ-1.3 任务创建
**需求**: 上传成功后自动创建处理任务
**验收标准**:
- 自动生成唯一任务 ID（UUID）
- 记录原始文件名、路径、类型、大小
- 记录创建时间
- 任务状态初始化为"已创建"
- 任务持久化到 SwiftData

## 2. 输出选项选择

### REQ-2.1 选项展示
**需求**: 展示三个互斥的输出选项卡片
**验收标准**:
- 选项一：字幕生成（橙色标识，SRT/VTT/双语）
- 选项二：内容解析与摘要（绿色标识，结构化/Markdown）
- 选项三：会议报告生成（紫色标识，HTML/模板化）
- 卡片包含图标、标题、描述、功能标签

### REQ-2.2 选项选择
**需求**: 用户可选择其中一个输出选项
**验收标准**:
- 点击卡片后添加选中状态（蓝色边框、勾选图标）
- 同一时间只能选中一个选项
- 选中后激活"开始处理"按钮
- 切换选项时更新选中状态

## 3. 处理流程与状态展示

### REQ-3.1 处理步骤
**需求**: 系统按以下步骤执行处理
**验收标准**:
1. 文件校验
2. 音频提取（仅视频文件）
3. Whisper 转录
4. 文本分析（根据选项）
5. 报告生成（根据选项）

### REQ-3.2 进度展示
**需求**: 实时展示处理进度
**验收标准**:
- 显示圆形进度环和百分比
- 显示当前执行步骤名称
- 显示所有步骤的状态（已完成/进行中/等待中）
- 步骤间有连接线表示进度
- 进行中步骤有脉冲动画

### REQ-3.3 状态流转
**需求**: 任务状态正确流转
**验收标准**:
- 已创建 → 文件校验中 → 音频提取中 → 转录中 → 文本分析中 → 报告生成中 → 完成
- 任一阶段可失败，记录失败原因
- 支持取消任务
- 失败/取消后保留已完成的中间结果

## 4. 结果展示

### REQ-4.1 结果卡片
**需求**: 处理完成后展示输出文件
**验收标准**:
- 每个输出文件以卡片形式展示
- 显示文件类型图标、名称、描述
- 显示文件类型标签（主输出/原始/元数据）
- 提供预览和下载按钮
- 支持"下载全部"功能

### REQ-4.2 输出文件
**需求**: 根据选项生成对应输出文件
**验收标准**:
- 字幕生成：subtitles.srt, subtitles_bilingual.srt
- 内容分析：audio_analysis.md
- 会议报告：meeting_report.html
- 原始转录：audio.md
- 元数据：metadata.json

## 5. 历史记录

### REQ-5.1 历史列表
**需求**: 展示最近处理任务列表
**验收标准**:
- 显示任务名称、处理类型、时间
- 显示状态标签（已完成/处理中/失败）
- 支持保存和删除操作
- 按时间倒序排列

### REQ-5.2 历史详情
**需求**: 可查看历史任务详情
**验收标准**:
- 查看任务基本信息
- 查看输出文件列表
- 重新下载结果文件

## 6. 系统设置

### REQ-6.1 Whisper 设置
**需求**: 配置 Whisper 模型参数
**验收标准**:
- 模型选择：自动/tiny/base/small/medium/large
- 模型存储路径配置
- 置信度阈值滑块（0-100%）
- 预设按钮：严格(90%)/默认(80%)/宽松(60%)

### REQ-6.2 音频处理设置
**需求**: 配置音频预处理选项
**验收标准**:
- 启用降噪开关
- 语音活动检测(VAD)开关
- 说话人分离开关
- 音量归一化开关

### REQ-6.3 字幕设置
**需求**: 配置字幕生成选项
**验收标准**:
- 生成双语字幕开关
- 字幕语言顺序选择
- 字幕格式选择（SRT/VTT/ASS）

### REQ-6.4 LLM 设置
**需求**: 配置本地大语言模型服务
**验收标准**:
- LLM 服务选择：Ollama（本地 127.0.0.1:11434）/ LM Studio（本地 127.0.0.1:1234 或其他自定义端口）
- 模型名称输入（如 llama3.1、qwen2.5 等本地已下载模型）
- 自动检测本地服务是否运行
- 服务未运行时提示用户启动

### REQ-6.5 提示词设置
**需求**: 自定义内容分析提示词
**验收标准**:
- 文本编辑区域输入提示词模板
- 支持 {{transcription}} 占位符
- 保存和恢复默认按钮

### REQ-6.6 报告模板设置
**需求**: 选择报告模板
**验收标准**:
- 模板选择：会议纪要/项目汇报/培训总结/访谈记录/自定义

### REQ-6.7 输出设置
**需求**: 配置输出选项
**验收标准**:
- 输出目录配置
- 提取关键截图开关
- 自动清理临时文件开关

## 7. 数据模型

### REQ-7.1 TaskItem 模型
```swift
@Model
final class TaskItem {
    var id: UUID
    var fileName: String
    var filePath: String
    var fileType: String
    var fileSize: Int64
    var outputType: String
    var status: String
    var createdAt: Date
    var completedAt: Date?
    var outputFiles: [String]
    var errorMessage: String?
}
```

### REQ-7.2 AppSettings 模型
```swift
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
    var analysisPrompt: String
    var reportTemplate: String
    var outputPath: String
    var enableScreenshots: Bool
    var autoCleanup: Bool
}
```

## 8. 非功能需求

### REQ-8.1 性能
- 支持大文件处理（>1GB）
- UI 保持响应，处理在后台线程
- 进度更新频率 >= 1Hz

### REQ-8.2 可靠性
- 单个步骤失败不导致整个系统崩溃
- 支持异常回退和重试
- 保留已完成的中间结果

### REQ-8.3 可维护性
- 模块分离清晰
- 配置文件化
- 日志可追踪

### REQ-8.4 安全与隐私（完全本地）
- **零云端传输**: 所有处理均在本地完成，音视频文件和转录文本不上传任何云端服务
- **零 API 密钥**: 不依赖任何需要 API 密钥的云端服务
- **本地网络-only**: LLM 调用仅限 127.0.0.1 本地地址，不连接外网
- **临时文件自动清理**
- **沙盒文件访问**
