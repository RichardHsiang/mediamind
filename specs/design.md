# MediaMind 设计规格文档

## 1. 视觉设计系统

### 1.1 色彩系统
```swift
extension Color {
    static let appleBlue = Color("#007AFF")
    static let appleGreen = Color("#34C759")
    static let appleOrange = Color("#FF9500")
    static let applePurple = Color("#AF52DE")
    static let applePink = Color("#FF2D55")
    static let appleTeal = Color("#5AC8FA")
    static let appleYellow = Color("#FFCC00")
    static let appleGray = Color("#8E8E93")
    static let appleDark = Color("#1D1D1F")
    static let appleBackground = Color("#F5F5F7")
    static let appleCard = Color.white.opacity(0.85)
    static let appleBorder = Color("#D1D1D6")
}
```

### 1.2 字体系统
- 标题：系统字体，semibold，28-40pt
- 副标题：系统字体，regular，16-20pt
- 正文：系统字体，regular，13-15pt
- 标签：系统字体，medium，11-13pt

### 1.3 间距系统
- 页面内边距：24-32pt
- 卡片内边距：16-24pt
- 组件间距：12-16pt
- 元素间距：8-12pt

### 1.4 圆角系统
- 大卡片：20pt
- 小卡片/按钮：12pt
- 标签/徽章：8pt

## 2. 组件设计

### 2.1 Glass Card（玻璃卡片）
```swift
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(24)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.85))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 4)
    }
}
```

### 2.2 Option Card（选项卡片）
```swift
struct OptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let tags: [String]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Icon
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.gradient)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    // Checkmark
                    if isSelected {
                        Circle()
                            .fill(Color.appleBlue)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.appleGray)
                
                // Tags
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(iconColor.opacity(0.1))
                            .foregroundColor(iconColor)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.appleBlue : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: action)
    }
}
```

### 2.3 Upload Zone（上传区域）
```swift
struct UploadZone: View {
    @State private var isDragOver = false
    let onFileSelected: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.appleBlue)
            
            Text("拖拽文件到此处")
                .font(.system(size: 17, weight: .semibold))
            
            Text("或点击选择文件")
                .font(.system(size: 13))
                .foregroundColor(.appleGray)
            
            HStack(spacing: 16) {
                Label("MP3, WAV, M4A", systemImage: "music.note")
                Label("MP4, MOV, MKV", systemImage: "film")
            }
            .font(.system(size: 12))
            .foregroundColor(.appleGray)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(isDragOver ? Color.appleBlue.opacity(0.03) : Color.clear)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundColor(isDragOver ? .appleBlue : .appleBorder)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            // Handle drop
            return true
        }
    }
}
```

### 2.4 Progress Ring（进度环）
```swift
struct ProgressRing: View {
    let progress: Double
    let size: CGFloat = 80
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.appleBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 17, weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}
```

### 2.5 Step Indicator（步骤指示器）
```swift
struct StepIndicator: View {
    let step: ProcessingStep
    let status: StepStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(status.backgroundColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: status.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(step.rawValue)
                        .font(.system(size: 15, weight: .medium))
                    
                    Spacer()
                    
                    Text(status.description)
                        .font(.system(size: 13))
                        .foregroundColor(status.textColor)
                }
                
                // Progress bar
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(status.progressColor)
                                .frame(width: geo.size.width * status.progress)
                                , alignment: .leading
                        )
                }
                .frame(height: 4)
            }
        }
    }
}
```

## 3. 页面布局

### 3.1 主窗口布局
```
┌─────────────────────────────────────────────┐
│  Title Bar (macOS native)                   │
├──────────┬──────────────────────────────────┤
│          │                                  │
│ Sidebar  │         Main Content             │
│  (200px) │         (flexible)               │
│          │                                  │
│ - 主页    │  - Header Section               │
│ - 历史    │  - Upload Section               │
│          │  - Options Section              │
│ Settings │  - Action Button                │
│  (bottom)│  - Processing Section           │
│          │  - Results Section              │
│          │                                  │
└──────────┴──────────────────────────────────┘
```

### 3.2 设置面板布局
```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            WhisperSettingsView()
                .tabItem {
                    Label("Whisper", systemImage: "microphone")
                }
            
            AudioSettingsView()
                .tabItem {
                    Label("音频", systemImage: "slider.horizontal.3")
                }
            
            SubtitleSettingsView()
                .tabItem {
                    Label("字幕", systemImage: "captions.bubble")
                }
            
            LLMSettingsView()
                .tabItem {
                    Label("LLM", systemImage: "brain")
                }
            
            OutputSettingsView()
                .tabItem {
                    Label("输出", systemImage: "folder")
                }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
```

## 4. 动画设计

### 4.1 页面加载动画
```swift
// Slide up + fade in
.animation(.easeOut(duration: 0.5), value: isVisible)
.offset(y: isVisible ? 0 : 20)
.opacity(isVisible ? 1 : 0)
```

### 4.2 卡片悬停效果
```swift
// Lift + shadow
.scaleEffect(isHovered ? 1.02 : 1)
.shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.08), 
        radius: isHovered ? 32 : 24)
.animation(.easeInOut(duration: 0.3), value: isHovered)
```

### 4.3 选中状态动画
```swift
// Checkmark scale in
.transition(.scale.combined(with: .opacity))
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
```

### 4.4 进度环动画
```swift
// Smooth progress update
.animation(.easeInOut(duration: 0.5), value: progress)
```

## 5. 响应式设计

### 5.1 布局断点
```swift
enum LayoutBreakpoint {
    case compact    // < 800px
    case regular    // 800-1200px
    case wide       // > 1200px
}
```

### 5.2 选项卡片布局
```swift
// Compact: 1 column
// Regular: 2 columns
// Wide: 3 columns
LazyVGrid(columns: columns, spacing: 16) {
    ForEach(options) { option in
        OptionCard(...)
    }
}
```

## 6. 交互设计

### 6.1 文件上传流程
1. 用户拖拽/点击上传区域
2. 显示文件信息卡片
3. 激活选项选择
4. 选择选项后激活开始按钮
5. 点击开始，显示处理进度
6. 完成后显示结果

### 6.2 设置面板交互
1. 点击侧边栏设置按钮
2. 弹出设置窗口（Sheet/Window）
3. 使用 TabView 切换设置分类
4. 修改设置后自动保存
5. 提供恢复默认按钮

### 6.3 历史记录交互
1. 点击侧边栏历史记录
2. 显示任务列表
3. 点击任务查看详情
4. 支持保存/删除操作

## 7. 图标映射

| 功能 | SF Symbol |
|------|-----------|
| 主页 | house.fill |
| 历史记录 | clock.arrow.circlepath |
| 设置 | gear |
| 字幕生成 | captions.bubble.fill |
| 内容分析 | brain.head.profile |
| 会议报告 | doc.text.fill |
| 上传 | arrow.up.circle.fill |
| 文件 | doc.fill |
| 视频 | film.fill |
| 音频 | music.note |
| 完成 | checkmark.circle.fill |
| 处理中 | arrow.triangle.2.circlepath |
| 失败 | xmark.circle.fill |
| 下载 | arrow.down.circle |
| 预览 | eye.fill |
| 删除 | trash.fill |
| 保存 | square.and.arrow.down |
