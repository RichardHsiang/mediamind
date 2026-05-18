import Foundation

struct FileService {
    static let shared = FileService()

    private let supportedFormats = AppConstants.supportedFormats
    private let supportedAudioFormats = AppConstants.supportedAudioFormats
    private let supportedVideoFormats = AppConstants.supportedVideoFormats
    private let maxFileSize = AppConstants.maxFileSize

    func validateFile(_ url: URL) throws -> FileInfo {
        let ext = url.pathExtension.lowercased()
        guard supportedFormats.contains(ext) else {
            throw FileValidationError.unsupportedFormat(ext)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileValidationError.fileNotFound
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? Int64 ?? 0

        guard size > 0 else {
            throw FileValidationError.emptyFile
        }

        guard size <= maxFileSize else {
            throw FileValidationError.fileTooLarge(ByteCountFormatter.string(fromByteCount: maxFileSize, countStyle: .file))
        }

        let isAudio = supportedAudioFormats.contains(ext)
        let isVideo = supportedVideoFormats.contains(ext)

        return FileInfo(
            url: url,
            name: url.lastPathComponent,
            extension: ext,
            size: size,
            type: isAudio ? .audio : (isVideo ? .video : .unknown)
        )
    }

    func createOutputDirectory() throws -> URL {
        let outputPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("MediaMind")
            .appendingPathComponent("output")

        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
        return outputPath
    }

    func createTempDirectory() throws -> URL {
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaMind")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempPath, withIntermediateDirectories: true)
        return tempPath
    }

    func cleanupTempDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

struct FileInfo {
    let url: URL
    let name: String
    let `extension`: String
    let size: Int64
    let type: FileType

    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum FileType {
    case audio
    case video
    case unknown
}

enum FileValidationError: Error, LocalizedError {
    case unsupportedFormat(String)
    case fileNotFound
    case emptyFile
    case fileTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "不支持的文件格式: .\(ext)"
        case .fileNotFound:
            return "文件不存在"
        case .emptyFile:
            return "文件为空"
        case .fileTooLarge(let maxSize):
            return "文件大小超过限制（最大 \(maxSize)）"
        }
    }
}
