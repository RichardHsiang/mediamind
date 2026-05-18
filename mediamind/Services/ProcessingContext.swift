import Foundation

class ProcessingContext {
    let fileURL: URL
    let outputType: OutputType
    let settings: AppSettings

    var tempDir: URL?
    var audioURL: URL?
    var transcriptionResult: TranscriptionResult?
    var analysis: String?
    var generatedFiles: [URL] = []
    var screenshotURLs: [URL] = []

    // 进度回调
    var onProgressUpdate: ((Double, String) -> Void)?

    var fileName: String { fileURL.lastPathComponent }
    var fileExtension: String { fileURL.pathExtension.lowercased() }
    var baseName: String { fileURL.deletingPathExtension().lastPathComponent }
    var fileSize: Int64 {
        (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    init(fileURL: URL, outputType: OutputType, settings: AppSettings) {
        self.fileURL = fileURL
        self.outputType = outputType
        self.settings = settings
    }

    /// 发送进度更新
    func reportProgress(_ progress: Double, description: String) {
        onProgressUpdate?(progress, description)
    }
}
