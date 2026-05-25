# MediaMind

<div align="center">

**智能音视频处理 · 本地隐私安全**

[![macOS](https://img.shields.io/badge/macOS-14.6+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[功能特性](#功能特性) • [快速开始](#快速开始) • [安装指南](#安装指南) • [使用文档](#使用文档) • [开发指南](#开发指南)

</div>

---

## 项目简介

MediaMind 是一款专为 macOS 设计的本地音视频智能处理桌面应用。通过集成 Whisper 语音识别、大语言模型分析和自动化报告生成，为用户提供从音视频文件到结构化文档的一站式解决方案。

### 核心价值

- **完全本地处理** - 所有数据处理均在本地完成，零云端依赖，确保隐私安全
- **AI 智能分析** - 集成 Whisper + LLM，实现高精度语音转录和智能内容分析
- **结构化输出** - 支持字幕、摘要、会议报告等多种输出格式
- **高效快速** - 基于 Apple Silicon 优化，充分利用本地硬件加速
- **多场景覆盖** - 会议记录、教学视频、培训录像、访谈播客等场景

---

## 功能特性

### 智能语音转录

- **高精度识别** - 基于 mlx-whisper，支持多种 Whisper 模型
- **多格式支持** - MP3, WAV, M4A, AAC, FLAC, OGG, MP4, MOV, MKV, AVI, WEBM
- **音频预处理** - 降噪、VAD、说话人分离、音量归一化
- **实时进度** - 可视化处理进度和状态展示

### 内容分析与摘要

- **AI 智能分析** - 集成 Ollama/LM Studio 本地 LLM
- **结构化输出** - 自动提取主题、章节、知识点、操作步骤
- **多维度分析** - 支持教学视频、培训视频、产品演示等不同类型
- **可追溯性** - 所有分析结果可追溯到原始时间戳

### 会议报告生成

- **专业模板** - 支持自定义 HTML 模板
- **自动填充** - 智能提取会议信息并填充模板
- **格式规范** - 符合企业会议纪要标准
- **可编辑性** - 生成的报告可直接编辑和导出

### 字幕生成

- **多格式支持** - SRT, VTT, ASS 字幕格式
- **多语言支持** - 支持中文、英文、法文、日文、德文、意大利文、西班牙文、葡萄牙文、阿拉伯文、泰文
- **时间同步** - 精确的时间戳对齐
- **批量处理** - 支持批量生成字幕文件

### 灵活配置

- **模型选择** - 支持多种 Whisper 模型（tiny/base/small/medium/large）
- **参数调优** - 置信度阈值、音频处理选项可配置
- **自定义提示词** - 支持自定义分析和报告生成提示词
- **模板管理** - 支持自定义报告模板

---

## 快速开始

### 系统要求

- **操作系统**: macOS 14.6 Sonoma 或更高版本
- **处理器**: Apple Silicon (M1/M2/M3) 或 Intel Mac
- **内存**: 建议 8GB 以上
- **磁盘空间**: 至少 5GB 可用空间

### 依赖安装

MediaMind 需要以下本地依赖：

```bash
# 1. 安装 FFmpeg（用于音视频处理）
brew install ffmpeg

# 2. 安装 Python 3.9+（如果未安装）
brew install python

# 3. 安装 mlx-whisper（用于语音识别）
pip install mlx-whisper

# 4. 安装 Ollama（用于 LLM 分析）
# 访问 https://ollama.ai 下载安装
# 或使用 Homebrew
brew install ollama

# 5. 下载 LLM 模型（示例：llama3.2）
ollama pull llama3.2

# 6. 启动 Ollama 服务
ollama serve
```

> **注意**: 也可以使用 LM Studio 替代 Ollama，访问 https://lmstudio.ai 下载安装。

### 首次配置

1. **启动应用** - 双击 MediaMind.app 启动应用
2. **配置目录** - 在设置中配置：
   - 模板目录（存放自定义 HTML 模板）
   - 输出目录（存放处理结果文件）
3. **配置服务** - 确保以下服务正在运行：
   - Ollama 服务（`ollama serve`）
   - 或 LM Studio 服务
4. **选择模型** - 在设置中选择：
   - Whisper 模型（推荐 base 或 small）
   - LLM 模型（如 llama3.2）

---

## 使用文档

### 基本流程

```
上传文件 → 选择输出类型 → 开始处理 → 查看结果
```

### 输出类型

| 类型 | 说明 | 输出文件 |
|------|------|----------|
| 字幕生成 | 生成视频字幕文件 | .srt, .vtt, .ass |
| 内容分析 | AI 智能内容摘要 | audio_analysis.md, audio.md |
| 会议报告 | 结构化会议纪要 | meeting_report.html, audio.md |

### 处理步骤

1. **文件校验** - 验证文件格式和完整性
2. **音频提取** - 从视频中提取音频（视频文件）
3. **语音转录** - Whisper 转录为文本
4. **文本分析** - LLM 内容分析（可选）
5. **报告生成** - 生成结构化报告（可选）

### 高级功能

#### 自定义提示词

在设置中可以自定义以下提示词：

- **分析提示词** - 控制内容分析的输出结构和重点
- **会议纪要提示词** - 控制会议纪要的格式和风格

#### 自定义模板

1. 将自定义 HTML 模板放入模板目录
2. 模板文件命名格式：`{模板名}.html`
3. 在设置中选择对应的模板

#### 批量处理

支持同时处理多个文件，自动排队执行。

---

## 安装指南

### 从源码构建

```bash
# 1. 克隆仓库
git clone https://github.com/RichardHsiang/mediamind.git
cd mediamind

# 2. 打开 Xcode 项目
open mediamind.xcodeproj

# 3. 选择目标设备和配置
# - Target: mediamind
# - Configuration: Debug 或 Release

# 4. 构建并运行
# 按 Cmd + R 或点击运行按钮
```

### 发布版本

从 [Releases](https://github.com/RichardHsiang/mediamind/releases) 页面下载最新的 `.dmg` 安装包。

---

## 开发指南

### 项目结构

```
mediamind/
├── mediamind/                    # 主应用代码
│   ├── mediamindApp.swift        # 应用入口
│   ├── Models/                   # 数据模型
│   │   ├── AppSettings.swift     # 应用设置
│   │   └── TaskItem.swift        # 任务模型
│   ├── Views/                    # UI 视图
│   │   ├── MainView.swift        # 主视图
│   │   ├── UploadView.swift      # 上传视图
│   │   ├── OptionsView.swift     # 选项视图
│   │   ├── ProcessingView.swift  # 处理视图
│   │   ├── ResultsView.swift     # 结果视图
│   │   ├── SettingsView.swift    # 设置视图
│   │   └── Components/           # 组件
│   ├── ViewModels/               # 视图模型
│   │   └── TaskViewModel.swift   # 任务视图模型
│   ├── Services/                 # 业务服务
│   │   ├── FFmpegService.swift   # FFmpeg 服务
│   │   ├── WhisperService.swift  # Whisper 服务
│   │   ├── LLMService.swift      # LLM 服务
│   │   ├── ReportService.swift   # 报告服务
│   │   ├── TemplateService.swift # 模板服务
│   │   ├── FileService.swift     # 文件服务
│   │   └── ProcessingStages.swift # 处理阶段
│   ├── Utils/                    # 工具类
│   │   └── Constants.swift       # 常量定义
│   └── Resources/                # 资源文件
│       └── transcribe.py         # Python 转录脚本
├── mediamindTests/               # 单元测试
├── mediamindUITests/             # UI 测试
├── specs/                        # 规格文档
│   ├── requirements.md           # 需求规格
│   ├── design.md                 # 设计文档
│   └── tasks.md                  # 任务清单
├── steering/                     # 指导文档
│   ├── product.md                # 产品定位
│   ├── structure.md              # 架构设计
│   └── tech.md                   # 技术标准
└── README.md                     # 项目说明
```

### 技术栈

- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI (macOS 14+)
- **数据持久化**: SwiftData
- **异步处理**: Swift Concurrency (async/await)
- **语音识别**: mlx-whisper (Python)
- **LLM 集成**: Ollama / LM Studio
- **音视频处理**: FFmpeg

### 代码规范

- 遵循 Swift API 设计指南
- 使用 MVVM 架构模式
- 异步操作使用 `async/await`
- 错误处理使用 `throws` 和 `Result`

### 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 配置说明

### Whisper 模型选择

| 模型 | 大小 | 速度 | 准确度 | 推荐场景 |
|------|------|------|--------|----------|
| tiny | ~39MB | 最快 | 一般 | 快速测试 |
| base | ~74MB | 快 | 良好 | 日常使用 |
| small | ~244MB | 中等 | 很好 | 推荐 |
| medium | ~769MB | 慢 | 优秀 | 高精度需求 |
| large | ~1550MB | 最慢 | 最佳 | 专业场景 |

### LLM 模型推荐

- **Ollama**: llama3.2, qwen2.5, mistral
- **LM Studio**: 任何兼容 OpenAI API 格式的模型

### 音频处理选项

- **降噪**: 减少背景噪音，提高识别准确度
- **VAD**: 语音活动检测，自动去除静音段
- **说话人分离**: 识别不同说话人（实验性功能）
- **音量归一化**: 统一音量水平

---

## 常见问题

### Q: 处理速度很慢怎么办？

A:
1. 检查是否使用 Apple Silicon Mac
2. 尝试使用更小的 Whisper 模型（如 base）
3. 关闭不必要的音频处理选项
4. 确保 Ollama/LM Studio 服务正常运行

### Q: 转录准确度不高？

A:
1. 使用更大的 Whisper 模型（如 small 或 medium）
2. 启用音频降噪功能
3. 调整置信度阈值
4. 确保音频质量良好

### Q: LLM 分析失败？

A:
1. 检查 Ollama/LM Studio 服务是否运行
2. 确认模型已正确下载
3. 检查网络连接（首次下载模型需要）
4. 查看错误日志获取详细信息

### Q: 如何自定义报告模板？

A:
1. 在设置中配置模板目录
2. 创建 HTML 模板文件
3. 使用占位符（如 `请输入会议内容...`）标记内容区域
4. 在设置中选择对应的模板

---

## 社区与支持

- **问题反馈**: [GitHub Issues](https://github.com/RichardHsiang/mediamind/issues)
- **功能建议**: [GitHub Discussions](https://github.com/RichardHsiang/mediamind/discussions)

---

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 致谢

- [OpenAI Whisper](https://github.com/openai/whisper) - 语音识别模型
- [mlx-whisper](https://github.com/ml-explore/mlx-examples) - Apple Silicon 优化
- [Ollama](https://ollama.ai) - 本地 LLM 运行时
- [FFmpeg](https://ffmpeg.org) - 音视频处理工具
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Apple UI 框架

---

## 项目状态

- **版本**: 1.0.0
- **开发状态**: 活跃开发
- **最后更新**: 2026-05-25
- **兼容性**: macOS 14.6+

---

<div align="center">

**如果觉得 MediaMind 对你有帮助，请给个 Star 支持一下！**

Made with by MediaMind Team

</div>
