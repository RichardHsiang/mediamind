# MediaMind - Technical Standards

## 技术栈

### 前端/UI
- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI（macOS 14+）
- **数据持久化**: SwiftData
- **设计系统**: Apple Design System，遵循 macOS Human Interface Guidelines

### 后端/处理引擎（完全本地部署）
- **音频提取**: FFmpeg（系统本地安装，通过 Process 调用）
- **语音识别**: mlx-whisper（本地 Python 环境，Apple Silicon 原生加速）
- **LLM 调用**: Ollama 或 LM Studio（本地 HTTP API，127.0.0.1）
- **截图提取**: OpenCV（本地 Python 绑定）
- **字幕生成**: 自定义 Swift 实现

### 本地依赖要求
用户需自行在 macOS 上安装以下组件：
- **FFmpeg**: `brew install ffmpeg`
- **Python 3.9+**: 系统自带或 `brew install python`
- **mlx-whisper**: `pip install mlx-whisper`
- **Ollama**: 从 https://ollama.ai 下载安装 或 **LM Studio**: 从 https://lmstudio.ai 下载安装
- **OpenCV**: `pip install opencv-python`（可选，用于截图提取）

### 开发环境
- **IDE**: Xcode 15+
- **最低系统**: macOS 14 Sonoma
- **架构**: Apple Silicon（arm64）优先，兼容 Intel

## 代码规范

### Swift 规范
- 使用 SwiftUI 声明式语法
- 遵循 MVVM 架构模式
- ViewModel 使用 `@Observable`（iOS 17+ / macOS 14+）
- 数据模型使用 SwiftData `@Model`
- 异步操作使用 Swift Concurrency（async/await）
- 错误处理使用 `Result` 类型或 `throws`

### 命名规范
- 类型名：UpperCamelCase（如 `TaskStatus`）
- 函数/变量：lowerCamelCase（如 `processFile`）
- 常量：lowerCamelCase（如 `maxFileSize`）
- 文件组织：按功能模块分目录

### 项目结构
```
mediamind/
├── mediamind/
│   ├── App/
│   │   └── mediamindApp.swift
│   ├── Models/
│   │   ├── TaskItem.swift
│   │   ├── ProcessingTask.swift
│   │   └── Settings.swift
│   ├── Views/
│   │   ├── MainView.swift
│   │   ├── UploadView.swift
│   │   ├── OptionsView.swift
│   │   ├── ProcessingView.swift
│   │   ├── ResultsView.swift
│   │   ├── HistoryView.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/
│   │   ├── TaskViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Services/
│   │   ├── FFmpegService.swift
│   │   ├── WhisperService.swift
│   │   ├── LLMService.swift
│   │   ├── FileService.swift
│   │   └── ReportService.swift
│   └── Utils/
│       ├── Constants.swift
│       └── Extensions.swift
├── mediamindTests/
└── mediamindUITests/
```

## 依赖管理
- 优先使用系统框架（SwiftUI、SwiftData、Foundation）
- 外部依赖通过 Swift Package Manager 管理
- 最小化第三方依赖数量

## 性能要求
- UI 响应时间 < 16ms（60fps）
- 文件处理在后台线程执行
- 大文件支持分段处理
- 内存使用监控，避免 OOM

## 安全规范
- **零云端依赖**: 所有处理均在本地完成，不调用任何云端 API
- **零 API 密钥**: 不硬编码任何 API 密钥或访问令牌
- **本地网络-only**: LLM 调用仅限 127.0.0.1 本地地址（Ollama/LM Studio）
- **本地文件访问遵循沙盒规则**
- **临时文件及时清理**
- **用户数据不出本机**
