import SwiftUI
import UniformTypeIdentifiers

struct TemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPath: String = ""
    @State private var availableTemplates: [String] = []
    @State private var showFilePicker = false
    
    let onConfirm: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("选择报告模板目录")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("会议报告生成需要 HTML 模板文件")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text("模板目录应包含名为 meeting.html 的模板文件")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Selected path display
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.appleBlue)
                
                Text(selectedPath.isEmpty ? "未选择目录" : selectedPath)
                    .font(.system(size: 13))
                    .foregroundColor(selectedPath.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                Button("浏览...") {
                    showFilePicker = true
                }
                .font(.system(size: 13, weight: .medium))
            }
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(8)
            
            // Template preview
            if !availableTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("发现的模板:")
                        .font(.system(size: 13, weight: .medium))
                    
                    ForEach(availableTemplates, id: \.self) { template in
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            
                            Text(template)
                                .font(.system(size: 13))
                            
                            Spacer()
                            
                            Text("可用")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            } else if !selectedPath.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("该目录未找到 HTML 模板文件")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("确认并继续") {
                    if !selectedPath.isEmpty {
                        onConfirm(selectedPath)
                        dismiss()
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(!selectedPath.isEmpty ? Color.appleBlue : Color.gray)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedPath.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedPath = url.path
                    scanTemplates(at: url.path)
                }
            case .failure(let error):
                print("[TemplatePickerSheet] File picker error: \(error)")
            }
        }
    }
    
    private func scanTemplates(at path: String) {
        let templates = TemplateService.shared.scanTemplates(from: path)
        availableTemplates = templates
    }
}
