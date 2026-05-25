import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @Binding var selectedFile: URL?
    @State private var isDragOver = false
    @State private var showFileImporter = false

    var body: some View {
        GlassCard {
            if let file = selectedFile {
                fileInfoView(file: file)
            } else {
                uploadZone
            }
        }
    }

    private var uploadZone: some View {
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
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [8, 4]
                    )
                )
                .foregroundColor(isDragOver ? .appleBlue : .appleBorder)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .onTapGesture {
            showFileImporter = true
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFile = url
                }
            case .failure:
                break
            }
        }
    }

    private func fileInfoView(file: URL) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.appleBlue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: fileIcon(for: file))
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(file.lastPathComponent)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Text(fileSizeString(for: file))
                    .font(.system(size: 13))
                    .foregroundColor(.appleGray)
            }

            Spacer()

            Button(action: { selectedFile = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.appleGray)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.white.opacity(0.5))
        .cornerRadius(12)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            selectedFile = url
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if AppConstants.supportedVideoFormats.contains(ext) {
            return "film.fill"
        }
        return "music.note"
    }

    private func fileSizeString(for url: URL) -> String {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        } catch {}
        return "未知大小"
    }
}
