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

    func transcribe(audioURL: URL, model: String = "", outputDir: URL, settings: AppSettings) async throws -> TranscriptionResult {
        let outputPath = outputDir.appendingPathComponent("transcription.txt")

        // 验证用户选择的模型
        guard !model.isEmpty else {
            throw WhisperError.transcriptionFailedWithMessage("未选择Whisper模型，请在设置中选择模型")
        }

        let actualModel = model

        // 查找可用的 Python 环境（优先使用包含 mlx_whisper 的虚拟环境）
        let pythonPath = findPythonWithMLXWhisper()
        print("[WhisperService] Using Python: \(pythonPath)")
        print("[WhisperService] Using user selected model: \(actualModel)")

        // 获取脚本路径
        let scriptPath = getTranscribeScriptPath()
        print("[WhisperService] Using script: \(scriptPath)")

        // 获取 ffmpeg 路径并传递给脚本
        let ffmpegPath = try FFmpegService.shared.getFFmpegPath()
        print("[WhisperService] Passing ffmpeg path: \(ffmpegPath)")

        var arguments = [
            scriptPath,
            "--model", actualModel,
            "--output_dir", outputDir.path,
            "--ffmpeg", ffmpegPath
        ]

        if settings.enableVAD {
            arguments.append("--vad")
        }

        if settings.enableSpeakerDiarization {
            arguments.append("--diarize")
        }

        // 添加temperature参数
        if settings.temperature != 0.0 {
            arguments.append("--temperature")
            arguments.append(String(settings.temperature))
        }

        // 添加best_of参数
        if settings.bestOf != 5 {
            arguments.append("--best_of")
            arguments.append(String(settings.bestOf))
        }

        // 添加beam_size参数
        if settings.beamSize != 5 {
            arguments.append("--beam_size")
            arguments.append(String(settings.beamSize))
        }

        // FP16默认启用，仅在用户禁用时传递--no_fp16
        if !settings.useFP16 {
            arguments.append("--no_fp16")
        }

        arguments.append(audioURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = arguments

        // 分离stdout和stderr，避免调试信息污染转录文本
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            // Set up timeout for long-running transcriptions
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 600_000_000_000) // 10 minutes timeout
                if !Task.isCancelled {
                    print("[WhisperService] Transcription timeout, terminating process")
                    process.terminate()
                    // 等待进程完全终止
                    process.waitUntilExit()
                    continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("转录超时（10分钟），请尝试更小的模型或检查文件"))
                }
            }

            // 监控stderr输出（调试信息）
            var errorBuffer = ""
            let stderrHandle = stderrPipe.fileHandleForReading
            stderrHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    errorBuffer += output
                    print("[WhisperService] Process stderr: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            
            process.terminationHandler = { proc in
                timeoutTask.cancel() // Cancel timeout when process ends
                stderrHandle.readabilityHandler = nil
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
                
                print("[WhisperService] Process terminated with status: \(proc.terminationStatus)")
                
                // 等待一小段时间确保文件写入完成
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    if proc.terminationStatus == 0 {
                        do {
                            // 检查文件是否存在
                            guard FileManager.default.fileExists(atPath: outputPath.path) else {
                                print("[WhisperService] Output file does not exist: \(outputPath.path)")
                                continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("转录结果文件未生成"))
                                return
                            }
                            
                            // 从文件读取转录结果，而不是从stdout
                            let rawText = try String(contentsOf: outputPath, encoding: .utf8)
                            
                            // 检查文件内容是否为空
                            guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                print("[WhisperService] Output file is empty")
                                continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("转录结果为空"))
                                return
                            }
                            
                            let segments = Self.parseSegmentsStatic(from: rawText)
                            let plainText = segments.map { $0.text }.joined(separator: "\n")
                            let result = TranscriptionResult(
                                text: plainText,
                                rawText: rawText,
                                segments: segments,
                                outputPath: outputPath
                            )
                            print("[WhisperService] Transcription completed successfully, segments: \(segments.count)")
                            
                            // 清理过程文件audio.wav
                            cleanupProcessFiles(audioURL: audioURL)
                            
                            continuation.resume(returning: result)
                        } catch {
                            print("[WhisperService] Failed to read output file: \(error)")
                            continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("转录结果读取失败: \(error.localizedDescription)"))
                        }
                    } else {
                        let errorString = errorBuffer.isEmpty ? "进程异常退出 (状态码: \(proc.terminationStatus))" : errorBuffer
                        print("[WhisperService] Transcription failed: \(errorString)")
                        continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("转录失败: \(errorString)"))
                    }
                }
            }

            do {
                try process.run()
                print("[WhisperService] Process started successfully, PID: \(process.processIdentifier)")
            } catch {
                timeoutTask.cancel()
                print("[WhisperService] Failed to start process: \(error)")
                continuation.resume(throwing: WhisperError.notInstalled)
            }
        }
    }

    func transcribeSegments(audioURLs: [URL], model: String = "", outputDir: URL, settings: AppSettings, segmentDuration: Double = 1800.0, overlapDuration: Double = 10.0) async throws -> TranscriptionResult {
        let outputPath = outputDir.appendingPathComponent("transcription.txt")

        // 验证用户选择的模型
        guard !model.isEmpty else {
            throw WhisperError.transcriptionFailedWithMessage("未选择Whisper模型，请在设置中选择模型")
        }

        let actualModel = model

        // 查找可用的 Python 环境
        let pythonPath = findPythonWithMLXWhisper()
        let scriptPath = getTranscribeScriptPath()
        let ffmpegPath = try FFmpegService.shared.getFFmpegPath()

        var allSegments: [TranscriptionSegment] = []

        for (index, audioURL) in audioURLs.enumerated() {
            print("[WhisperService] Transcribing segment \(index + 1)/\(audioURLs.count): \(audioURL.path)")

            let segmentOutputPath = outputDir.appendingPathComponent("segment_\(index + 1).txt")

            var arguments = [
                scriptPath,
                "--model", actualModel,
                "--output_dir", outputDir.path,
                "--ffmpeg", ffmpegPath
            ]

            if settings.enableVAD {
                arguments.append("--vad")
            }

            if settings.enableSpeakerDiarization {
                arguments.append("--diarize")
            }

            // 添加temperature参数
            if settings.temperature != 0.0 {
                arguments.append("--temperature")
                arguments.append(String(settings.temperature))
            }

            // 添加best_of参数
            if settings.bestOf != 5 {
                arguments.append("--best_of")
                arguments.append(String(settings.bestOf))
            }

            // 添加beam_size参数
            if settings.beamSize != 5 {
                arguments.append("--beam_size")
                arguments.append(String(settings.beamSize))
            }

            // FP16默认启用，仅在用户禁用时传递--no_fp16
            if !settings.useFP16 {
                arguments.append("--no_fp16")
            }

            arguments.append(audioURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var errorBuffer = ""
                let stderrHandle = stderrPipe.fileHandleForReading
                stderrHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        let output = String(data: data, encoding: .utf8) ?? ""
                        errorBuffer += output
                        print("[WhisperService] Segment \(index + 1) stderr: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }

                process.terminationHandler = { proc in
                    stderrHandle.readabilityHandler = nil
                    stdoutPipe.fileHandleForReading.closeFile()
                    stderrPipe.fileHandleForReading.closeFile()

                    if proc.terminationStatus == 0 {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                            if FileManager.default.fileExists(atPath: segmentOutputPath.path) {
                                do {
                                    let rawText = try String(contentsOf: segmentOutputPath, encoding: .utf8)
                                    if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        let segments = Self.parseSegmentsStatic(from: rawText)
                                        print("[WhisperService] Segment \(index + 1) completed, segments: \(segments.count)")
                                        allSegments.append(contentsOf: segments)
                                        continuation.resume()
                                    } else {
                                        print("[WhisperService] Segment \(index + 1) output is empty")
                                        continuation.resume()
                                    }
                                } catch {
                                    print("[WhisperService] Failed to read segment \(index + 1) output: \(error)")
                                    continuation.resume()
                                }
                            } else {
                                print("[WhisperService] Segment \(index + 1) output file not found")
                                continuation.resume()
                            }
                        }
                    } else {
                        let errorString = errorBuffer.isEmpty ? "进程异常退出 (状态码: \(proc.terminationStatus))" : errorBuffer
                        print("[WhisperService] Segment \(index + 1) transcription failed: \(errorString)")
                        continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("分段\(index + 1)转录失败: \(errorString)"))
                    }
                }

                do {
                    try process.run()
                } catch {
                    print("[WhisperService] Failed to start process for segment \(index + 1): \(error)")
                    continuation.resume(throwing: WhisperError.notInstalled)
                }
            }

            // 清理分段过程文件
            try? FileManager.default.removeItem(at: audioURL)
            try? FileManager.default.removeItem(at: segmentOutputPath)
        }

        // 合并并调整时间戳
        let mergedSegments = mergeAndAdjustTimestamps(segments: allSegments, segmentDuration: segmentDuration, overlapDuration: overlapDuration)

        // 生成合并后的转录文本
        let plainText = mergedSegments.map { $0.text }.joined(separator: "\n")
        let rawText = generateRawTextFromSegments(segments: mergedSegments)

        // 写入最终输出文件
        try rawText.write(to: outputPath, atomically: true, encoding: .utf8)

        let result = TranscriptionResult(
            text: plainText,
            rawText: rawText,
            segments: mergedSegments,
            outputPath: outputPath
        )

        print("[WhisperService] All segments transcribed and merged, total segments: \(mergedSegments.count)")
        return result
    }

    // 静态方法，供外部调用
    static func findPythonWithMLXWhisperStatic() -> String {
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

    static func getTranscribeScriptPathStatic() -> String {
        // 首先检查 Bundle 中的脚本
        if let bundlePath = Bundle.main.path(forResource: "transcribe", ofType: "py", inDirectory: "Resources") {
            return bundlePath
        }

        // 检查常见的开发路径
        let possiblePaths = [
            "\(NSHomeDirectory())/Documents/trae/mediamind/mediamind/Resources/transcribe.py",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("[WhisperService] Found transcribe script at: \(path)")
                return path
            }
        }

        print("[WhisperService] Error: transcribe.py not found")
        return ""
    }

    static func parseSegmentsStatic(from text: String) -> [TranscriptionSegment] {
        var segments: [TranscriptionSegment] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.isEmpty { continue }

            var confidence = 1.0

            // Pattern 1: [HH:MM:SS - HH:MM:SS] (confidence) Speaker: text
            let patternWithConfidence = #"\[(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\s*-\s*(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\]\s*\((\d+\.?\d*)\)\s*(.*?):\s*(.*)"#
            // Pattern 2: [HH:MM:SS - HH:MM:SS] Speaker: text
            let patternWithSpeaker = #"\[(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\s*-\s*(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\]\s*(.*?):\s*(.*)"#
            // Pattern 3: [HH:MM:SS - HH:MM:SS] text (from transcribe.py)
            let patternSimple = #"\[(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\s*-\s*(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\]\s*(.*)"#

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

    static func mergeAndAdjustTimestampsStatic(segments: [TranscriptionSegment], segmentDuration: Double, overlapDuration: Double) -> [TranscriptionSegment] {
        var mergedSegments: [TranscriptionSegment] = []
        var currentSegmentOffset = 0.0

        for segment in segments {
            let segmentStartTime = parseTimeToSecondsStatic(segment.startTime)
            let segmentEndTime = parseTimeToSecondsStatic(segment.endTime)
            
            // 计算调整后的时间戳
            let adjustedStartTime = segmentStartTime + currentSegmentOffset
            let adjustedEndTime = segmentEndTime + currentSegmentOffset
            
            // 检查是否需要跳过重叠部分
            if currentSegmentOffset > 0 {
                let overlapThreshold = currentSegmentOffset - overlapDuration
                
                if adjustedStartTime > overlapThreshold {
                    let adjustedSegment = TranscriptionSegment(
                        startTime: formatTimeFromSecondsStatic(adjustedStartTime),
                        endTime: formatTimeFromSecondsStatic(adjustedEndTime),
                        speaker: segment.speaker,
                        text: segment.text,
                        confidence: segment.confidence
                    )
                    mergedSegments.append(adjustedSegment)
                }
            } else {
                let adjustedSegment = TranscriptionSegment(
                    startTime: formatTimeFromSecondsStatic(adjustedStartTime),
                    endTime: formatTimeFromSecondsStatic(adjustedEndTime),
                    speaker: segment.speaker,
                    text: segment.text,
                    confidence: segment.confidence
                )
                mergedSegments.append(adjustedSegment)
            }
            
            // 更新下一段的偏移量
            if segmentEndTime >= segmentDuration - overlapDuration {
                currentSegmentOffset += (segmentDuration - overlapDuration)
            }
        }

        return mergedSegments
    }
    
    static func mergeAndAdjustTimestampsWithStartTimesStatic(segments: [TranscriptionSegment], segmentStartTimes: [Double], segmentDuration: Double, overlapDuration: Double) -> [TranscriptionSegment] {
        guard !segmentStartTimes.isEmpty else {
            return segments
        }
        
        var mergedSegments: [TranscriptionSegment] = []
        var currentPartIndex = 0
        var lastEndTime = 0.0
        
        for segment in segments {
            let segmentStartTime = parseTimeToSecondsStatic(segment.startTime)
            let segmentEndTime = parseTimeToSecondsStatic(segment.endTime)
            
            // 检测是否进入新的一段（当结束时间小于开始时间，或时间戳重置时）
            if segmentStartTime < lastEndTime - 60 || (lastEndTime > 0 && segmentStartTime > lastEndTime + 60) {
                // 时间戳重置，进入下一段
                currentPartIndex += 1
            }
            lastEndTime = segmentEndTime
            
            // 确定当前片段属于哪一段
            let partStartTime = currentPartIndex < segmentStartTimes.count ? segmentStartTimes[currentPartIndex] : 0.0
            
            // 计算调整后的时间戳
            let adjustedStartTime = segmentStartTime + partStartTime
            let adjustedEndTime = segmentEndTime + partStartTime
            
            let adjustedSegment = TranscriptionSegment(
                startTime: formatTimeFromSecondsStatic(adjustedStartTime),
                endTime: formatTimeFromSecondsStatic(adjustedEndTime),
                speaker: segment.speaker,
                text: segment.text,
                confidence: segment.confidence
            )
            mergedSegments.append(adjustedSegment)
        }
        
        return mergedSegments
    }

    static func parseTimeToSecondsStatic(_ timeString: String) -> Double {
        let timePart: String
        var milliseconds: Double = 0.0
        
        if timeString.contains(".") {
            let parts = timeString.components(separatedBy: ".")
            timePart = parts[0]
            if parts.count > 1 {
                let msStr = String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
                milliseconds = Double(msStr)! / 1000.0
            }
        } else if timeString.contains(",") {
            let parts = timeString.components(separatedBy: ",")
            timePart = parts[0]
            if parts.count > 1 {
                let msStr = String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
                milliseconds = Double(msStr)! / 1000.0
            }
        } else {
            timePart = timeString
        }
        
        let components = timePart.components(separatedBy: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0.0
        }
        return hours * 3600 + minutes * 60 + seconds + milliseconds
    }

    static func formatTimeFromSecondsStatic(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }

    static func generateRawTextFromSegmentsStatic(segments: [TranscriptionSegment]) -> String {
        return segments.map { segment in
            if segment.speaker.isEmpty {
                return "[\(segment.startTime) - \(segment.endTime)] \(segment.text)"
            } else {
                return "[\(segment.startTime) - \(segment.endTime)] \(segment.speaker): \(segment.text)"
            }
        }.joined(separator: "\n")
    }

    private func mergeAndAdjustTimestamps(segments: [TranscriptionSegment], segmentDuration: Double, overlapDuration: Double) -> [TranscriptionSegment] {
        var mergedSegments: [TranscriptionSegment] = []
        var currentSegmentOffset = 0.0

        for segment in segments {
            let segmentStartTime = parseTimeToSeconds(segment.startTime)
            let segmentEndTime = parseTimeToSeconds(segment.endTime)
            
            // 计算调整后的时间戳
            let adjustedStartTime = segmentStartTime + currentSegmentOffset
            let adjustedEndTime = segmentEndTime + currentSegmentOffset
            
            // 检查是否需要跳过重叠部分
            if currentSegmentOffset > 0 {
                let overlapThreshold = currentSegmentOffset - overlapDuration
                
                if adjustedStartTime > overlapThreshold {
                    let adjustedSegment = TranscriptionSegment(
                        startTime: formatTimeFromSeconds(adjustedStartTime),
                        endTime: formatTimeFromSeconds(adjustedEndTime),
                        speaker: segment.speaker,
                        text: segment.text,
                        confidence: segment.confidence
                    )
                    mergedSegments.append(adjustedSegment)
                }
            } else {
                let adjustedSegment = TranscriptionSegment(
                    startTime: formatTimeFromSeconds(adjustedStartTime),
                    endTime: formatTimeFromSeconds(adjustedEndTime),
                    speaker: segment.speaker,
                    text: segment.text,
                    confidence: segment.confidence
                )
                mergedSegments.append(adjustedSegment)
            }
            
            // 更新下一段的偏移量
            if segmentEndTime >= segmentDuration - overlapDuration {
                currentSegmentOffset += (segmentDuration - overlapDuration)
            }
        }

        return mergedSegments
    }

    private func parseTimeToSeconds(_ timeString: String) -> Double {
        let timePart: String
        var milliseconds: Double = 0.0
        
        if timeString.contains(".") {
            let parts = timeString.components(separatedBy: ".")
            timePart = parts[0]
            if parts.count > 1 {
                let msStr = String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
                milliseconds = Double(msStr)! / 1000.0
            }
        } else if timeString.contains(",") {
            let parts = timeString.components(separatedBy: ",")
            timePart = parts[0]
            if parts.count > 1 {
                let msStr = String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
                milliseconds = Double(msStr)! / 1000.0
            }
        } else {
            timePart = timeString
        }
        
        let components = timePart.components(separatedBy: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0.0
        }
        return hours * 3600 + minutes * 60 + seconds + milliseconds
    }

    private func formatTimeFromSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }

    private func generateRawTextFromSegments(segments: [TranscriptionSegment]) -> String {
        return segments.map { segment in
            if segment.speaker.isEmpty {
                return "[\(segment.startTime) - \(segment.endTime)] \(segment.text)"
            } else {
                return "[\(segment.startTime) - \(segment.endTime)] \(segment.speaker): \(segment.text)"
            }
        }.joined(separator: "\n")
    }

    private func cleanupProcessFiles(audioURL: URL) {
        // 清理audio.wav过程文件
        if audioURL.lastPathComponent == "audio.wav" {
            do {
                try FileManager.default.removeItem(at: audioURL)
                print("[WhisperService] Cleaned up process file: \(audioURL.path)")
            } catch {
                print("[WhisperService] Failed to clean up process file: \(error)")
            }
        }
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
            "\(NSHomeDirectory())/Documents/trae/mediamind/mediamind/Resources/transcribe.py",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("[WhisperService] Found transcribe script at: \(path)")
                return path
            }
        }

        print("[WhisperService] Error: transcribe.py not found")
        return ""
    }
}

enum WhisperError: LocalizedError {
    case notInstalled
    case transcriptionFailedWithMessage(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Whisper未安装或配置不正确"
        case .transcriptionFailedWithMessage(let message):
            return message
        }
    }
}