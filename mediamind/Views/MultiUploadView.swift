import SwiftUI
import UniformTypeIdentifiers

struct MultiUploadView: View {
    @Binding var selectedFiles: [URL]
    @State private var isDragOver = false
    @State private var showFileImporter = false
    @State private var isProcessingDrop = false

    var body: some View {
        VStack(spacing: 0) {
            if selectedFiles.isEmpty {
                uploadZone
            } else {
                fileListWithDrop
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragOver) { providers in
            print("[MultiUploadView] ========== 拖拽激活 ==========")
            print("[MultiUploadView] 提供商数量: \(providers.count)")
            print("[MultiUploadView] isDragOver状态: \(isDragOver)")
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard !isProcessingDrop else {
            print("[MultiUploadView] ⚠️ 正在处理拖拽，忽略新的拖拽")
            return
        }
        
        isProcessingDrop = true
        print("[MultiUploadView] ========== 拖拽开始 ==========")
        print("[MultiUploadView] 提供商数量: \(providers.count)")
        
        var validFiles: [URL] = []
        let group = DispatchGroup()
        
        for (index, provider) in providers.enumerated() {
            group.enter()
            
            print("[MultiUploadView] 处理提供商 \(index + 1)/\(providers.count)")
            print("[MultiUploadView] 提供商类型: \(provider.registeredTypeIdentifiers)")
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                print("[MultiUploadView] ✅ 提供商支持文件URL类型")
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("[MultiUploadView] ❌ 加载项目失败: \(error.localizedDescription)")
                        return
                    }
                    
                    var fileURL: URL?
                    
                    if let data = item as? Data {
                        fileURL = URL(dataRepresentation: data, relativeTo: nil)
                        print("[MultiUploadView] 📄 从Data加载URL: \(fileURL?.lastPathComponent ?? "未知")")
                    } else if let url = item as? URL {
                        fileURL = url
                        print("[MultiUploadView] 📄 直接获取URL: \(url.lastPathComponent)")
                    } else {
                        print("[MultiUploadView] ❌ 未知的项目类型: \(type(of: item))")
                    }
                    
                    if let url = fileURL {
                        if isValidFile(url) {
                            DispatchQueue.main.async {
                                validFiles.append(url)
                                print("[MultiUploadView] ✅ 有效文件: \(url.lastPathComponent)")
                            }
                        } else {
                            print("[MultiUploadView] ⚠️ 无效文件类型: \(url.lastPathComponent)")
                        }
                    } else {
                        print("[MultiUploadView] ❌ 无法解析文件URL")
                    }
                }
            } else {
                print("[MultiUploadView] ⚠️ 提供商不支持文件URL类型")
                print("[MultiUploadView] 支持的类型: \(provider.registeredTypeIdentifiers)")
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("[MultiUploadView] ========== 拖拽处理完成 ==========")
            print("[MultiUploadView] 有效文件数量: \(validFiles.count)")
            
            if !validFiles.isEmpty {
                selectedFiles.append(contentsOf: validFiles)
                print("[MultiUploadView] ✅ 已添加 \(validFiles.count) 个文件，总计: \(selectedFiles.count)")
            } else {
                print("[MultiUploadView] ❌ 没有有效文件被添加")
            }
            
            isProcessingDrop = false
        }
    }

    private func isValidFile(_ url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            print("[MultiUploadView] ⚠️ 无法访问安全作用域资源: \(url.lastPathComponent)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let pathExtension = url.pathExtension.lowercased()
        let validExtensions = ["mp3", "wav", "m4a", "mp4", "mov", "mkv", "avi", "flv", "webm", "aac", "ogg", "wma"]
        
        let isValid = validExtensions.contains(pathExtension)
        print("[MultiUploadView] 文件验证: \(url.lastPathComponent) - 扩展名: \(pathExtension) - 有效: \(isValid)")
        
        return isValid
    }

    private var uploadZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(isDragOver ? .appleBlue : .gray)

            Text("拖拽多个文件到此处")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isDragOver ? .appleBlue : .primary)

            Text("或点击选择多个文件")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Label("MP3, WAV, M4A", systemImage: "music.note")
                Label("MP4, MOV, MKV", systemImage: "film")
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isDragOver ? Color.appleBlue.opacity(0.1) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .foregroundColor(isDragOver ? .appleBlue : .gray.opacity(0.3))
        )
        .onChange(of: isDragOver) { oldValue, newValue in
            print("[MultiUploadView] isDragOver状态变化: \(oldValue) -> \(newValue)")
        }
        .onTapGesture {
            print("[MultiUploadView] 点击上传区域")
            showFileImporter = true
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: true
        ) { result in
            print("[MultiUploadView] 文件选择器结果: \(result)")
            switch result {
            case .success(let urls):
                let validUrls = urls.filter { isValidFile($0) }
                print("[MultiUploadView] 通过选择器选择了 \(urls.count) 个文件，有效: \(validUrls.count)")
                selectedFiles.append(contentsOf: validUrls)
            case .failure(let error):
                print("[MultiUploadView] 文件选择器失败: \(error)")
            }
        }
    }

    private var fileListWithDrop: some View {
        VStack(spacing: 12) {
            HStack {
                Text("已选择 \(selectedFiles.count) 个文件")
                    .font(.system(size: 15, weight: .medium))
                
                Spacer()
                
                Button(action: {
                    selectedFiles.removeAll()
                    showFileImporter = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("重新选择")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(selectedFiles.enumerated()), id: \.offset) { index, file in
                        fileRow(file: file, index: index)
                    }
                    
                    dropZone
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: 300)
        }
    }
    
    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 32))
                .foregroundColor(isDragOver ? .appleBlue : .gray.opacity(0.6))
            
            Text("拖拽文件到此处添加")
                .font(.system(size: 13))
                .foregroundColor(isDragOver ? .appleBlue : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragOver ? Color.appleBlue.opacity(0.1) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                )
                .foregroundColor(isDragOver ? .appleBlue : .gray.opacity(0.3))
        )
        .onTapGesture {
            print("[MultiUploadView] 点击添加区域")
            showFileImporter = true
        }
    }

    private func fileRow(file: URL, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.appleBlue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: getFileIcon(fileExtension: file.pathExtension))
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                if let fileSize = getFileSize(file) {
                    Text(fileSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                selectedFiles.remove(at: index)
                print("[MultiUploadView] 移除文件: \(file.lastPathComponent)")
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    private func getFileIcon(fileExtension: String) -> String {
        let ext = fileExtension.lowercased()
        if ["mp3", "wav", "m4a", "aac", "ogg", "wma", "flac"].contains(ext) {
            return "music.note"
        } else if ["mp4", "mov", "mkv", "avi", "flv", "webm"].contains(ext) {
            return "film"
        } else {
            return "doc"
        }
    }

    private func getFileSize(_ url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? UInt64 else {
            return nil
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}