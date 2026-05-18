import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit // Needed for NSOpenPanel used in folder pickers

struct SettingsView: View {
    @Query private var settingsList: [AppSettings]
    @Environment(\.modelContext) private var modelContext
    @State private var showSaveSuccess = false
    @State private var showFolderPicker = false
    @State private var showModelPathPicker = false
    
    // Dynamic model lists
    @State private var whisperModels: [String] = []
    @State private var llmModels: [String] = []
    @State private var isLoadingModels = true
    @State private var isLoadingLLMModels = false
    @State private var showLLMErrorAlert = false
    @State private var llmErrorMessage = ""
    @State private var showDebugInfo = false
    
    // Template scanning
    @State private var customTemplates: [CustomTemplateOption] = []
    @State private var isLoadingTemplates = true
    
    var settings: AppSettings {
        settingsList.first ?? AppSettings()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                 HStack(spacing: 16) {
                     RoundedRectangle(cornerRadius: 12)
                         .fill(
                             LinearGradient(
                                 colors: [.appleBlue, .applePurple],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing
                             )
                         )
                         .frame(width: 48, height: 48)
                         .overlay(
                             Image(systemName: "gearshape.fill")
                                 .font(.system(size: 24))
                                 .foregroundColor(.white)
                         )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统设置")
                            .font(.system(size: 24, weight: .semibold))
                        
                        Text("配置处理参数与输出选项")
                            .font(.system(size: 14))
                            .foregroundColor(.appleGray)
                    }
                    
                    Spacer()
                    
                    if showSaveSuccess {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("已保存")
                                .font(.system(size: 13))
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                    }
                }
                
                // Loading indicator
                if isLoadingModels {
                    HStack {
                        Spacer()
                        ProgressView("正在加载模型列表...")
                            .padding()
                        Spacer()
                    }
                }
                
                // Whisper Settings
                settingsSection(title: "Whisper 模型设置", icon: "microphone.fill", color: .appleBlue) {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("模型选择")
                                    .font(.system(size: 14, weight: .medium))
                                
                                if isLoadingModels {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else if whisperModels.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12))
                                            Text("未检测到模型")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.orange)
                                        }
                                        
                                        Text("可能的原因：")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("• 路径不正确或不存在")
                                            Text("• 路径下没有受支持的模型文件")
                                            Text("• 文件权限不足")
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        
                                        Text("请尝试：")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("1. 点击右侧文件夹图标重新选择路径")
                                            Text("2. 确认该路径下包含 .bin/.pt/.safetensors/.onnx 文件")
                                            Text("3. 检查文件读取权限")
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        
                                        Text("支持格式: .bin, .pt, .safetensors, .onnx, 目录形式")
                                            .font(.system(size: 9))
                                            .padding(4)
                                            .background(Color.blue.opacity(0.05))
                                            .cornerRadius(4)
                                    }
                                    .padding(8)
                                    .background(Color.orange.opacity(0.05))
                                    .cornerRadius(6)
                                } else {
                                    Picker("", selection: Binding(
                                        get: { settings.whisperModel },
                                        set: {
                                            settings.whisperModel = $0
                                            autoSave()
                                        }
                                    )) {
                                        ForEach(whisperModels, id: \.self) { model in
                                            Text(model == "auto" ? "自动选择" : model).tag(model)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("模型存储路径")
                                    .font(.system(size: 14, weight: .medium))
                                
                                HStack {
                                    TextField("", text: Binding(
                                        get: { settings.modelPath },
                                        set: {
                                            settings.modelPath = $0
                                            autoSave()
                                        }
                                    ))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    
                                    Button(action: pickModelPath) {
                                        Image(systemName: "folder")
                                            .foregroundColor(.primary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("语音识别置信度阈值")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Spacer()
                                
                                Text("\(Int(settings.confidenceThreshold * 100))%")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appleBlue)
                            }
                            
                            Text("低于此阈值的转录结果将被标记为低置信度，可能需要进行人工校对")
                                .font(.system(size: 12))
                                .foregroundColor(.appleGray)
                            
                            Slider(
                                value: Binding(
                                    get: { settings.confidenceThreshold },
                                    set: {
                                        settings.confidenceThreshold = $0
                                        autoSave()
                                    }
                                ),
                                in: 0...1
                            )
                            .accentColor(.appleBlue)
                            
                            HStack(spacing: 8) {
                                Button("默认 (80%)") {
                                    settings.confidenceThreshold = 0.8
                                    autoSave()
                                }
                                .font(.system(size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(settings.confidenceThreshold == 0.8 ? Color.appleBlue : Color.gray.opacity(0.1))
                                .foregroundColor(settings.confidenceThreshold == 0.8 ? .white : .primary)
                                .cornerRadius(6)
                                .buttonStyle(PlainButtonStyle())
                                
                                Button("宽松 (60%)") {
                                    settings.confidenceThreshold = 0.6
                                    autoSave()
                                }
                                .font(.system(size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(settings.confidenceThreshold == 0.6 ? Color.appleBlue : Color.gray.opacity(0.1))
                                .foregroundColor(settings.confidenceThreshold == 0.6 ? .white : .primary)
                                .cornerRadius(6)
                                .buttonStyle(PlainButtonStyle())
                                
                                Button("严格 (90%)") {
                                    settings.confidenceThreshold = 0.9
                                    autoSave()
                                }
                                .font(.system(size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(settings.confidenceThreshold == 0.9 ? Color.appleBlue : Color.gray.opacity(0.1))
                                .foregroundColor(settings.confidenceThreshold == 0.9 ? .white : .primary)
                                .cornerRadius(6)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                // Audio Settings
                settingsSection(title: "音频处理设置", icon: "slider.horizontal.3", color: .appleGreen) {
                    VStack(spacing: 16) {
                        ToggleRow(
                            title: "启用降噪",
                            description: "对音频进行降噪处理",
                            isOn: Binding(
                                get: { settings.enableDenoise },
                                set: {
                                    settings.enableDenoise = $0
                                    autoSave()
                                }
                            )
                        )
                        
                        ToggleRow(
                            title: "语音活动检测 (VAD)",
                            description: "识别语音片段和非语音片段",
                            isOn: Binding(
                                get: { settings.enableVAD },
                                set: {
                                    settings.enableVAD = $0
                                    autoSave()
                                }
                            )
                        )
                        
                        ToggleRow(
                            title: "说话人分离",
                            description: "区分不同说话人",
                            isOn: Binding(
                                get: { settings.enableSpeakerDiarization },
                                set: {
                                    settings.enableSpeakerDiarization = $0
                                    autoSave()
                                }
                            )
                        )
                        
                        ToggleRow(
                            title: "音量归一化",
                            description: "统一音频音量",
                            isOn: Binding(
                                get: { settings.enableVolumeNormalize },
                                set: {
                                    settings.enableVolumeNormalize = $0
                                    autoSave()
                                }
                            )
                        )
                    }
                }
                
                // Subtitle Settings
                settingsSection(title: "字幕生成设置", icon: "captions.bubble", color: .appleOrange) {
                    VStack(spacing: 16) {
                        ToggleRow(
                            title: "生成双语字幕",
                            description: "同时生成原始语言和目标语言字幕",
                            isOn: Binding(
                                get: { settings.enableBilingualSubtitle },
                                set: {
                                    settings.enableBilingualSubtitle = $0
                                    autoSave()
                                }
                            )
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("字幕语言顺序")
                                .font(.system(size: 14, weight: .medium))
                            
                            Picker("", selection: Binding(
                                get: { settings.subtitleLanguageOrder },
                                set: {
                                    settings.subtitleLanguageOrder = $0
                                    autoSave()
                                }
                            )) {
                                ForEach(0..<AppConstants.subtitleOrders.count, id: \.self) { index in
                                    Text(AppConstants.subtitleOrderDisplayNames[index])
                                        .tag(AppConstants.subtitleOrders[index])
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("字幕格式")
                                .font(.system(size: 14, weight: .medium))
                            
                            HStack(spacing: 16) {
                                ForEach(["SRT", "VTT", "ASS"], id: \.self) { format in
                                    FormatCheckbox(
                                        title: format,
                                        isSelected: settings.subtitleFormats.contains(format)
                                    ) {
                                        toggleSubtitleFormat(format)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // LLM Settings
                settingsSection(title: "LLM 设置", icon: "brain.head.profile", color: .applePurple) {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LLM 服务")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Picker("", selection: Binding(
                                    get: { settings.llmService },
                                    set: {
                                        settings.llmService = $0
                                        if let service = LLMServiceType(rawValue: $0) {
                                            settings.llmBaseURL = service.defaultBaseURL
                                        }
                                        autoSave()
                                        // Refresh LLM models when service changes
                                        Task { await loadLLMModels() }
                                    }
                                )) {
                                    ForEach(LLMServiceType.allCases, id: \.self) { service in
                                        Text(service.displayName).tag(service.rawValue)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("模型名称")
                                    .font(.system(size: 14, weight: .medium))

                                if isLoadingLLMModels {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("正在加载模型列表...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                } else if showLLMErrorAlert && llmModels.isEmpty {
                                    llmErrorDetailView(errorMessage: llmErrorMessage)
                                } else if llmModels.isEmpty {
                                    llmEmptyStateView()
                                } else {
                                    Picker("", selection: Binding(
                                        get: { settings.llmModel },
                                        set: {
                                            settings.llmModel = $0
                                            autoSave()
                                        }
                                    )) {
                                        ForEach(llmModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("服务地址")
                                .font(.system(size: 14, weight: .medium))
                            
                            TextField("", text: Binding(
                                get: { settings.llmBaseURL },
                                set: {
                                    settings.llmBaseURL = $0
                                    autoSave()
                                }
                            ))
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            Text("Ollama 默认: http://127.0.0.1:11434 | LM Studio 默认: http://127.0.0.1:1234/v1")
                                .font(.system(size: 12))
                                .foregroundColor(.appleGray)
                        }
                    }
                }

                // Service Health Check
                ServiceHealthPanel()

                // Analysis Prompt
                settingsSection(title: "内容解析与摘要提示词", icon: "brain.head.profile", color: .appleGreen) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("自定义AI分析时使用的提示词模板，控制输出内容的结构和重点")
                            .font(.system(size: 13))
                            .foregroundColor(.appleGray)
                        
                         TextEditor(text: Binding(
                             get: { settings.analysisPrompt },
                             set: {
                                 settings.analysisPrompt = $0
                                 autoSave()
                             }
                         ))
                         .font(.system(size: 13))
                         .frame(minHeight: 200)
                         .padding(8)
                         .background(Color.white)
                         .cornerRadius(8)
                         .overlay(
                             RoundedRectangle(cornerRadius: 8)
                                 .stroke(Color.gray, lineWidth: 1)
                         )
                        
                        HStack(spacing: 12) {
                            Button("恢复默认") {
                                settings.analysisPrompt = AppSettings.defaultAnalysisPrompt
                                autoSave()
                            }
                            .font(.system(size: 14))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                }
                
                 // Report Template
                 settingsSection(title: "报告模板设置", icon: "doc.text", color: .applePink) {
                     VStack(alignment: .leading, spacing: 12) {
                         // Template folder path
                         HStack {
                             Text("模板目录")
                                 .font(.system(size: 14, weight: .medium))
                             
                             Spacer()
                             
                             Button(action: pickTemplateFolder) {
                                 HStack(spacing: 4) {
                                     Image(systemName: "folder")
                                     Text("选择")
                                 }
                                 .font(.system(size: 12))
                             }
                             .buttonStyle(.bordered)
                         }
                         
                         // Show current template path
                         Text(settings.templatePath.isEmpty ? "未设置" : settings.templatePath)
                             .font(.system(size: 12))
                             .foregroundColor(settings.templatePath.isEmpty ? .red : .secondary)
                             .lineLimit(1)
                             .truncationMode(.middle)
                         
                         Divider()
                         
                         // Template picker row
                         HStack(alignment: .center, spacing: 12) {
                             VStack(alignment: .leading, spacing: 4) {
                                 Text("选择模板")
                                     .font(.system(size: 14, weight: .medium))
                                 
                                 if isLoadingTemplates {
                                     ProgressView()
                                         .scaleEffect(0.8)
                                 } else {
                                     Picker("", selection: Binding(
                                         get: { settings.uploadTemplate },
                                         set: {
                                             settings.uploadTemplate = $0
                                             autoSave()
                                         }
                                     )) {
                                         // Custom templates only
                                         if !customTemplates.isEmpty {
                                             Section("可用模板") {
                                                 ForEach(customTemplates) { template in
                                                     Text(template.name).tag(template.id)
                                                 }
                                             }
                                         } else {
                                             Section("可用模板") {
                                                 Text("暂无模板，请点击下方按钮上传").tag("")
                                             }
                                         }
                                     }
                                     .pickerStyle(MenuPickerStyle())
                                 }
                             }
                             
                             Spacer()
                             
                             // Upload template button
                             Button(action: openUploadTemplateFolder) {
                                 VStack(spacing: 4) {
                                     Image(systemName: "arrow.up.doc")
                                         .font(.system(size: 20))
                                     Text("上传模板")
                                         .font(.system(size: 11))
                                 }
                                 .foregroundColor(.applePink)
                             }
                             .buttonStyle(.plain)
                         }
                         
                         // Help text
                         if customTemplates.isEmpty {
                             Text("点击\"上传模板\"将自定义 HTML 模板放入文件夹，默认模板已内置")
                                 .font(.system(size: 11))
                                 .foregroundColor(.secondary)
                         }
                      
                          // Meeting Prompt Editor
                          VStack(alignment: .leading, spacing: 12) {
                              HStack {
                                  Text("会议纪要提示词")
                                      .font(.system(size: 14, weight: .medium))

                                  Spacer()

                                  Button("恢复默认") {
                                      settings.meetingPrompt = AppSettings.defaultMeetingPrompt
                                      autoSave()
                                  }
                                  .font(.system(size: 12))
                                  .padding(.horizontal, 12)
                                  .padding(.vertical, 6)
                                  .background(Color.gray.opacity(0.1))
                                  .cornerRadius(6)
                                  .buttonStyle(PlainButtonStyle())
                              }

                              Text("自定义会议纪要生成时使用的提示词，控制输出内容的写作规范和风格")
                                  .font(.system(size: 12))
                                  .foregroundColor(.appleGray)

                              TextEditor(text: Binding(
                                  get: { settings.meetingPrompt },
                                  set: {
                                      settings.meetingPrompt = $0
                                      autoSave()
                                  }
                              ))
                              .font(.system(size: 13))
                              .frame(minHeight: 150)
                              .padding(8)
                              .background(Color.white)
                              .cornerRadius(8)
                              .overlay(
                                  RoundedRectangle(cornerRadius: 8)
                                      .stroke(Color.gray, lineWidth: 1)
                              )
                          }
                      }
                  }

                // Output Settings
                settingsSection(title: "输出设置", icon: "folder", color: .appleTeal) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("输出目录")
                                .font(.system(size: 14, weight: .medium))
                            
                            HStack {
                                let textFieldBinding = Binding(
                                    get: { settings.outputPath },
                                    set: {
                                        settings.outputPath = $0
                                        autoSave()
                                    }
                                )
                                
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
                                
                                Button(action: pickOutputFolder) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if settings.outputPath.isEmpty {
                                Text("⚠️ 请选择输出目录，否则无法生成文件")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        ToggleRow(
                            title: "提取关键截图",
                            description: "从视频中提取关键帧",
                            isOn: Binding(
                                get: { settings.enableScreenshots },
                                set: {
                                    settings.enableScreenshots = $0
                                    autoSave()
                                }
                            )
                        )
                        
                        ToggleRow(
                            title: "自动清理临时文件",
                            description: "处理完成后删除中间文件",
                            isOn: Binding(
                                get: { settings.autoCleanup },
                                set: {
                                    settings.autoCleanup = $0
                                    autoSave()
                                }
                            )
                        )
                    }
                }
                
                // Debug Info Panel
                DisclosureGroup(isExpanded: $showDebugInfo) {
                    debugInfoContent()
                } label: {
                    HStack {
                        Image(systemName: "laptopcomputer")
                        Text("调试信息")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: showDebugInfo ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
                .padding(.horizontal)
                
                // Save Button
                HStack {
                    Spacer()
                    
                    Button("保存设置") {
                        saveSettings()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appleBlue)
                    .cornerRadius(10)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(40)
        }
        .background(Color.appleBackground)
        .onAppear {
            Task {
                await loadModels()
                scanTemplates()
            }
        }
    }
    
    // MARK: - Model Loading

    @MainActor
    private func loadModels() async {
        isLoadingModels = true
        print("[SettingsView] ========== Loading models ==========")

        let discoveredWhisperModels = await ModelDiscoveryService.shared.getWhisperModels(modelPath: settings.modelPath)
        whisperModels = ["auto"] + discoveredWhisperModels
        print("[SettingsView] Whisper models loaded: \(discoveredWhisperModels.count)")

        await loadLLMModels()
        print("[SettingsView] ========== Done loading models ==========")

        isLoadingModels = false
    }

    @MainActor
    private func loadLLMModels() async {
        isLoadingLLMModels = true
        llmModels = []
        showLLMErrorAlert = false
        llmErrorMessage = ""

        defer {
            isLoadingLLMModels = false
        }

        let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
        print("[SettingsView] Loading LLM models for service: \(serviceType.rawValue) (rawValue from settings: '\(settings.llmService)')")

        switch serviceType {
        case .ollama:
            print("[SettingsView] Attempting to load Ollama models...")
            do {
                let models = try await ModelDiscoveryService.shared.getOllamaModels(forceRefresh: true)
                print("[SettingsView] Ollama returned \(models.count) models: \(models)")
                llmModels = models

                if models.isEmpty {
                    showLLMErrorAlert = true
                    llmErrorMessage = "未检测到 Ollama 模型\n\n请确认：\n• Ollama 服务已运行（执行 `ollama serve`）\n• 至少安装了一个模型（`ollama pull <model-name>`）\n• 查看 Xcode 控制台获取详细信息"
                } else {
                    if !models.contains(settings.llmModel) {
                        settings.llmModel = models[0]
                        autoSave()
                    }
                }
            } catch {
                print("[SettingsView] ❌ Failed to load Ollama models: \(error)")
                llmModels = []
                showLLMErrorAlert = true
                llmErrorMessage = "加载 Ollama 模型失败\n\n\(error.localizedDescription)"
            }

        case .lmstudio:
            print("[SettingsView] Attempting to load LM Studio models...")
            let models = await ModelDiscoveryService.shared.getLMStudioModels(forceRefresh: true)
            print("[SettingsView] LM Studio returned \(models.count) models: \(models)")
            llmModels = models

            if models.isEmpty {
                showLLMErrorAlert = true
                llmErrorMessage = "未检测到 LM Studio 模型\n\n请确认：\n• LM Studio 应用已启动\n• 至少加载了一个模型到内存\n• 服务地址为 http://127.0.0.1:1234/v1\n• 查看 Xcode 控制台获取详细信息"
            } else {
                if !models.contains(settings.llmModel) {
                    settings.llmModel = models[0]
                    autoSave()
                }
            }
        }

        print("[SettingsView] Final llmModels count: \(llmModels.count)")
    }
    
    // MARK: - Folder Pickers (macOS Native)
    
    private func pickModelPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择模型存储路径"

        if panel.runModal() == .OK, let url = panel.url {
            settings.modelPath = url.path
            print("[SettingsView] Model path changed to: \(settings.modelPath)")
            autoSave()
            Task {
                await ModelDiscoveryService.shared.invalidateWhisperCache(modelPath: settings.modelPath)
                let discovered = await ModelDiscoveryService.shared.getWhisperModels(
                    modelPath: settings.modelPath,
                    forceRefresh: true
                )
                whisperModels = ["auto"] + discovered
                print("[SettingsView] Refreshed whisper models (force refresh): \(discovered.count)")
            }
        }
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择输出目录"

        if panel.runModal() == .OK, let url = panel.url {
            print("[SettingsView] User selected output folder: \(url.path)")
            settings.outputPath = url.path
            print("[SettingsView] Updated settings.outputPath to: \(settings.outputPath)")
            autoSave()
        }
    }
    
    // MARK: - Template Management
    
    private func scanTemplates() {
        isLoadingTemplates = true
        let templateNames = TemplateService.shared.scanTemplates(from: settings.templatePath)
        customTemplates = templateNames.map { CustomTemplateOption(name: $0) }
        isLoadingTemplates = false
    }
    
    private func pickTemplateFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择模板目录"

        if panel.runModal() == .OK, let url = panel.url {
            print("[SettingsView] User selected template folder: \(url.path)")
            settings.templatePath = url.path
            autoSave()
            // Rescan templates after folder change
            scanTemplates()
        }
    }
    
    private func openUploadTemplateFolder() {
        TemplateService.shared.openTemplateFolder(at: settings.templatePath)
        // Re-scan templates when user returns (simulated by just re-scanning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            scanTemplates()
        }
    }
    
    // MARK: - Helpers
    
     private func settingsSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
         VStack(alignment: .leading, spacing: 16) {
             HStack(spacing: 8) {
                 Image(systemName: icon)
                     .font(.system(size: 18))
                     .foregroundColor(color)
                 
                 Text(title)
                     .font(.system(size: 18, weight: .semibold))
             }
             
             Divider()
             
             content()
         }
         .padding(16)
         .background(.ultraThinMaterial)
         .cornerRadius(12)
     }
    
    private func autoSave() {
        print("[SettingsView] autoSave called, outputPath: \(settings.outputPath)")
        if settingsList.isEmpty {
            print("[SettingsView] Inserting new settings to context")
            modelContext.insert(settings)
        } else {
            print("[SettingsView] Updating existing settings")
        }
        do {
            try modelContext.save()
            print("[SettingsView] Settings saved successfully")
            withAnimation {
                showSaveSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSaveSuccess = false
                }
            }
        } catch {
            print("[SettingsView] Failed to save settings: \(error)")
        }
    }
    
    private func saveSettings() {
        autoSave()
    }
    
    private func toggleSubtitleFormat(_ format: String) {
        var formats = settings.subtitleFormats
        if formats.contains(format) {
            formats.removeAll { $0 == format }
        } else {
            formats.append(format)
        }
        settings.subtitleFormats = formats
        autoSave()
    }
    
    // MARK: - Empty State Views
    
    @ViewBuilder
    private func llmErrorDetailView(errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("未检测到模型")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }

            Text(errorMessage)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            llmTroubleshootingSteps()
            
            Text("查看 Xcode 控制台获取详细错误信息")
                .font(.system(size: 9))
                .padding(4)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func llmEmptyStateView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("未检测到模型，请确认服务已运行")
                    .font(.system(size: 12))
                    .foregroundColor(.appleGray)
            }
            
            llmTroubleshootingSteps()
        }
        .padding(8)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func llmTroubleshootingSteps() -> some View {
        let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
        
        VStack(alignment: .leading, spacing: 4) {
            if serviceType == .ollama {
                Text("• Ollama 服务可能未启动")
                Text("• 未安装任何模型")
                Text("• 网络连接问题")
            } else {
                Text("• LM Studio 应用未启动")
                Text("• 未加载模型到内存")
                Text("• 本地服务器未运行")
            }
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func debugInfoContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📁 Whisper 模型路径")
                .font(.system(size: 12, weight: .semibold))
            Text("配置值: \(settings.modelPath)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text("已发现模型: \(whisperModels.count - 1) 个")
                .font(.system(size: 11))
            
            Divider()
            
            Text("🤖 LLM 服务状态")
                .font(.system(size: 12, weight: .semibold))
            Text("服务类型: \(settings.llmService)")
                .font(.system(size: 11))
            Text("已发现模型: \(llmModels.count) 个")
                .font(.system(size: 11))
            Text("当前选中: \(settings.llmModel)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("⚡ 缓存状态")
                .font(.system(size: 12, weight: .semibold))
            Text("（详细信息请查看 Xcode 控制台日志）")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.appleGray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
        }
    }
}

struct FormatCheckbox: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .appleBlue : .gray)
                
                Text(title)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}