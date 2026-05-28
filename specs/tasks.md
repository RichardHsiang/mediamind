# MediaMind 开发任务清单

## 任务状态说明
- `[x]` 已完成
- `[ ]` 待开始
- `[~]` 进行中
- `[*]` 可选

---

## Phase 1: 项目基础架构

### Task 1: 创建项目目录结构
**Status**: `[ ]` / **Priority**: High / **Phase**: 1 / **Parallel Group**: A
**需求追溯**: _需求: 架构设计_
**Files**: 创建目录
- `mediamind/mediamind/Models/`
- `mediamind/mediamind/Views/`
- `mediamind/mediamind/ViewModels/`
- `mediamind/mediamind/Services/`
- `mediamind/mediamind/Utils/`

**Sub-steps**:
- [ ] Step 1.1: 在 Xcode 中创建 Group 目录结构
  **VALIDATION GATE**:
  - Type: FileCheck
  - Command: `ls -la <project_root>/mediamind/`
  - Expected: 包含 Models, Views, ViewModels, Services, Utils 目录
  - Pass Criteria: 所有目录存在
  - Fail Action: 重新创建缺失目录

- [ ] Step 1.2: 移动现有文件到正确位置
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `cd <project_root> && xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' clean build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 编译成功，无错误
  - Fail Action: 检查文件引用路径

### Task 2: 定义数据模型
**Status**: `[ ]` / **Priority**: High / **Phase**: 1 / **Parallel Group**: A
**需求追溯**: _需求: REQ-7.1, REQ-7.2_
**Files**:
- 创建: `mediamind/mediamind/Models/TaskItem.swift`
- 创建: `mediamind/mediamind/Models/AppSettings.swift`
- 修改: `mediamind/mediamind/Models/Item.swift` (删除或替换)

**Sub-steps**:
- [ ] Step 2.1: 创建 TaskItem 模型
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: SwiftData 模型编译通过
  - Fail Action: 检查 @Model 注解和属性类型

- [ ] Step 2.2: 创建 AppSettings 模型
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 设置模型编译通过
  - Fail Action: 检查属性默认值和类型

- [ ] Step 2.3: 更新 ModelContainer 配置
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 应用启动不崩溃
  - Fail Action: 检查 Schema 配置

### Task 3: 定义枚举和常量
**Status**: `[ ]` / **Priority**: High / **Phase**: 1 / **Parallel Group**: A
**需求追溯**: _需求: REQ-3.1, REQ-3.3_
**Files**:
- 创建: `mediamind/mediamind/Utils/Constants.swift`

**Sub-steps**:
- [ ] Step 3.1: 定义 TaskStatus 枚举
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 枚举定义正确
  - Fail Action: 检查 RawRepresentable 实现

- [ ] Step 3.2: 定义 OutputType 枚举
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 枚举定义正确
  - Fail Action: 检查关联值和计算属性

- [ ] Step 3.3: 定义 ProcessingStep 枚举
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 枚举定义正确
  - Fail Action: 检查步骤顺序和描述

---

## Phase 2: UI 组件开发

### Task 4: 创建基础 UI 组件
**Status**: `[ ]` / **Priority**: High / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-2.1, REQ-3.2, REQ-4.1_
**Files**:
- 创建: `mediamind/mediamind/Views/Components/GlassCard.swift`
- 创建: `mediamind/mediamind/Views/Components/ProgressRing.swift`
- 创建: `mediamind/mediamind/Views/Components/StepIndicator.swift`

**Sub-steps**:
- [ ] Step 4.1: 实现 GlassCard 组件
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 组件编译通过
  - Fail Action: 检查 ViewBuilder 和泛型用法

- [ ] Step 4.2: 实现 ProgressRing 组件
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 进度环动画正常
  - Fail Action: 检查 trim 和 rotationEffect

- [ ] Step 4.3: 实现 StepIndicator 组件
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 步骤指示器显示正确
  - Fail Action: 检查状态颜色和图标映射

### Task 5: 实现主界面布局
**Status**: `[ ]` / **Priority**: High / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-1.1, REQ-2.1, REQ-4.1, REQ-5.1_
**Files**:
- 创建: `mediamind/mediamind/Views/MainView.swift`
- 创建: `mediamind/mediamind/Views/SidebarView.swift`
- 修改: `mediamind/mediamind/ContentView.swift`

**Sub-steps**:
- [ ] Step 5.1: 实现 SidebarView
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行应用，检查侧边栏
  - Expected: 侧边栏显示主页、历史记录、设置导航项
  - Pass Criteria: 导航项可点击，选中状态正确
  - Fail Action: 检查 NavigationLink 和 selection

- [ ] Step 5.2: 实现主内容区域布局
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行应用，检查主内容区
  - Expected: 显示标题、上传区域、选项卡片
  - Pass Criteria: 布局正确，无重叠
  - Fail Action: 检查 ScrollView 和 VStack 布局

- [ ] Step 5.3: 更新 ContentView 为入口
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' build`
  - Expected: BUILD SUCCEEDED
  - Pass Criteria: 应用编译通过
  - Fail Action: 检查视图层级

### Task 6: 实现上传区域
**Status**: `[ ]` / **Priority**: High / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-1.1, REQ-1.2_
**Files**:
- 创建: `mediamind/mediamind/Views/UploadView.swift`

**Sub-steps**:
- [ ] Step 6.1: 实现拖拽上传区域
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行应用，拖拽文件到上传区域
  - Expected: 文件被接受，显示文件信息
  - Pass Criteria: 拖拽视觉反馈正确，文件信息准确
  - Fail Action: 检查 onDrop 修饰符和 UTType

- [ ] Step 6.2: 实现文件选择器
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 点击上传区域，选择文件
  - Expected: 文件选择器打开，选中文件后显示信息
  - Pass Criteria: 文件选择器正常工作
  - Fail Action: 检查 NSOpenPanel 调用

- [ ] Step 6.3: 实现文件信息展示
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 上传文件后查看文件卡片
  - Expected: 显示文件名、大小、类型图标
  - Pass Criteria: 信息准确，可删除
  - Fail Action: 检查文件元数据获取

### Task 7: 实现选项选择区域
**Status**: `[ ]` / **Priority**: High / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-2.1, REQ-2.2_
**Files**:
- 创建: `mediamind/mediamind/Views/OptionsView.swift`

**Sub-steps**:
- [ ] Step 7.1: 实现三个选项卡片
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行应用，查看选项卡片
  - Expected: 三个卡片正确显示，颜色和图标正确
  - Pass Criteria: 布局正确，信息完整
  - Fail Action: 检查 LazyVGrid 配置

- [ ] Step 7.2: 实现互斥选择逻辑
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 点击不同选项卡片
  - Expected: 只能选中一个，选中状态正确
  - Pass Criteria: 互斥逻辑正常，动画流畅
  - Fail Action: 检查 @State 和 onTapGesture

### Task 8: 实现处理进度界面
**Status**: `[ ]` / **Priority**: High / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-3.2, REQ-3.3_
**Files**:
- 创建: `mediamind/mediamind/Views/ProcessingView.swift`

**Sub-steps**:
- [ ] Step 8.1: 实现进度环和步骤列表
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行应用，开始处理任务
  - Expected: 显示进度环和步骤状态
  - Pass Criteria: 进度更新正确，步骤状态变化正常
  - Fail Action: 检查进度绑定和状态更新

### Task 9: 实现结果展示界面
**Status**: `[ ]` / **Priority**: High / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-4.1, REQ-4.2_
**Files**:
- 创建: `mediamind/mediamind/Views/ResultsView.swift`

**Sub-steps**:
- [ ] Step 9.1: 实现结果卡片列表
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 处理完成后查看结果
  - Expected: 显示输出文件卡片
  - Pass Criteria: 文件信息正确，可预览下载
  - Fail Action: 检查文件路径和元数据

### Task 10: 实现历史记录界面
**Status**: `[ ]` / **Priority**: Medium / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-5.1, REQ-5.2_
**Files**:
- 创建: `mediamind/mediamind/Views/HistoryView.swift`

**Sub-steps**:
- [ ] Step 10.1: 实现历史列表
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 查看历史记录页面
  - Expected: 显示历史任务列表
  - Pass Criteria: 任务信息正确，状态标签正确
  - Fail Action: 检查 SwiftData 查询

### Task 11: 实现设置界面
**Status**: `[ ]` / **Priority**: Medium / **Phase**: 2 / **Parallel Group**: B
**需求追溯**: _需求: REQ-6.1-REQ-6.7_
**Files**:
- 创建: `mediamind/mediamind/Views/SettingsView.swift`

**Sub-steps**:
- [ ] Step 11.1: 实现设置面板布局
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 打开设置面板
  - Expected: 显示分类 Tab 和设置项
  - Pass Criteria: 布局正确，可滚动
  - Fail Action: 检查 TabView 和 Form 布局

- [ ] Step 11.2: 实现设置持久化
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 修改设置，重启应用
  - Expected: 设置值保持
  - Pass Criteria: 持久化正常工作
  - Fail Action: 检查 SwiftData 保存

---

## Phase 3: 业务逻辑开发

### Task 12: 实现 TaskManager
**Status**: `[ ]` / **Priority**: High / **Phase**: 3 / **Parallel Group**: C
**需求追溯**: _需求: REQ-1.3, REQ-3.3_
**Files**:
- 创建: `mediamind/mediamind/ViewModels/TaskViewModel.swift`

**Sub-steps**:
- [ ] Step 12.1: 实现任务创建和状态管理
  **VALIDATION GATE**:
  - Type: Unit Test
  - Command: `xcodebuild test -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS'`
  - Expected: 测试通过
  - Pass Criteria: 任务状态流转正确
  - Fail Action: 检查状态机逻辑

- [ ] Step 12.2: 实现处理流程编排
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行完整处理流程
  - Expected: 步骤按顺序执行，状态正确更新
  - Pass Criteria: 流程完整执行
  - Fail Action: 检查异步任务编排

### Task 13: 实现 FileService
**Status**: `[ ]` / **Priority**: High / **Phase**: 3 / **Parallel Group**: C
**需求追溯**: _需求: REQ-1.2, REQ-1.3_
**Files**:
- 创建: `mediamind/mediamind/Services/FileService.swift`

**Sub-steps**:
- [ ] Step 13.1: 实现文件校验
  **VALIDATION GATE**:
  - Type: Unit Test
  - Command: `xcodebuild test -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS'`
  - Expected: 测试通过
  - Pass Criteria: 各种文件类型校验正确
  - Fail Action: 检查文件扩展名和大小判断

- [ ] Step 13.2: 实现临时文件管理
  **VALIDATION GATE**:
  - Type: Unit Test
  - Command: `xcodebuild test -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS'`
  - Expected: 测试通过
  - Pass Criteria: 临时文件创建和清理正常
  - Fail Action: 检查 FileManager 操作

### Task 14: 实现 FFmpegService
**Status**: `[ ]` / **Priority**: High / **Phase**: 3 / **Parallel Group**: C
**需求追溯**: _需求: REQ-1.2 (视频音频提取)_
**Files**:
- 创建: `mediamind/mediamind/Services/FFmpegService.swift`

**Sub-steps**:
- [ ] Step 14.1: 实现音频提取
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 上传视频文件，检查音频提取
  - Expected: 成功提取音频为 WAV 格式
  - Pass Criteria: 音频文件生成，格式正确
  - Fail Action: 检查 FFmpeg 命令和路径

- [ ] Step 14.2: 实现视频信息获取
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 上传视频文件，查看信息
  - Expected: 获取时长、分辨率等信息
  - Pass Criteria: 信息准确
  - Fail Action: 检查 ffprobe 输出解析

### Task 15: 实现 WhisperService (Mock)
**Status**: `[ ]` / **Priority**: High / **Phase**: 3 / **Parallel Group**: C
**需求追溯**: _需求: REQ-3.1 (转录步骤)_
**Files**:
- 创建: `mediamind/mediamind/Services/WhisperService.swift`

**Sub-steps**:
- [ ] Step 15.1: 实现 Mock 转录服务
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行处理流程
  - Expected: 转录步骤执行，生成模拟结果
  - Pass Criteria: 步骤完成，结果文件生成
  - Fail Action: 检查模拟数据生成

### Task 16: 实现 LLMService (Mock)
**Status**: `[ ]` / **Priority**: Medium / **Phase**: 3 / **Parallel Group**: C
**需求追溯**: _需求: REQ-3.1 (分析步骤)_
**Files**:
- 创建: `mediamind/mediamind/Services/LLMService.swift`

**Sub-steps**:
- [ ] Step 16.1: 实现 Mock LLM 服务
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行分析流程
  - Expected: 分析步骤执行，生成模拟结果
  - Pass Criteria: 步骤完成，结果文件生成
  - Fail Action: 检查模拟数据生成

---

## Phase 4: 集成与验证

### Task 17: 集成测试
**Status**: `[ ]` / **Priority**: High / **Phase**: 4 / **Parallel Group**: D
**需求追溯**: _需求: 全部_
**Files**: 无新文件

**Sub-steps**:
- [ ] Step 17.1: 完整流程测试
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 上传文件 → 选择选项 → 开始处理 → 查看结果
  - Expected: 完整流程无错误
  - Pass Criteria: 所有步骤正常执行，结果正确
  - Fail Action: 检查日志和错误信息

- [ ] Step 17.2: 边界情况测试
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 测试大文件、空文件、不支持格式
  - Expected: 正确处理边界情况
  - Pass Criteria: 错误提示明确，不崩溃
  - Fail Action: 检查错误处理逻辑

### Task 18: UI  polish
**Status**: `[ ]` / **Priority**: Medium / **Phase**: 4 / **Parallel Group**: D
**需求追溯**: _需求: 设计规范_
**Files**: 修改现有 View 文件

**Sub-steps**:
- [ ] Step 18.1: 动画和过渡效果
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 运行应用，检查动画
  - Expected: 动画流畅，无卡顿
  - Pass Criteria: 60fps 动画
  - Fail Action: 优化动画性能

- [ ] Step 18.2: 暗色模式支持
  **VALIDATION GATE**:
  - Type: Manual
  - Command: 切换系统暗色模式
  - Expected: 应用适配暗色模式
  - Pass Criteria: 颜色对比度正确
  - Fail Action: 检查 Color 适配

### Task 19: 最终构建验证
**Status**: `[ ]` / **Priority**: High / **Phase**: 4 / **Parallel Group**: D
**需求追溯**: _需求: 全部_
**Files**: 无

**Sub-steps**:
- [ ] Step 19.1: 编译验证
  **VALIDATION GATE**:
  - Type: Compilation
  - Command: `xcodebuild -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS' clean build`
  - Expected: BUILD SUCCEEDED，无警告
  - Pass Criteria: 编译成功
  - Fail Action: 修复编译错误

- [ ] Step 19.2: 单元测试验证
  **VALIDATION GATE**:
  - Type: Unit Test
  - Command: `xcodebuild test -project mediamind.xcodeproj -scheme mediamind -destination 'platform=macOS'`
  - Expected: 所有测试通过
  - Pass Criteria: 测试覆盖率 > 60%
  - Fail Action: 修复失败测试

---

## Checkpoint: Phase 边界验证

### Phase 1 完成检查点
- [ ] 项目目录结构正确
- [ ] 数据模型编译通过
- [ ] 应用能正常启动

### Phase 2 完成检查点
- [ ] 所有 UI 组件正常显示
- [ ] 交互逻辑正确
- [ ] 设置持久化正常

### Phase 3 完成检查点
- [ ] 服务层逻辑正确
- [ ] Mock 数据生成正常
- [ ] 处理流程可执行

### Phase 4 完成检查点
- [ ] 完整流程测试通过
- [ ] 编译无错误无警告
- [ ] 单元测试全部通过
