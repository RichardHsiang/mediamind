import Foundation

struct VideoInfo: Codable, Sendable {
    let format: FormatInfo?
    let streams: [StreamInfo]?

    var duration: Double {
        format?.duration?.value ?? 0
    }

    var width: Int {
        streams?.first?.width ?? 0
    }

    var height: Int {
        streams?.first?.height ?? 0
    }
}

struct FormatInfo: Codable, Sendable {
    let duration: StringOrDouble?
}

/// 支持解码 String 或 Double 类型的 duration
struct StringOrDouble: Codable, Sendable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self),
           let doubleValue = Double(stringValue) {
            value = doubleValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else {
            value = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct StreamInfo: Codable, Sendable {
    let width: Int?
    let height: Int?
}

actor FFmpegService {
    static let shared = FFmpegService()

    private var ffmpegPath: String?
    private var ffprobePath: String?

    private func findExecutable(_ name: String) -> String? {
        // 常见安装路径
        let possiblePaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 尝试使用 which 命令查找
        let envPaths = ["/usr/bin/env", "/bin/sh"]

        for envPath in envPaths {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: envPath)
            process.arguments = ["which", name]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                        return path
                    }
                }
            } catch {
                print("[FFmpegService] Error finding \(name) via \(envPath): \(error.localizedDescription)")
            }
        }

        return nil
    }

    func getFFmpegPath() throws -> String {
        if let path = ffmpegPath {
            return path
        }
        if let path = findExecutable("ffmpeg") {
            ffmpegPath = path
            print("[FFmpegService] Found ffmpeg at: \(path)")
            return path
        }
        throw FFmpegError.notInstalled
    }

    private func getFFprobePath() throws -> String {
        if let path = ffprobePath {
            return path
        }
        if let path = findExecutable("ffprobe") {
            ffprobePath = path
            print("[FFmpegService] Found ffprobe at: \(path)")
            return path
        }
        throw FFmpegError.notInstalled
    }

    func extractAudio(from videoURL: URL, outputDir: URL, settings: AppSettings? = nil) async throws -> URL {
        let outputURL = outputDir.appendingPathComponent("extracted_audio.wav")

        var arguments: [String] = [
            "-i", videoURL.path,
            "-vn",
            "-acodec", "pcm_s16le",
            "-ar", "16000",
            "-ac", "1"
        ]

        if let settings = settings {
            var filterChain: [String] = []

            if settings.enableDenoise {
                // 使用 afftdn (FFT Denoise) 滤镜，这是 FFmpeg 标准内置的降噪滤镜
                filterChain.append("afftdn=nf=-25")
            }

            if settings.enableVolumeNormalize {
                filterChain.append("loudnorm=I=-16:TP=-1.5:LRA=11")
            }

            if !filterChain.isEmpty {
                arguments.append("-af")
                arguments.append(filterChain.joined(separator: ","))
            }
        }

        arguments.append("-y")
        arguments.append(outputURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: try getFFmpegPath())
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outputURL)
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "未知错误"
                    print("[FFmpegService] Audio extraction failed: \(errorString)")
                    continuation.resume(throwing: FFmpegError.extractionFailed)
                }
            }

            do {
                try process.run()
            } catch {
                print("[FFmpegService] Failed to run ffmpeg: \(error)")
                continuation.resume(throwing: FFmpegError.notInstalled)
            }
        }
    }

    func getVideoInfo(_ url: URL) async throws -> VideoInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try getFFprobePath())
        process.arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-show_entries", "stream=width,height",
            "-of", "json",
            url.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                guard proc.terminationStatus == 0 else {
                    continuation.resume(throwing: FFmpegError.probeFailed)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                do {
                    let info = try JSONDecoder().decode(VideoInfo.self, from: data)
                    continuation.resume(returning: info)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: FFmpegError.notInstalled)
            }
        }
    }

    func extractFrame(at time: Double, from videoURL: URL, outputDir: URL) async throws -> URL {
        let outputURL = outputDir.appendingPathComponent("frame_\(Int(time)).jpg")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: try getFFmpegPath())
        process.arguments = [
            "-ss", "\(time)",
            "-i", videoURL.path,
            "-vframes", "1",
            "-q:v", "2",
            "-y",
            outputURL.path
        ]

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: FFmpegError.frameExtractionFailed)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: FFmpegError.notInstalled)
            }
        }
    }
}

enum FFmpegError: Error, LocalizedError {
    case notInstalled
    case extractionFailed
    case probeFailed
    case frameExtractionFailed

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "FFmpeg 未安装。请运行以下命令安装:\n\nbrew install ffmpeg\n\n安装完成后请重启应用。"
        case .extractionFailed:
            return "音频提取失败"
        case .probeFailed:
            return "视频信息获取失败"
        case .frameExtractionFailed:
            return "截图提取失败"
        }
    }
}
