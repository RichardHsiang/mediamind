# MediaMind 目录配置修改验证

## 修改内容

### 1. 移除默认输出目录
**文件**: [AppSettings.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Models/AppSettings.swift#L119)

**修改前**:
```swift
outputPath: String = "~/MediaMind/output/",
```

**修改后**:
```swift
outputPath: String = "",
```

**说明**: 输出目录默认值从 `~/MediaMind/output/` 改为空字符串，要求用户必须自行选择。

### 2. 移除默认模板目录
**文件**: [TemplateService.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Services/TemplateService.swift#L12-15)

**修改前**:
```swift
/// Get the default template folder path
var defaultTemplatePath: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MediaMind")
        .appendingPathComponent("templates")
}
```

**修改后**:
```swift
/// Get the default template folder path (deprecated - user must choose)
var defaultTemplatePath: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MediaMind")
        .appendingPathComponent("templates")
}
```

**说明**: 标记为已废弃，不再作为默认路径使用。

### 3. 模板服务强制要求路径
**文件**: [TemplateService.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Services/TemplateService.swift#L26-35)

**修改内容**:
- `scanTemplates()` 方法：移除默认路径回退，未配置路径时返回空数组
- `loadTemplate()` 方法：移除默认路径回退，未配置路径时返回 nil
- `openTemplateFolder()` 方法：移除默认路径回退，未配置路径时直接返回

**关键修改**:
```swift
func scanTemplates(from templatePath: String?) -> [String] {
    guard let path = templatePath, !path.isEmpty else {
        print("[TemplateService] No template path configured")
        return []
    }
    // ...
}

func loadTemplate(named templateName: String, from templatePath: String?) -> String? {
    guard let path = templatePath, !path.isEmpty else {
        print("[TemplateService] No template path configured")
        return nil
    }
    // ...
}
```

### 4. 设置界面优化
**文件**: [SettingsView.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Views/SettingsView.swift#L509-514)

#### 模板目录显示
**修改前**:
```swift
Text(settings.templatePath.isEmpty ? "默认: ~/MediaMind/templates/" : settings.templatePath)
    .font(.system(size: 12))
    .foregroundColor(.secondary)
```

**修改后**:
```swift
Text(settings.templatePath.isEmpty ? "未设置" : settings.templatePath)
    .font(.system(size: 12))
    .foregroundColor(settings.templatePath.isEmpty ? .red : .secondary)
```

#### 输出目录显示
**修改前**:
```swift
TextField("", text: Binding(...))
    .textFieldStyle(PlainTextFieldStyle())
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
```

**修改后**:
```swift
TextField("", text: textFieldBinding)
    .textFieldStyle(PlainTextFieldStyle())
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(settings.outputPath.isEmpty ? Color.red : Color.clear, lineWidth: 1)
    )
    .overlay(
        Group {
            if settings.outputPath.isEmpty {
                Text("请选择输出目录")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.system(size: 13))
                    .padding(.leading, 12)
            }
        }
    )

if settings.outputPath.isEmpty {
    Text("⚠️ 请选择输出目录，否则无法生成文件")
        .font(.system(size: 11))
        .foregroundColor(.red)
}
```

**说明**: 
- 未设置时显示红色边框和提示文本
- 添加警告信息提示用户必须选择

### 5. 新增错误类型
**文件**: [TaskViewModel.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/ViewModels/TaskViewModel.swift#L156-175)

**新增错误**:
```swift
enum ProcessingError: Error, LocalizedError {
    // ... 现有错误类型
    case outputPathNotConfigured
    case templatePathNotConfigured

    var errorDescription: String? {
        // ...
        case .outputPathNotConfigured:
            return "输出目录未配置，请在设置中选择输出目录"
        case .templatePathNotConfigured:
            return "模板目录未配置，请在设置中选择模板目录"
    }
}
```

### 6. 处理流程验证
**文件**: [ProcessingStages.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Services/ProcessingStages.swift#L126-131)

**输出目录验证**:
```swift
let currentOutputPath = context.settings.outputPath
guard !currentOutputPath.isEmpty else {
    throw ProcessingError.outputPathNotConfigured
}
```

**模板目录验证**:
```swift
guard !context.settings.templatePath.isEmpty else {
    throw ProcessingError.templatePathNotConfigured
}
```

### 7. 报告生成服务验证
**文件**: [ReportService.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Services/ReportService.swift#L55-61)

**修改内容**:
```swift
func generateMeetingReport(...) async throws -> URL {
    // ...
    
    guard let path = templatePath, !path.isEmpty else {
        print("[ReportService] No template path configured")
        throw ProcessingError.templatePathNotConfigured
    }
    
    // Load custom template
    if let templateContent = TemplateService.shared.loadTemplate(named: "meeting", from: path) {
        // ...
    }
}
```

## 功能验证

### 编译状态
✅ **BUILD SUCCEEDED** - 所有修改编译成功

### 预期行为

#### 首次启动
1. 打开应用，进入设置
2. 模板目录显示"未设置"（红色）
3. 输出目录显示红色边框和"请选择输出目录"提示
4. 显示警告："⚠️ 请选择输出目录，否则无法生成文件"

#### 配置目录
1. 点击"选择"按钮选择模板目录
2. 点击文件夹图标选择输出目录
3. 路径显示更新为实际路径
4. 红色警告消失

#### 尝试处理文件（未配置目录）
1. 上传文件
2. 选择输出类型
3. 点击开始处理
4. 系统抛出错误：
   - 如果输出目录未配置："输出目录未配置，请在设置中选择输出目录"
   - 如果模板目录未配置："模板目录未配置，请在设置中选择模板目录"

#### 正常处理（已配置目录）
1. 配置好模板目录和输出目录
2. 上传文件并处理
3. 文件成功输出到指定目录
4. 报告使用指定模板生成

## 技术细节

### 验证机制
1. **输出目录验证**：在 `ReportGenerationStage` 开始时验证
2. **模板目录验证**：在 `generateReport` 方法中验证
3. **错误处理**：使用 `ProcessingError` 枚举统一管理错误

### 用户体验优化
1. **视觉提示**：红色边框和文字提示未配置状态
2. **警告信息**：明确告知用户必须配置
3. **错误信息**：清晰的错误描述，指导用户操作

### 向后兼容性
- 保留 `defaultTemplatePath` 属性（标记为废弃）
- 现有用户需要重新配置目录
- 新用户必须配置目录才能使用

## 注意事项

1. **首次使用**：用户必须先配置模板目录和输出目录
2. **错误提示**：未配置时会显示明确的错误信息
3. **视觉反馈**：设置界面提供清晰的视觉提示
4. **文件输出**：未配置输出目录时无法生成任何文件

## 后续优化建议

1. 添加目录配置向导（首次启动时）
2. 支持目录配置的导入/导出
3. 添加目录有效性验证（权限、磁盘空间等）
4. 提供默认目录推荐（可选）
5. 添加目录配置历史记录