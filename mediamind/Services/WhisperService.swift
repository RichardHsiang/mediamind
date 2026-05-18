import Foundation
import SwiftUI

struct TranscriptionResult {
    let text: String
    let rawText: String
    let segments: [TranscriptionSegment]
    let outputPath: URL
}

struct TranscriptionSegment {
    let startTime: String
    let endTime: String
    let speaker: String
    let text: String
    var confidence: Double = 1.0

    var confidenceLevel: ConfidenceLevel {
        if confidence >= 0.9 { return .high }
        else if confidence >= 0.7 { return .medium }
        else { return .low }
    }

    var isLowConfidence: Bool {
        confidence < 0.7
    }
}

enum ConfidenceLevel {
    case high
    case medium
    case low

    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

struct WhisperService {
    static let shared = WhisperService()

    func transcribe(audioURL: URL, model: String = "base", outputDir: URL, settings: AppSettings) async throws -> TranscriptionResult {
        let outputPath = outputDir.appendingPathComponent("transcription.txt")

        // 查找可用的 Python 环境（优先使用包含 mlx_whisper 的虚拟环境）
        let pythonPath = findPythonWithMLXWhisper()
        print("[WhisperService] Using Python: \(pythonPath)")

        // 获取脚本路径
        let scriptPath = getTranscribeScriptPath()
        print("[WhisperService] Using script: \(scriptPath)")

        // 获取 ffmpeg 路径并传递给脚本
        let ffmpegPath = await FFmpegService.shared.getFFmpegPath()
        print("[WhisperService] Passing ffmpeg path: \(ffmpegPath)")

        var arguments = [
            scriptPath,
            "--model", model,
            "--output_dir", outputDir.path,
            "--ffmpeg", ffmpegPath
        ]

        if settings.enableVAD {
            arguments.append("--vad")
        }

        if settings.enableSpeakerDiarization {
            arguments.append("--diarize")
        }

        arguments.append(audioURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    do {
                        let rawText = try String(contentsOf: outputPath, encoding: .utf8)
                        let segments = Self.parseSegmentsStatic(from: rawText)
                        let plainText = segments.map { $0.text }.joined(separator: "\n")
                        let result = TranscriptionResult(
                            text: plainText,
                            rawText: rawText,
                            segments: segments,
                            outputPath: outputPath
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: WhisperError.transcriptionFailed)
                    }
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "未知错误"
                    continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage(errorString))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: WhisperError.notInstalled)
            }
        }
    }

    private nonisolated static func parseSegmentsStatic(from text: String) -> [TranscriptionSegment] {
        var segments: [TranscriptionSegment] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.isEmpty { continue }

            var confidence = 1.0

            // Pattern 1: [HH:MM:SS - HH:MM:SS] (confidence) Speaker: text
            let patternWithConfidence = #"\[(\d{2}:\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}:\d{2})\]\s*\((\d+\.?\d*)\)\s*(.*?):\s*(.*)"#
            // Pattern 2: [HH:MM:SS - HH:MM:SS] Speaker: text
            let patternWithSpeaker = #"\[(\d{2}:\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}:\d{2})\]\s*(.*?):\s*(.*)"#
            // Pattern 3: [HH:MM:SS - HH:MM:SS] text (from transcribe.py)
            let patternSimple = #"\[(\d{2}:\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}:\d{2})\]\s*(.*)"#

            if let regex = try? NSRegularExpression(pattern: patternWithConfidence),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                let startTime = String(line[Range(match.range(at: 1), in: line)!])
                let endTime = String(line[Range(match.range(at: 2), in: line)!])
                let confidenceStr = String(line[Range(match.range(at: 3), in: line)!])
                let speaker = String(line[Range(match.range(at: 4), in: line)!])
                let text = String(line[Range(match.range(at: 5), in: line)!])

                confidence = Double(confidenceStr) ?? 1.0

                segments.append(TranscriptionSegment(
                    startTime: startTime,
                    endTime: endTime,
                    speaker: speaker,
                    text: text,
                    confidence: confidence / 100.0
                ))
            } else if let regex = try? NSRegularExpression(pattern: patternWithSpeaker),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                let startTime = String(line[Range(match.range(at: 1), in: line)!])
                let endTime = String(line[Range(match.range(at: 2), in: line)!])
                let speaker = String(line[Range(match.range(at: 3), in: line)!])
                let text = String(line[Range(match.range(at: 4), in: line)!])

                segments.append(TranscriptionSegment(
                    startTime: startTime,
                    endTime: endTime,
                    speaker: speaker,
                    text: text,
                    confidence: confidence
                ))
            } else if let regex = try? NSRegularExpression(pattern: patternSimple),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                let startTime = String(line[Range(match.range(at: 1), in: line)!])
                let endTime = String(line[Range(match.range(at: 2), in: line)!])
                let text = String(line[Range(match.range(at: 3), in: line)!])

                segments.append(TranscriptionSegment(
                    startTime: startTime,
                    endTime: endTime,
                    speaker: "",
                    text: text,
                    confidence: confidence
                ))
            }
        }

        return segments
    }

    static func filterSegmentsByConfidence(_ segments: [TranscriptionSegment], threshold: Double) -> (high: [TranscriptionSegment], low: [TranscriptionSegment]) {
        let high = segments.filter { $0.confidence >= threshold }
        let low = segments.filter { $0.confidence < threshold }
        return (high, low)
    }

    private func findPythonWithMLXWhisper() -> String {
        // 优先检查常见的虚拟环境路径
        let possiblePaths = [
            "\(NSHomeDirectory())/ComfyUI/.venv/bin/python3",
            "\(NSHomeDirectory())/.venv/bin/python3",
            "\(NSHomeDirectory())/venv/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                // 检查是否包含 mlx_whisper
                let checkProcess = Process()
                checkProcess.executableURL = URL(fileURLWithPath: path)
                checkProcess.arguments = ["-c", "import mlx_whisper; print('OK')"]

                let pipe = Pipe()
                checkProcess.standardOutput = pipe
                checkProcess.standardError = pipe

                do {
                    try checkProcess.run()
                    checkProcess.waitUntilExit()

                    if checkProcess.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        if output.contains("OK") {
                            print("[WhisperService] Found Python with mlx_whisper at: \(path)")
                            return path
                        }
                    }
                } catch {
                    print("[WhisperService] Error checking \(path): \(error)")
                }
            }
        }

        // 如果都找不到，返回系统默认的 python3
        print("[WhisperService] Warning: No Python with mlx_whisper found, falling back to system python3")
        return "/usr/bin/python3"
    }

    private func getTranscribeScriptPath() -> String {
        // 首先检查 Bundle 中的脚本
        if let bundlePath = Bundle.main.path(forResource: "transcribe", ofType: "py", inDirectory: "Resources") {
            return bundlePath
        }

        // 检查常见的开发路径
        let possiblePaths = [
            "\(NSHomeDirectory())/Documents/obsidian仓库/trae/mediamind/mediamind/Resources/transcribe.py",
            "\(NSHomeDirectory())/Documents/trae/mediamind/mediamind/Resources/transcribe.py",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // 默认返回相对路径（用于开发调试）
        return "mediamind/Resources/transcribe.py"
    }
}

enum WhisperError: Error, LocalizedError {
    case notInstalled
    case transcriptionFailed
    case transcriptionFailedWithMessage(String)
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "mlx-whisper 未安装，请运行: pip install mlx-whisper"
        case .transcriptionFailed:
            return "语音转录失败"
        case .transcriptionFailedWithMessage(let message):
            return "语音转录失败: \(message)"
        case .modelNotFound(let model):
            return "模型未找到: \(model)"
        }
    }
}
