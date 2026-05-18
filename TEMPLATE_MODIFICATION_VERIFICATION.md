# MediaMind 模板设置修改验证

## 修改内容

### 1. 删除所有内置模板选项
**文件**: [Constants.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Utils/Constants.swift#L173-184)

**修改前**:
```swift
enum ReportTemplate: String, CaseIterable {
    case meeting = "meeting"
    case project = "project"
    case training = "training"
    case interview = "interview"
    case custom = "custom"
    case dynamic = "dynamic"

    var displayName: String {
        switch self {
        case .meeting: return "会议纪要"
        case .project: return "项目汇报"
        case .training: return "培训总结"
        case .interview: return "访谈记录"
        case .custom: return "自定义模板"
        case .dynamic: return "自定义模板"
        }
    }
    
    static var builtInTemplates: [ReportTemplate] {
        [.meeting, .project, .training, .interview]
    }
}
```

**修改后**:
```swift
enum ReportTemplate: String, CaseIterable {
    case custom = "custom"
    case dynamic = "dynamic"

    var displayName: String {
        switch self {
        case .custom: return "自定义模板"
        case .dynamic: return "自定义模板"
        }
    }
    
    static var builtInTemplates: [ReportTemplate] {
        []  // 空数组，删除所有内置模板
    }
}
```

### 2. 设置界面修改
**文件**: [SettingsView.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Views/SettingsView.swift#L534-545)

**修改前**:
- 显示"内置模板"section，包含4个内置选项
- 显示"自定义模板"section，仅在有自定义模板时显示

**修改后**:
- 删除"内置模板"section
- 统一显示"可用模板"section
- 当没有模板时显示提示："暂无模板，请点击下方按钮上传"
- 更新帮助文本："点击\"上传模板\"将自定义 HTML 模板放入文件夹，默认模板已内置"

### 3. 自定义模板支持
**文件**: [ReportService.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Services/ReportService.swift#L55-85)

**新增功能**:
- 优先从模板目录加载自定义模板
- 如果找到 `meeting.html`，使用自定义模板
- 自动替换模板中的占位符：
  - `请输入会议内容...` → 实际会议内容
  - `placeholder="请输入会议主题..."` → 实际主题
  - `placeholder="请输入编号..."` → 实际编号
  - `placeholder="请输入会议时间..."` → 实际时间
  - `placeholder="请输入会议地点..."` → 实际地点
  - `placeholder="请输入参会人员..."` → 实际参会人员

### 4. 处理流程修改
**文件**: [ProcessingStages.swift](file:///Users/richardhsiang/Documents/obsidian仓库/trae/mediamind/mediamind/Services/ProcessingStages.swift#L218-229)

**修改内容**:
- 默认模板从 `.meeting` 改为 `.custom`
- 传递 `templatePath` 参数给报告生成服务

### 5. 默认模板安装
**位置**: `~/MediaMind/templates/meeting.html`

**操作**:
- 将 `/Users/richardhsiang/Documents/obsidian仓库/trae/会议记录模板.html` 复制到 `~/MediaMind/templates/meeting.html`
- 作为默认的会议纪要模板

## 功能验证

### 编译状态
✅ **BUILD SUCCEEDED** - 所有修改编译成功

### 模板文件
✅ **meeting.html** 已安装到 `~/MediaMind/templates/`

### 预期行为

#### 设置界面
1. 打开设置 → 报告模板设置
2. 模板选择器中不再显示内置模板选项
3. 显示"可用模板"section
4. 自动检测到 `meeting.html` 模板
5. 可以选择"meeting"模板

#### 报告生成
1. 上传视频文件
2. 选择"会议报告"输出类型
3. 系统自动使用 `~/MediaMind/templates/meeting.html` 作为模板
4. 生成的报告包含：
   - 原始模板的样式和布局
   - 自动填充的会议信息
   - AI生成的会议内容

#### 自定义模板上传
1. 点击"上传模板"按钮
2. 打开 `~/MediaMind/templates/` 文件夹
3. 用户可以添加更多自定义HTML模板
4. 新模板会自动出现在选择器中

## 技术细节

### 模板加载优先级
1. 首先尝试从自定义模板目录加载
2. 如果找到匹配的模板文件，使用自定义模板
3. 如果未找到，回退到内置生成逻辑

### 占位符替换机制
```swift
private func replaceTemplatePlaceholders(in template: String, with contentHTML: String, meetingInfo: MeetingInfo) -> String {
    var result = template
    
    // 替换内容占位符
    result = result.replacingOccurrences(of: "请输入会议内容...", with: contentHTML)
    
    // 替换会议信息占位符
    result = result.replacingOccurrences(of: "placeholder=\"请输入会议主题...\"", with: "value=\"\(escapeHTML(meetingInfo.theme))\"")
    // ... 其他占位符
    
    return result
}
```

### 模板文件要求
- 文件格式：HTML
- 文件位置：`~/MediaMind/templates/`
- 文件命名：`{模板名}.html`
- 必须包含占位符才能自动填充内容

## 注意事项

1. **模板兼容性**: 自定义模板需要包含特定的占位符才能正确填充内容
2. **默认模板**: `meeting.html` 作为默认模板已预安装
3. **扩展性**: 用户可以通过上传按钮添加更多自定义模板
4. **回退机制**: 如果自定义模板加载失败，系统会使用内置生成逻辑

## 后续优化建议

1. 支持更多占位符类型
2. 添加模板预览功能
3. 支持模板编辑器
4. 添加模板验证机制
5. 支持模板导入/导出