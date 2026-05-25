# MediaMind - Architecture

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ MainView │ │ Upload   │ │ Process  │ │ Settings │       │
│  │          │ │ View     │ │ View     │ │ View     │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
│       └─────────────┴─────────────┴─────────────┘            │
│                         │                                    │
│                    ViewModels                                │
│              (TaskViewModel, SettingsVM)                     │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────┼────────────────────────────────────┐
│                      Business Layer                          │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ TaskManager  │ │ FileService  │ │ ReportGen    │       │
│  │              │ │              │ │              │       │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘       │
│         └────────────────┴────────────────┘                │
│                         │                                    │
│                    SwiftData Models                          │
│              (TaskItem, Settings, etc.)                      │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────┼────────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ FFmpeg   │ │ Whisper  │ │ LLM      │ │ OpenCV   │       │
│  │ Service  │ │ Service  │ │ Service  │ │ Service  │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
│       └────────────┴────────────┴────────────┘              │
│                         │                                    │
│              External Tools (Process/Local HTTP)             │
│    (ffmpeg, mlx_whisper, ollama/lmstudio@127.0.0.1, python) │
└─────────────────────────────────────────────────────────────┘
```

## 模块职责

### Presentation Layer（表现层）
- **MainView**: 应用主窗口，侧边栏导航
- **UploadView**: 文件上传区域，拖拽支持
- **OptionsView**: 输出选项选择（字幕/分析/报告）
- **ProcessingView**: 处理进度展示，步骤状态
- **ResultsView**: 结果文件展示，预览下载
- **HistoryView**: 历史任务列表
- **SettingsView**: 系统设置面板

### Business Layer（业务层）
- **TaskManager**: 任务生命周期管理，状态流转
- **FileService**: 文件校验、路径管理、临时文件清理
- **ReportGenerator**: 报告模板渲染，HTML/Markdown 生成
- **SwiftData Models**: 任务、设置等数据持久化

### Service Layer（服务层）
- **FFmpegService**: 音频提取、格式转换、视频信息获取
- **WhisperService**: 语音转录，模型管理，结果解析
- **LLMService**: Ollama/LM Studio HTTP API 调用
- **OpenCVService**: 关键帧提取、视频片段截取

## 数据流

```
用户上传文件
    ↓
FileService 校验文件
    ↓
TaskManager 创建任务（SwiftData 持久化）
    ↓
FFmpegService 提取音频（视频文件）
    ↓
WhisperService 执行转录
    ↓
LLMService 内容分析（根据选项）
    ↓
ReportGenerator 生成报告
    ↓
更新任务状态，展示结果
```

## 状态管理

### 任务状态机
```
[已创建] → [文件校验中] → [音频提取中] → [转录中] → [文本分析中] → [报告生成中] → [完成]
    ↓           ↓              ↓            ↓           ↓            ↓
[已取消]   [失败] ←──────────←──────────←──────────←──────────←──────────
```

### 全局状态
- 当前选中导航项
- 当前处理任务
- 应用设置配置

## 扩展点
- **模型替换**: WhisperService 协议化，支持不同后端
- **LLM 替换**: LLMService 协议化，支持 Ollama / LM Studio 等不同本地提供商
- **模板扩展**: ReportGenerator 支持自定义模板加载
- **输出格式**: 通过策略模式扩展新输出类型
