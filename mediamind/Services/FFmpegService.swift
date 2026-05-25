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

final class FFmpegService {
    static let shared = FFmpegService()

    private var ffmpegPath: String?
    private var ffprobePath: String?
    private let lock = NSLock()

    private func findExecutable(_ name: String) -> String? {
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
            } catch {}
        }

        return nil
    }

    func getFFmpegPath() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        if let path = ffmpegPath {
            return path
        }
        if let path = findExecutable("ffmpeg") {
            ffmpegPath = path
            return path
        }
        throw FFmpegError.notInstalled
    }

    private func getFFprobePath() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        if let path = ffprobePath {
            return path
        }
        if let path = findExecutable("ffprobe") {
            ffprobePath = path
            return path
        }
        throw FFmpegError.notInstalled
    }

    func getVideoInfo(_ url: URL) async throws -> VideoInfo {
        let ffprobe = try getFFprobePath()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffprobe)
            process.arguments = [
                "-v", "error",
                "-show_entries", "format=duration",
                "-show_entries", "stream=width,height",
                "-of", "json",
                url.path
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

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
        let ffmpeg = try getFFmpegPath()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpeg)
            process.arguments = [
                "-ss", "\(time)",
                "-i", videoURL.path,
                "-vframes", "1",
                "-q:v", "2",
                "-y",
                outputURL.path
            ]

            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

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

    func extractClip(from videoURL: URL, startTime: Double, endTime: Double, outputDir: URL, outputFileName: String? = nil) async throws -> URL {
        let duration = endTime - startTime
        let fileName = outputFileName ?? "clip_\(Int(startTime))_\(Int(endTime)).mp4"
        let outputURL = outputDir.appendingPathComponent(fileName)
        let ffmpeg = try getFFmpegPath()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpeg)
            process.arguments = [
                "-ss", "\(startTime)",
                "-t", "\(duration)",
                "-i", videoURL.path,
                "-c", "copy",
                "-avoid_negative_ts", "make_zero",
                "-y",
                outputURL.path
            ]

            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: FFmpegError.clipExtractionFailed)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: FFmpegError.notInstalled)
            }
        }
    }

    func extractSegment(from videoURL: URL, startTime: Double, endTime: Double, outputDir: URL) async throws -> URL {
        let fileName = "segment_\(Int(startTime))_\(Int(endTime)).mp4"
        return try await extractClip(
            from: videoURL,
            startTime: startTime,
            endTime: endTime,
            outputDir: outputDir,
            outputFileName: fileName
        )
    }

    func extractAudio(from videoURL: URL, outputDir: URL, settings: AppSettings) async throws -> URL {
        let fileName = "audio.wav"
        let outputURL = outputDir.appendingPathComponent(fileName)
        let ffmpeg = try getFFmpegPath()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpeg)
            process.arguments = [
                "-i", videoURL.path,
                "-vn",
                "-acodec", "pcm_s16le",
                "-ar", "16000",
                "-ac", "1",
                "-y",
                outputURL.path
            ]

            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: FFmpegError.extractionFailed)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: FFmpegError.notInstalled)
            }
        }
    }

    func extractAndTranscribeSegments(from videoURL: URL, outputDir: URL, settings: AppSettings, segmentDuration: Double = 1800.0, overlapDuration: Double = 10.0, onSegmentReady: @escaping (URL, Int, Int, Double) async throws -> Void) async throws {
        let videoInfo = try await getVideoInfo(videoURL)
        let duration = videoInfo.duration
        let totalSegments = max(1, Int(ceil(duration / segmentDuration)))

        var currentTime = 0.0
        for segmentIndex in 0..<totalSegments {
            let segmentEndTime = min(currentTime + segmentDuration, duration)
            
            let segmentFileName = String(format: "segment_%03d.wav", segmentIndex)
            let segmentURL = outputDir.appendingPathComponent(segmentFileName)

            let ffmpeg = try getFFmpegPath()

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ffmpeg)
                process.arguments = [
                    "-ss", "\(currentTime)",
                    "-t", "\(segmentEndTime - currentTime)",
                    "-i", videoURL.path,
                    "-vn",
                    "-acodec", "pcm_s16le",
                    "-ar", "16000",
                    "-ac", "1",
                    "-y",
                    segmentURL.path
                ]

                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                process.terminationHandler = { _ in
                    continuation.resume(returning: ())
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: FFmpegError.extractionFailed)
                }
            }

            print("[FFmpegService] Extracted segment \(segmentIndex)/\(totalSegments): \(segmentURL.path) (start: \(currentTime)s)")
            
            try await onSegmentReady(segmentURL, segmentIndex, totalSegments, currentTime)

            currentTime += segmentDuration - overlapDuration
            if currentTime >= duration { break }
        }
    }
}

enum FFmpegError: Error, LocalizedError {
    case notInstalled
    case extractionFailed
    case probeFailed
    case frameExtractionFailed
    case clipExtractionFailed

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
        case .clipExtractionFailed:
            return "视频片段截取失败"
        }
    }
}
