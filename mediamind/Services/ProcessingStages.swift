import Foundation

protocol ProcessingStage {
    func process(_ context: ProcessingContext) async throws
}

class FileValidationStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        context.reportProgress(0.02, description: "创建临时目录...")
        context.tempDir = try FileService.shared.createTempDirectory()
        guard context.tempDir != nil else { throw ProcessingError.fileValidationFailed }

        context.reportProgress(0.05, description: "验证文件格式...")
        _ = try FileService.shared.validateFile(context.fileURL)

        context.reportProgress(0.10, description: "文件校验完成")
    }
}

class AudioExtractionStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        if AppConstants.supportedAudioFormats.contains(context.fileExtension) {
            context.reportProgress(0.15, description: "音频文件，跳过提取")
            context.audioURL = context.fileURL
        } else {
            context.reportProgress(0.12, description: "检查视频时长...")
            guard let tempDir = context.tempDir else { throw ProcessingError.fileValidationFailed }
            
            // 获取视频时长
            let videoInfo = try await FFmpegService.shared.getVideoInfo(context.fileURL)
            let duration = videoInfo.duration
            
            // 如果时长超过20分钟，使用边提取边转录的并行处理
            if duration > 1200.0 { // 20分钟 = 1200秒
                context.reportProgress(0.13, description: "视频时长\(Int(duration/60))分钟，启用分段处理...")
                context.useSegmentedProcessing = true
                context.reportProgress(0.25, description: "开始分段提取和转录...")
            } else {
                context.reportProgress(0.15, description: "开始提取音频...")
                context.audioURL = try await FFmpegService.shared.extractAudio(
                    from: context.fileURL,
                    outputDir: tempDir,
                    settings: context.settings
                )
                context.reportProgress(0.25, description: "音频提取完成")
            }
        }
    }
}

class TranscriptionStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        guard let tempDir = context.tempDir else { throw ProcessingError.fileValidationFailed }

        context.reportProgress(0.30, description: "加载Whisper模型...")

        let whisperModel = context.settings.whisperModel
        
        // 检查是否使用分段处理
        if context.useSegmentedProcessing {
            context.reportProgress(0.35, description: "开始分段提取和转录...")
            
            var allSegments: [TranscriptionSegment] = []
            var segmentStartTimes: [Double] = []
            let segmentDuration = 900.0 // 15分钟
            let overlapDuration = 10.0 // 10秒重叠
            
            try await FFmpegService.shared.extractAndTranscribeSegments(
                from: context.fileURL,
                outputDir: tempDir,
                settings: context.settings,
                segmentDuration: segmentDuration,
                overlapDuration: overlapDuration
            ) { audioURL, segmentIndex, totalSegments, segmentStartTime in
                // 记录段的起始时间
                segmentStartTimes.append(segmentStartTime)
                
                // 边提取边转录
                context.reportProgress(0.35 + Double(segmentIndex) / Double(totalSegments) * 0.15, description: "转录第\(segmentIndex)/\(totalSegments)段...")
                
                // transcribe.py 默认输出 transcription.txt
                let segmentOutputPath = tempDir.appendingPathComponent("transcription.txt")

                let pythonPath = WhisperService.findPythonWithMLXWhisperStatic()
                let scriptPath = WhisperService.getTranscribeScriptPathStatic()
                let ffmpegPath = try FFmpegService.shared.getFFmpegPath()

                var arguments = [
                    scriptPath,
                    "--model", whisperModel,
                    "--output_dir", tempDir.path,
                    "--ffmpeg", ffmpegPath
                ]

                if context.settings.enableVAD {
                    arguments.append("--vad")
                }

                if context.settings.enableSpeakerDiarization {
                    arguments.append("--diarize")
                }

                // 添加temperature参数
                if context.settings.temperature != 0.0 {
                    arguments.append("--temperature")
                    arguments.append(String(context.settings.temperature))
                }

                // 添加best_of参数
                if context.settings.bestOf != 5 {
                    arguments.append("--best_of")
                    arguments.append(String(context.settings.bestOf))
                }

                // 添加beam_size参数
                if context.settings.beamSize != 5 {
                    arguments.append("--beam_size")
                    arguments.append(String(context.settings.beamSize))
                }

                // FP16默认启用，仅在用户禁用时传递--no_fp16
                if !context.settings.useFP16 {
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

                // 先删除之前可能存在的 transcription.txt，避免读取旧数据
                try? FileManager.default.removeItem(at: segmentOutputPath)

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var stdoutBuffer = ""
                    var stderrBuffer = ""

                    let stdoutHandle = stdoutPipe.fileHandleForReading
                    let stderrHandle = stderrPipe.fileHandleForReading

                    stdoutHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            let output = String(data: data, encoding: .utf8) ?? ""
                            stdoutBuffer += output
                        }
                    }

                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            let output = String(data: data, encoding: .utf8) ?? ""
                            stderrBuffer += output
                        }
                    }

                    process.terminationHandler = { proc in
                        stdoutHandle.readabilityHandler = nil
                        stderrHandle.readabilityHandler = nil
                        stdoutPipe.fileHandleForReading.closeFile()
                        stderrPipe.fileHandleForReading.closeFile()

                        if proc.terminationStatus == 0 {
                            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                                // 优先尝试读取文件，如果文件不存在则使用 stdout
                                var rawText = ""
                                if FileManager.default.fileExists(atPath: segmentOutputPath.path) {
                                    do {
                                        rawText = try String(contentsOf: segmentOutputPath, encoding: .utf8)
                                        print("[TranscriptionStage] Segment \(segmentIndex) read from file, length: \(rawText.count)")
                                    } catch {
                                        print("[TranscriptionStage] Failed to read segment file, using stdout: \(error)")
                                    }
                                }

                                // 如果文件为空或不存在，使用 stdout
                                if rawText.isEmpty && !stdoutBuffer.isEmpty {
                                    rawText = stdoutBuffer
                                    print("[TranscriptionStage] Segment \(segmentIndex) read from stdout, length: \(rawText.count)")
                                }

                                if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    let segments = WhisperService.parseSegmentsStatic(from: rawText)
                                    print("[TranscriptionStage] Segment \(segmentIndex) completed, parsed segments: \(segments.count)")
                                    allSegments.append(contentsOf: segments)
                                } else {
                                    print("[TranscriptionStage] Warning: Segment \(segmentIndex) produced empty output")
                                }
                                continuation.resume()
                            }
                        } else {
                            print("[TranscriptionStage] Segment \(segmentIndex) failed with exit code \(proc.terminationStatus)")
                            print("[TranscriptionStage] stderr: \(stderrBuffer)")
                            continuation.resume(throwing: WhisperError.transcriptionFailedWithMessage("分段\(segmentIndex)转录失败: \(stderrBuffer.prefix(200))"))
                        }
                    }

                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: WhisperError.notInstalled)
                    }
                }

                // 清理分段过程文件
                try? FileManager.default.removeItem(at: audioURL)
                try? FileManager.default.removeItem(at: segmentOutputPath)
            }
            
            // 合并并调整时间戳
            let mergedSegments = WhisperService.mergeAndAdjustTimestampsWithStartTimesStatic(
                segments: allSegments,
                segmentStartTimes: segmentStartTimes,
                segmentDuration: segmentDuration,
                overlapDuration: overlapDuration
            )
            
            // 生成合并后的转录文本
            let plainText = mergedSegments.map { $0.text }.joined(separator: "\n")
            let rawText = WhisperService.generateRawTextFromSegmentsStatic(segments: mergedSegments)
            
            // 写入最终输出文件
            let outputPath = tempDir.appendingPathComponent("transcription.txt")
            try rawText.write(to: outputPath, atomically: true, encoding: .utf8)
            
            let result = TranscriptionResult(
                text: plainText,
                rawText: rawText,
                segments: mergedSegments,
                outputPath: outputPath
            )
            
            context.transcriptionResult = result
            context.reportProgress(0.60, description: "分段转录完成并合并")
        } else if let audioURL = context.audioURL {
            let result = try await WhisperService.shared.transcribe(
                audioURL: audioURL,
                model: whisperModel,
                outputDir: tempDir,
                settings: context.settings
            )
            context.transcriptionResult = result
            context.reportProgress(0.60, description: "语音转录完成")
        } else {
            throw ProcessingError.audioExtractionFailed
        }
    }
}

class AnalysisStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        guard context.outputType == .analysis || context.outputType == .report else {
            context.reportProgress(0.85, description: "跳过文本分析")
            return
        }
        guard let transcriptionResult = context.transcriptionResult else { throw ProcessingError.transcriptionFailed }

        context.reportProgress(0.65, description: "准备AI分析...")

        // 根据输出类型严格选择对应的提示词
        let prompt: String
        if context.outputType == .analysis {
            // 内容解析与摘要：严格使用 analysisPrompt
            prompt = context.settings.analysisPrompt
            print("[AnalysisStage] Using analysisPrompt for content analysis")
        } else if context.outputType == .report {
            // 会议报告：严格使用 meetingPrompt
            prompt = context.settings.meetingPrompt
            print("[AnalysisStage] Using meetingPrompt for meeting report")
        } else {
            throw ProcessingError.invalidOutputType
        }

        context.analysis = try await LLMService.shared.analyzeContent(
            transcription: transcriptionResult.text,
            prompt: prompt,
            settings: context.settings
        )

        context.reportProgress(0.80, description: "AI分析完成")
    }
}

class ScreenshotExtractionStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        // 检查用户是否启用了截图功能
        guard context.settings.enableScreenshots else {
            print("[ScreenshotExtractionStage] Screenshots disabled in settings, skipping")
            context.reportProgress(0.80, description: "截图已禁用，跳过")
            return
        }
        
        guard !AppConstants.supportedAudioFormats.contains(context.fileExtension) else { return }
        guard context.outputType == .analysis || context.outputType == .report else { return }

        let currentOutputPath = context.settings.outputPath
        let finalOutputDir = URL(fileURLWithPath: currentOutputPath.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let taskOutputDir = finalOutputDir.appendingPathComponent(context.baseName)
        let imagesDir = taskOutputDir.appendingPathComponent("images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        do {
            let videoInfo = try await FFmpegService.shared.getVideoInfo(context.fileURL)
            let duration = videoInfo.duration
            let interval = 60.0
            var currentTime = 1.0
            var extractedCount = 0
            let totalExpected = Int(duration / interval) + 1

            while currentTime < duration {
                let progress = 0.75 + (Double(extractedCount) / Double(totalExpected)) * 0.05
                context.reportProgress(progress, description: "提取截图 \(extractedCount + 1)/\(totalExpected)...")

                let frameURL = try? await FFmpegService.shared.extractFrame(
                    at: currentTime,
                    from: context.fileURL,
                    outputDir: imagesDir
                )
                if let url = frameURL {
                    context.screenshotURLs.append(url)
                }
                extractedCount += 1
                currentTime += interval
            }
            context.reportProgress(0.80, description: "截图提取完成")
        } catch {
            print("Screenshot extraction failed: \(error)")
        }
    }
}

class ReportGenerationStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        context.reportProgress(0.82, description: "准备生成报告...")

        let currentOutputPath = context.settings.outputPath
        guard !currentOutputPath.isEmpty else {
            throw ProcessingError.outputPathNotConfigured
        }
        
        let finalOutputDir = URL(fileURLWithPath: currentOutputPath.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        try FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true)

        // 所有输出类型都创建同名文件夹
        let taskOutputDir = finalOutputDir.appendingPathComponent(context.baseName)
        try FileManager.default.createDirectory(at: taskOutputDir, withIntermediateDirectories: true)
        
        // 将原始音视频文件移动到同名文件夹中
        try await moveOriginalFileToOutputDir(context: context, outputDir: taskOutputDir)

        context.reportProgress(0.85, description: "生成原始转录文本...")
        try await generateAudioMD(context: context, outputDir: taskOutputDir)

        switch context.outputType {
        case .subtitle:
            context.reportProgress(0.90, description: "生成字幕文件...")
            try await generateSubtitle(context: context, outputDir: taskOutputDir)
        case .analysis:
            context.reportProgress(0.90, description: "生成分析报告...")
            try await generateAnalysis(context: context, outputDir: taskOutputDir)
        case .report:
            context.reportProgress(0.90, description: "生成会议报告...")
            try await generateReport(context: context, outputDir: taskOutputDir)
        }

        context.reportProgress(0.95, description: "生成元数据...")
        try await generateMetadata(context: context, outputDir: taskOutputDir)

        context.reportProgress(1.0, description: "处理完成")
    }

    private func moveOriginalFileToOutputDir(context: ProcessingContext, outputDir: URL) async throws {
        let fileName = context.fileName
        let destinationURL = outputDir.appendingPathComponent(fileName)
        
        // 如果文件已经在目标目录中，不需要移动
        if context.fileURL.deletingLastPathComponent() == outputDir {
            print("[ReportGenerationStage] File already in output directory")
            return
        }
        
        // 如果目标位置已存在同名文件，先删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // 移动文件到输出目录
        try FileManager.default.moveItem(at: context.fileURL, to: destinationURL)
        print("[ReportGenerationStage] Moved original file to: \(destinationURL.path)")
    }

    private func generateAudioMD(context: ProcessingContext, outputDir: URL) async throws {
        guard let transcriptionResult = context.transcriptionResult else {
            print("[ProcessingStages] Error: No transcription result found")
            throw ProcessingError.transcriptionFailed
        }

        let audioMDURL = outputDir.appendingPathComponent("audio.md")

        var content = "# 原始转录文本\n\n"

        let segments = transcriptionResult.segments
        print("[ProcessingStages] Generating audio.md with \(segments.count) segments")

        let processedSegments = mergeSegmentsIntoSentences(segments)

        var writtenCount = 0
        for segment in processedSegments {
            let normalizedText = normalizeTranscriptionText(segment.text)
            if normalizedText.isEmpty { continue }

            writtenCount += 1
            content += "\(writtenCount)\n"
            content += "\(formatSRTTime(segment.startTime)) --> \(formatSRTTime(segment.endTime))\n"
            content += "\(normalizedText)\n\n"
        }

        if writtenCount == 0 {
            print("[ProcessingStages] Warning: No segments were written to audio.md (original segments: \(segments.count))")
            if segments.count > 0 {
                content += "> (所有转录内容在规范化过程中被过滤，可能是因为仅包含标点或违规词)\n\n"
            } else {
                content += "> (未发现有效的转录片段)\n\n"
            }
        }

        content += """
        ---

        *生成时间: \(Date().formatted())*
        """

        try content.write(to: audioMDURL, atomically: true, encoding: .utf8)
        context.generatedFiles.append(audioMDURL)
    }

    private func isLikelyForeignLanguage(_ text: String) -> Bool {
        let latinChars = CharacterSet(charactersIn: "a-zA-Z")
        let cjkChars = CharacterSet(charactersIn: "\u{4e00}-\u{9fff}\u{3400}-\u{4dbf}\u{f900}-\u{faff}")
        
        var latinCount = 0
        var cjkCount = 0
        
        for char in text.unicodeScalars {
            if latinChars.contains(char) { latinCount += 1 }
            if cjkChars.contains(char) { cjkCount += 1 }
        }
        
        return latinCount > cjkCount && latinCount > 0
    }

    private func mergeSegmentsIntoSentences(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        guard !segments.isEmpty else { return [] }
        
        let allText = segments.map { $0.text }.joined(separator: " ")
        if !isLikelyForeignLanguage(allText) { return segments }
        
        var result: [TranscriptionSegment] = []
        var currentGroupStartIndex = 0
        var currentGroupText = ""
        
        for i in 0..<segments.count {
            let segText = segments[i].text.trimmingCharacters(in: .whitespaces)
            
            if currentGroupText.isEmpty {
                currentGroupText = segText
            } else {
                currentGroupText += " " + segText
            }
            
            let trimmedEnd = currentGroupText.trimmingCharacters(in: .whitespaces)
            let endsWithSentenceBoundary = trimmedEnd.hasSuffix(".") ||
                                           trimmedEnd.hasSuffix("!") ||
                                           trimmedEnd.hasSuffix("?") ||
                                           trimmedEnd.hasSuffix(".\"") ||
                                           trimmedEnd.hasSuffix("!\")" ) ||
                                           trimmedEnd.hasSuffix("?\")" )
            
            let wordCount = currentGroupText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            
            if endsWithSentenceBoundary || wordCount >= 30 {
                let splitParts = splitLongSentenceByGrammar(currentGroupText, maxWords: 25)
                
                for (partIdx, part) in splitParts.enumerated() {
                    let startTime: String
                    let endTime: String
                    
                    if partIdx == 0 && splitParts.count == 1 {
                        startTime = segments[currentGroupStartIndex].startTime
                        endTime = segments[i].endTime
                    } else if partIdx == 0 {
                        startTime = segments[currentGroupStartIndex].startTime
                        endTime = segments[min(i, segments.count - 1)].startTime
                    } else {
                        startTime = segments[min(i, segments.count - 1)].startTime
                        endTime = segments[i].endTime
                    }
                    
                    result.append(TranscriptionSegment(
                        startTime: startTime,
                        endTime: endTime,
                        speaker: segments[currentGroupStartIndex].speaker,
                        text: part
                    ))
                }
                
                currentGroupStartIndex = i + 1
                currentGroupText = ""
            }
        }
        
        if !currentGroupText.isEmpty {
            let lastSeg = segments[max(0, currentGroupStartIndex)]
            let endSeg = segments[segments.count - 1]
            result.append(TranscriptionSegment(
                startTime: lastSeg.startTime,
                endTime: endSeg.endTime,
                speaker: lastSeg.speaker,
                text: currentGroupText
            ))
        }
        
        print("[ProcessingStages] Merged \(segments.count) raw segments into \(result.count) sentence-based segments")
        return result
    }

    private func splitLongSentenceByGrammar(_ sentence: String, maxWords: Int) -> [String] {
        let words = sentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard words.count > maxWords else { return [sentence] }
        
        var parts: [String] = []
        var currentPart: [String] = []
        
        let clauseBreakers = Set([
            ",", ";", ":", "--", "-",
            "and", "but", "or", "nor", "for", "so", "yet",
            "although", "though", "because", "since", "while",
            "when", "where", "if", "unless", "until",
            "that", "which", "who", "whom", "whose",
            "however", "therefore", "moreover", "furthermore",
            "in", "on", "at", "by", "with", "from", "to", "of",
            "also", "then", "next", "finally", "first", "second"
        ])
        
        for word in words {
            currentPart.append(word)
            
            let lowerWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let isClauseBreaker = clauseBreakers.contains(lowerWord)
            let endsWithComma = word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":")
            
            if (isClauseBreaker || endsWithComma) && currentPart.count >= maxWords / 2 {
                parts.append(currentPart.joined(separator: " "))
                currentPart = []
            } else if currentPart.count >= maxWords {
                parts.append(currentPart.joined(separator: " "))
                currentPart = []
            }
        }
        
        if !currentPart.isEmpty {
            parts.append(currentPart.joined(separator: " "))
        }
        
        return parts.isEmpty ? [sentence] : parts
    }

    private func normalizeTranscriptionText(_ text: String) -> String {
        var cleaned = text
        
        // 1. 去除标点符号，用空格代替（规范第6条）
        let punctuation = CharacterSet.punctuationCharacters.union(CharacterSet(charactersIn: "，。！？；：\"\"''（）【】《》"))
        cleaned = cleaned.components(separatedBy: punctuation).joined(separator: " ")
        
        // 2. 去除句首语气词（规范第7条）
        let leadingFillers = ["噢", "啊", "哎呀", "喂"]
        var words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if !words.isEmpty {
            for filler in leadingFillers {
                if words[0] == filler {
                    words.removeFirst()
                    break
                }
            }
        }
        cleaned = words.joined(separator: " ")
        
        // 3. 过滤脏话（规范第14条）
        cleaned = cleaned.replacingOccurrences(of: "他妈的", with: "")
        cleaned = cleaned.replacingOccurrences(of: "妈的", with: "")
        
        // 4. 处理重复语句（规范第9条：超过三遍以上只上三次）
        let components = cleaned.components(separatedBy: " ").filter { !$0.isEmpty }
        var resultComponents: [String] = []
        if !components.isEmpty {
            var currentWord = ""
            var count = 0
            for word in components {
                if word == currentWord {
                    count += 1
                    if count <= 3 {
                        resultComponents.append(word)
                    }
                } else {
                    currentWord = word
                    count = 1
                    resultComponents.append(word)
                }
            }
        }
        cleaned = resultComponents.joined(separator: " ")
        
        // 5. 数字处理（规范第8条：年代、房间号用阿拉伯数字，其余尽量汉字）
        cleaned = convertNumbersToChinese(cleaned)
        
        // 6. 修正“的、地、得”（规范第10条：简化处理，根据语境微调，这里做基础去重或修正）
        // 这是一个复杂的NLP任务，此处仅做最基础的空格清理
        
        return cleaned.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func convertNumbersToChinese(_ text: String) -> String {
        let pattern = "\\d+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        var result = text
        let chineseNumbers = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        
        // 从后往前替换，避免偏移问题
        for match in matches.reversed() {
            let numberStr = nsString.substring(with: match.range)
            
            // 规范：年代（4位）、房间号（通常包含在特定上下文）用阿拉伯数字
            // 这里简单判断：4位数字认为是年代，不转换
            if numberStr.count == 4 { continue }
            
            // 房间号判断：如果前后有“房”、“室”、“号”，不转换
            let start = match.range.location
            let end = match.range.location + match.range.length
            
            if start > 0 {
                let prevChar = nsString.substring(with: NSRange(location: start - 1, length: 1))
                if ["房", "室", "号"].contains(prevChar) { continue }
            }
            if end < nsString.length {
                let nextChar = nsString.substring(with: NSRange(location: end, length: 1))
                if ["房", "室", "号"].contains(nextChar) { continue }
            }
            
            // 其他数字尝试转换为汉字（简单处理 0-99）
            if let val = Int(numberStr) {
                var chinese = ""
                if val < 10 {
                    chinese = chineseNumbers[val]
                } else if val < 20 {
                    chinese = "十" + (val % 10 == 0 ? "" : chineseNumbers[val % 10])
                } else if val < 100 {
                    chinese = chineseNumbers[val / 10] + "十" + (val % 10 == 0 ? "" : chineseNumbers[val % 10])
                } else {
                    // 超过100的数字暂时保留，或者逐位转换
                    continue 
                }
                
                let range = Range(match.range, in: result)!
                result.replaceSubrange(range, with: chinese)
            }
        }
        
        return result
    }

    private func splitTextIntoLines(_ text: String, maxChars: Int) -> [String] {
        var lines: [String] = []
        let components = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var currentLine = ""
        for component in components {
            if currentLine.isEmpty {
                currentLine = component
            } else if (currentLine.count + 1 + component.count) <= maxChars {
                currentLine += " " + component
            } else {
                lines.append(currentLine)
                currentLine = component
            }
            
            // 如果单个单词/片段就超过了限制，强制拆分
            while currentLine.count > maxChars {
                let index = currentLine.index(currentLine.startIndex, offsetBy: maxChars)
                lines.append(String(currentLine[..<index]))
                currentLine = String(currentLine[index...])
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.isEmpty ? [text] : lines
    }

    private func formatSRTTime(_ timeString: String) -> String {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else {
            return "00:00:00,000"
        }
        let hours = components[0]
        let minutes = components[1]
        let secondsAndMs = components[2]

        if secondsAndMs.contains(".") {
            let parts = secondsAndMs.components(separatedBy: ".")
            let secs = parts[0]
            let ms = parts.count > 1 ? String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0) : "000"
            return "\(hours):\(minutes):\(secs),\(ms)"
        } else if secondsAndMs.contains(",") {
            let parts = secondsAndMs.components(separatedBy: ",")
            let secs = parts[0]
            let ms = parts.count > 1 ? String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0) : "000"
            return "\(hours):\(minutes):\(secs),\(ms)"
        } else {
            return "\(hours):\(minutes):\(secondsAndMs),000"
        }
    }

    private func generateSubtitle(context: ProcessingContext, outputDir: URL) async throws {
        guard let transcriptionResult = context.transcriptionResult else { throw ProcessingError.transcriptionFailed }

        let targetLanguage = context.settings.subtitleTargetLanguage

        context.reportProgress(0.87, description: "步骤1/3：复制audio.md并转换为translation.srt格式...")

        let audioMDURL = outputDir.appendingPathComponent("audio.md")
        guard FileManager.default.fileExists(atPath: audioMDURL.path) else {
            print("[ProcessingStages] Error: audio.md not found at \(audioMDURL.path)")
            throw ProcessingError.transcriptionFailed
        }

        let audioMDContent = try String(contentsOf: audioMDURL, encoding: .utf8)
        let segments = parseAudioMDToSegments(audioMDContent)

        print("[ProcessingStages] Parsed \(segments.count) segments from audio.md")

        var srtContent = ""
        for (index, segment) in segments.enumerated() {
            srtContent += "\(index + 1)\n"
            srtContent += "\(segment.startTime) --> \(segment.endTime)\n"
            // 清理并自动换行：保持每行字数在18-25字之间，最多两行
            let cleanedText = cleanSubtitleText(segment.text)
            let wrappedText = wrapSubtitleText(cleanedText, minChars: 18, maxChars: 25)
            srtContent += "\(wrappedText)\n\n"
        }

        let translationSRTURL = outputDir.appendingPathComponent("translation.srt")
        try srtContent.write(to: translationSRTURL, atomically: true, encoding: .utf8)
        print("[ProcessingStages] Step 1 completed: Created translation.srt with \(segments.count) entries")

        context.reportProgress(0.90, description: "步骤2/3：使用LLM翻译为目标语言(\(targetLanguage))...")

        let transcriptionSegments = segments.map { segment in
            TranscriptionSegment(
                startTime: segment.startTime,
                endTime: segment.endTime,
                speaker: "",
                text: segment.text
            )
        }

        let translatedSegments = try await LLMService.shared.translateSegmentsToTargetLanguage(
            segments: transcriptionSegments,
            targetLanguage: targetLanguage,
            settings: context.settings
        )

        print("[ProcessingStages] Step 2 completed: Translated \(translatedSegments.count) segments to \(targetLanguage)")

        var translatedSRTContent = ""
        for (index, segment) in translatedSegments.enumerated() {
            translatedSRTContent += "\(index + 1)\n"
            translatedSRTContent += "\(segment.startTime) --> \(segment.endTime)\n"
            // 清理翻译结果并自动换行：保持每行字数在18-25字之间，最多两行
            let cleanedText = cleanSubtitleText(segment.text)
            let wrappedText = wrapSubtitleText(cleanedText, minChars: 18, maxChars: 25)
            translatedSRTContent += "\(wrappedText)\n\n"
        }

        try translatedSRTContent.write(to: translationSRTURL, atomically: true, encoding: .utf8)
        context.generatedFiles.append(translationSRTURL)

        context.reportProgress(0.93, description: "步骤3/3：二次校验翻译完整性...")

        try await verifyTranslationCompleteness(
            fileURL: translationSRTURL,
            originalSegments: segments,
            targetLanguage: targetLanguage,
            settings: context.settings
        )

        print("[ProcessingStages] ✅ All 3 steps completed: translation.srt generated and verified")
    }

    private struct ParsedSegment {
        let startTime: String
        let endTime: String
        let text: String
    }

    private func parseAudioMDToSegments(_ content: String) -> [ParsedSegment] {
        var segments: [ParsedSegment] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("---") || line.hasPrefix("*") {
                i += 1
                continue
            }

            if let indexNum = Int(line), indexNum > 0 {
                if i + 1 < lines.count {
                    let timeLine = lines[i + 1].trimmingCharacters(in: .whitespaces)

                    if timeLine.contains("-->") {
                        let timeParts = timeLine.components(separatedBy: " --> ")
                        if timeParts.count == 2 {
                            let startTime = timeParts[0].trimmingCharacters(in: .whitespaces)
                            let endTime = timeParts[1].trimmingCharacters(in: .whitespaces)

                            // 收集多行文本，直到遇到空行或下一个序号
                            var textLines: [String] = []
                            var j = i + 2
                            while j < lines.count {
                                let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                                if nextLine.isEmpty {
                                    break
                                }
                                if let _ = Int(nextLine), nextLine == String(j - i - 2 + 1) {
                                    // 可能是下一个序号
                                    break
                                }
                                if nextLine.hasPrefix("#") || nextLine.hasPrefix("---") || nextLine.hasPrefix("*") || nextLine.hasPrefix(">") {
                                    break
                                }
                                textLines.append(lines[j])
                                j += 1
                            }

                            let text = textLines.joined(separator: "\n")
                            if !text.isEmpty {
                                segments.append(ParsedSegment(
                                    startTime: startTime,
                                    endTime: endTime,
                                    text: text
                                ))
                            }
                            i = j
                            continue
                        }
                    }
                    i += 1
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }

        return segments
    }

    private func verifyTranslationCompleteness(
        fileURL: URL,
        originalSegments: [ParsedSegment],
        targetLanguage: String,
        settings: AppSettings
    ) async throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let entries = parseSRTFile(content)

        print("[ProcessingStages] 🔍 Starting optimized verification: \(entries.count) entries, target: \(targetLanguage)")

        guard entries.count == originalSegments.count else {
            print("[ProcessingStages] ⚠️ Entry count mismatch: \(entries.count) != \(originalSegments.count)")
            return
        }

        var level1Pass: [SubtitleEntry] = []
        var level2Candidates: [(Int, SubtitleEntry)] = []

        for (index, entry) in entries.enumerated() {
            let originalText = originalSegments[index].text.trimmingCharacters(in: .whitespaces)
            let currentText = entry.content.trimmingCharacters(in: .whitespaces)

            if currentText.isEmpty || currentText.lowercased() == originalText.lowercased() {
                level2Candidates.append((index, entry))
            } else {
                level1Pass.append(entry)
            }
        }

        print("[ProcessingStages] Level 1 (quick): \(level1Pass.count) passed, \(level2Candidates.count) need deeper check")

        var level2Pass: [SubtitleEntry] = []
        var level3Candidates: [(Int, SubtitleEntry)] = []

        for (index, entry) in level2Candidates {
            let originalText = originalSegments[index].text.trimmingCharacters(in: .whitespaces)
            let currentText = entry.content.trimmingCharacters(in: .whitespaces)

            let hasForeignChars = containsForeignLanguageCharacters(text: currentText, targetLanguage: targetLanguage)
            let similarity = calculateTextSimilarity(text1: currentText, text2: originalText)

            if !hasForeignChars && similarity < 0.7 {
                level2Pass.append(entry)
            } else {
                level3Candidates.append((index, entry))
            }
        }

        print("[ProcessingStages] Level 2 (medium): +\(level2Pass.count) passed, \(level3Candidates.count) need deep check")

        var finalEntries = level1Pass + level2Pass

        if !level3Candidates.isEmpty {
            let fixedEntries = try await batchFixProblematicEntries(
                candidates: level3Candidates,
                originalSegments: originalSegments,
                targetLanguage: targetLanguage,
                settings: settings
            )
            finalEntries += fixedEntries
        }

        finalEntries.sort { $0.index < $1.index }

        let correctedContent = generateSRTContent(finalEntries)
        try correctedContent.write(to: fileURL, atomically: true, encoding: .utf8)

        print("[ProcessingStages] ✅ Optimized verification completed:")
        print("[ProcessingStages]    - Total: \(entries.count)")
        print("[ProcessingStages]    - L1 quick pass: \(level1Pass.count)")
        print("[ProcessingStages]    - L2 medium pass: \(level2Pass.count)")
        print("[ProcessingStages]    - L3 deep fix: \(level3Candidates.count)")
    }

    private func batchFixProblematicEntries(
        candidates: [(Int, SubtitleEntry)],
        originalSegments: [ParsedSegment],
        targetLanguage: String,
        settings: AppSettings
    ) async throws -> [SubtitleEntry] {
        let problematicSegments = candidates.map { (index, entry) in
            TranscriptionSegment(
                startTime: entry.startTime,
                endTime: entry.endTime,
                speaker: "",
                text: originalSegments[index].text
            )
        }

        let maxBatchSize = 15
        var allFixed: [Int: SubtitleEntry] = [:]

        for batchStart in stride(from: 0, to: problematicSegments.count, by: maxBatchSize) {
            let batchEnd = min(batchStart + maxBatchSize, problematicSegments.count)
            let batch = Array(problematicSegments[batchStart..<batchEnd])
            let batchIndices = Array(candidates[batchStart..<batchEnd].map { $0.0 })

            do {
                let retranslated = try await LLMService.shared.translateSegmentsToTargetLanguage(
                    segments: batch,
                    targetLanguage: targetLanguage,
                    settings: settings
                )

                for (localIdx, translated) in retranslated.enumerated() {
                    let globalIdx = batchIndices[localIdx]
                    let entry = candidates.first(where: { $0.0 == globalIdx })!.1
                    allFixed[globalIdx] = SubtitleEntry(
                        index: entry.index,
                        startTime: entry.startTime,
                        endTime: entry.endTime,
                        content: translated.text
                    )
                }
            } catch {
                print("[ProcessingStaces] ⚠️ Batch re-translation failed, using best effort cleanup")
                for localIdx in 0..<batch.count {
                    let globalIdx = batchIndices[localIdx]
                    let entry = candidates.first(where: { $0.0 == globalIdx })!.1
                    allFixed[globalIdx] = SubtitleEntry(
                        index: entry.index,
                        startTime: entry.startTime,
                        endTime: entry.endTime,
                        content: cleanBestEffortTranslation(entry.content)
                    )
                }
            }
        }

        return candidates.compactMap { (index, _) in allFixed[index] }
    }

    private func detectTranslationIssues(
        translatedText: String,
        originalText: String,
        targetLanguage: String
    ) -> [String] {
        var issues: [String] = []

        if translatedText.isEmpty {
            issues.append("empty_translation")
            return issues
        }

        let cleanTranslated = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanTranslated.lowercased() == cleanOriginal.lowercased() {
            issues.append("not_translated_identical")
            return issues
        }

        if cleanTranslated.contains(cleanOriginal) && cleanOriginal.count > 3 {
            issues.append("contains_original_text")
        }

        if cleanTranslated.contains("->") || cleanTranslated.contains("→") || cleanTranslated.contains("-> ") {
            let parts = cleanTranslated.components(separatedBy: CharacterSet(charactersIn: "->→"))
            if parts.count >= 2 {
                let firstPart = parts[0].trimmingCharacters(in: .whitespaces)
                if firstPart.lowercased() == cleanOriginal.lowercased() || firstPart.count > 0 {
                    issues.append("arrow_format_with_original")
                }
            }
        }

        if containsForeignLanguageCharacters(text: cleanTranslated, targetLanguage: targetLanguage) {
            issues.append("contains_foreign_characters")
        }

        if detectMixedLanguagePattern(text: cleanTranslated) {
            issues.append("mixed_language_pattern")
        }

        let similarity = calculateTextSimilarity(text1: cleanTranslated, text2: cleanOriginal)
        if similarity > 0.7 {
            issues.append("high_similarity_to_original(\(Int(similarity * 100))%)")
        }

        return issues
    }

    private func containsForeignLanguageCharacters(text: String, targetLanguage: String) -> Bool {
        let latinChars = CharacterSet(charactersIn: "a-zA-ZàâäéèêëïîôùûüÿœæçÀÂÄÉÈÊËÏÎÔÙÛÜŸŒÆÇ")
        let cjkChars = CharacterSet(charactersIn: "\u{4e00}-\u{9fff}\u{3400}-\u{4dbf}\u{f900}-\u{faff}\u{3040}-\u{309f}\u{30a0}-\u{30ff}")

        switch targetLanguage {
        case "Chinese":
            var foreignCharCount = 0
            var totalCharCount = 0
            let whitespaceChars = CharacterSet.whitespaces
            let punctuationChars = CharacterSet(charactersIn: "\u{FF0C}\u{3001}\u{3002}\u{FF01}\u{FF1F}\u{FF1B}\u{FF1A}\u{201C}\u{201D}\u{2018}\u{2019}\u{FF08}\u{FF09}\u{3010}\u{3011}\u{300A}\u{300B}\u{2014}\u{2026}\u{00B7}")

            for char in text.unicodeScalars {
                let isWhitespace = whitespaceChars.contains(char)
                let isPunctuation = punctuationChars.contains(char)

                if !char.isASCII && !isWhitespace && !isPunctuation {
                    if !cjkChars.contains(char) {
                        foreignCharCount += 1
                    }
                    totalCharCount += 1
                } else if char.isASCII && !isWhitespace && char != Unicode.Scalar(44) && char != Unicode.Scalar(46) && char != Unicode.Scalar(63) && char != Unicode.Scalar(33) {
                    let asciiStr = String(char)
                    if asciiStr.range(of: "[a-zA-Z]", options: .regularExpression) != nil {
                        foreignCharCount += asciiStr.count
                        totalCharCount += asciiStr.count
                    }
                }
            }

            if totalCharCount > 0 {
                let foreignRatio = Double(foreignCharCount) / Double(totalCharCount)
                return foreignRatio > 0.15
            }

        case "English", "French", "German", "Spanish":
            var cjkCharCount = 0
            var totalAlphaCount = 0
            let letterChars = CharacterSet.letters

            for char in text.unicodeScalars {
                if cjkChars.contains(char) {
                    cjkCharCount += 1
                }
                if letterChars.contains(char) {
                    totalAlphaCount += 1
                }
            }

            if totalAlphaCount > 0 {
                let cjkRatio = Double(cjkCharCount) / Double(totalAlphaCount)
                return cjkRatio > 0.15
            }

        default:
            break
        }

        return false
    }

    private func detectMixedLanguagePattern(text: String) -> Bool {
        let patterns = [
            "\\b(Le|La|Les|De|Des|Du|Un|Une|Et|En|Ou|Ne|Pas|Est|Sont|Avoir|Être|Pour|Dans|Sur|Avec|Sans|Chez|Par|Entre|Vers|Sous|Comme|Mais|Donc|Alors|Lorsque|Puisque|Quand|Si|Que|Qui|Ce|Cela|Ceci|Tout|Autre|Même|Bien|Plus|Très|Trop|Peu|Beaucoup|Encore|Déjà|Toujours|Jamais|Souvent|Parfois|Ici|Là|Maintenant|Aujourd\\'hui|Demain|Hier|Bonjour|Bonsoir|Merci|Excusez|S\\'il|N\\'|J\\'|L\\'|Qu\\')\\b",
            "\\b(The|This|That|These|Those|Is|Are|Was|Were|Have|Has|Had|Will|Would|Could|Should|May|Might|Can|Shall|Must|Do|Does|Did|Not|No|Yes|And|Or|But|If|When|Where|What|Which|Who|Whom|Whose|How|Why|For|With|Without|From|To|At|In|On|By|About|Of|Over|Under|Between|Through|During|Before|After|While|Although|Though|Because|Since|Until|Unless|However|Therefore|Moreover|Furthermore|Nevertheless|Nonetheless|Otherwise|Instead|Also|Too|Very|Quite|Rather|Somewhat|Almost|Nearly|Just|Only|Even|Still|Yet|Already|Always|Never|Often|Sometimes|Here|There|Now|Then|Today|Tomorrow|Yesterday|Please|Thank|Hello|Goodbye)\\b"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.numberOfMatches(in: text, options: [], range: range)
                if matches > 2 {
                    return true
                }
            }
        }

        return false
    }

    private func calculateTextSimilarity(text1: String, text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })

        if words1.isEmpty || words2.isEmpty { return 0.0 }

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        return Double(intersection.count) / Double(union.count)
    }

    private func cleanBestEffortTranslation(_ text: String) -> String {
        var cleaned = text

        if cleaned.contains("->") || cleaned.contains("→") {
            let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: "->→"))
            if parts.count >= 2 {
                cleaned = parts.last?.trimmingCharacters(in: .whitespaces) ?? cleaned
            }
        }

        let patternsToRemove = [
            "^.*?->\\s*",
            "\\(.*?\\)",
            "\\[.*?\\]",
            "^译文[:：]\\s*",
            "^翻译[:：]\\s*"
        ]

        for pattern in patternsToRemove {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct SubtitleEntry {
        let index: Int
        let startTime: String
        let endTime: String
        let content: String
    }

    private func parseSRTFile(_ content: String) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []
        let blocks = content.components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard lines.count >= 3 else { continue }
            
            guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }
            
            let timeLine = lines[1]
            let timeParts = timeLine.components(separatedBy: " --> ")
            guard timeParts.count == 2 else { continue }
            
            let startTime = timeParts[0].trimmingCharacters(in: .whitespaces)
            let endTime = timeParts[1].trimmingCharacters(in: .whitespaces)
            
            let contentLines = Array(lines[2...])
            let content = contentLines.joined(separator: "\n")
            
            entries.append(SubtitleEntry(
                index: index,
                startTime: startTime,
                endTime: endTime,
                content: content
            ))
        }
        
        return entries
    }

    private func parseVTTFile(_ content: String) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []
        var lines = content.components(separatedBy: "\n")
        
        if !lines.isEmpty && lines[0].hasPrefix("WEBVTT") {
            lines = Array(lines.dropFirst())
        }
        
        var currentIndex = 1
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            if line.isEmpty {
                i += 1
                continue
            }
            
            if line.contains("-->") {
                let timeParts = line.components(separatedBy: " --> ")
                guard timeParts.count == 2 else { i += 1; continue }
                
                let startTime = timeParts[0].trimmingCharacters(in: .whitespaces)
                let endTime = timeParts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? timeParts[1]
                
                var contentLines: [String] = []
                var j = i + 1
                while j < lines.count {
                    let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if nextLine.isEmpty || nextLine.contains("-->") {
                        break
                    }
                    contentLines.append(lines[j])
                    j += 1
                }
                
                let content = contentLines.joined(separator: "\n")
                
                entries.append(SubtitleEntry(
                    index: currentIndex,
                    startTime: startTime,
                    endTime: endTime,
                    content: content
                ))
                
                currentIndex += 1
                i = j
            } else {
                i += 1
            }
        }
        
        return entries
    }

    private func generateSRTContent(_ entries: [SubtitleEntry]) -> String {
        var lines: [String] = []
        
        for entry in entries {
            lines.append("\(entry.index)")
            lines.append("\(entry.startTime) --> \(entry.endTime)")
            lines.append(entry.content)
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }

    private func generateVTTContent(_ entries: [SubtitleEntry]) -> String {
        var lines: [String] = ["WEBVTT", ""]
        
        for entry in entries {
            lines.append("\(entry.startTime) --> \(entry.endTime)")
            lines.append(entry.content)
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }

    private func generateAnalysis(context: ProcessingContext, outputDir: URL) async throws {
        guard let transcriptionResult = context.transcriptionResult,
              let analysis = context.analysis else { throw ProcessingError.transcriptionFailed }

        let analysisURLs = try await ReportService.shared.generateAnalysisReport(
            transcription: transcriptionResult.text,
            rawTranscription: transcriptionResult.rawText,
            analysis: analysis,
            outputDir: outputDir,
            screenshotURLs: context.screenshotURLs
        )
        context.generatedFiles.append(contentsOf: analysisURLs)
    }

    private func generateReport(context: ProcessingContext, outputDir: URL) async throws {
        guard let transcriptionResult = context.transcriptionResult,
              let analysis = context.analysis else { throw ProcessingError.transcriptionFailed }

        // 检查模板路径是否配置
        if context.settings.templatePath.isEmpty {
            print("[ReportGenerationStage] Template path not configured, pausing queue for user selection")
            // 暂停队列并提示用户选择模板
            if let currentTask = TaskQueueManager.shared.currentTask {
                TaskQueueManager.shared.pauseForTemplateSelection(task: currentTask)
            }
            throw ProcessingError.templatePathNotConfigured
        }

        // 使用 uploadTemplate 作为模板名称（如 "meeting"），templatePath 作为目录路径
        let templateName = context.settings.uploadTemplate.isEmpty ? "meeting" : context.settings.uploadTemplate
        let templateDirectoryPath = context.settings.templatePath
        
        print("[ReportGenerationStage] Using template: \(templateName) from path: \(templateDirectoryPath)")
        
        let reportURL = try await ReportService.shared.generateMeetingReport(
            transcription: transcriptionResult.text,
            analysis: analysis,
            templateName: templateName,
            outputDir: outputDir,
            templatePath: templateDirectoryPath
        )
        context.generatedFiles.append(reportURL)
    }

    private func generateMetadata(context: ProcessingContext, outputDir: URL) async throws {
        let metadataURL = outputDir.appendingPathComponent("metadata.json")
        let metadata: [String: Any] = [
            "fileName": context.fileName,
            "fileType": context.fileExtension,
            "fileSize": context.fileSize,
            "outputType": context.outputType.rawValue,
            "outputFiles": context.generatedFiles.map { $0.lastPathComponent },
            "screenshots": context.screenshotURLs.map { $0.lastPathComponent },
            "settings": [
                "whisperModel": context.settings.whisperModel,
                "llmService": context.settings.llmService,
                "analysisPrompt": context.settings.analysisPrompt
            ]
        ]

        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted) {
            try? metadataData.write(to: metadataURL)
            context.generatedFiles.append(metadataURL)
        }
    }
    
    /// 清理字幕文本，移除可能存在的非字幕内容（如 [x] 序号、括号注释等）
    private func cleanSubtitleText(_ text: String) -> String {
        var cleaned = text
        
        // 1. 移除首尾的方括号序号，如 "[0]"、"[1]" 等
        let bracketIndexPattern = "^\\[\\d+\\]\\s*"
        if let regex = try? NSRegularExpression(pattern: bracketIndexPattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // 2. 移除首尾引号
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) || (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // 3. 移除常见的 LLM 误加的标记和注释
        let noisePatterns = [
            "^序号[:：]\\s*\\d+\\s*",
            "^译文[:：]\\s*",
            "^翻译[:：]\\s*",
            "^结果[:：]\\s*",
            "\\(.*?翻译.*?\\)",
            "译文[:：].*$"
        ]
        
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        // 4. 移除行首可能误加的数字序号（如 "1. 内容"）
        let leadingNumberPattern = "^\\d+[\\.、\\s]+"
        if let regex = try? NSRegularExpression(pattern: leadingNumberPattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// 字幕文本自动换行，最多只分为上下两行，保持每行字数相当（18-25字之间）
    /// - 标点符号不允许单独占据一行
    private func wrapSubtitleText(_ text: String, minChars: Int = 18, maxChars: Int = 25) -> String {
        // 如果文本已经包含换行符，说明已经格式化过，直接返回
        if text.contains("\n") {
            return text
        }
        
        // 清理文本：去除首尾空白
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // 如果文本长度小于等于最大字符数，不需要换行
        if trimmed.count <= maxChars {
            return trimmed
        }
        
        // 标点符号集合（用于断行，但不能单独成行）
        let breakPunctuation: Set<Character> = ["，", "、", "；", "：", ",", ";", ":", " "]
        let endPunctuation: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        
        // 尝试找到最佳的断行位置
        // 目标：断在 minChars 到 maxChars 之间，且断点后的字符不是标点
        let totalLength = trimmed.count
        let idealBreakPos = totalLength / 2 // 理想断点位置（中间）
        
        // 搜索范围：在 idealBreakPos ± 一定的范围内寻找最佳断点
        let searchStart = max(minChars, idealBreakPos - 5)
        let searchEnd = min(maxChars, totalLength - minChars)
        
        // 如果总长度超过两行最大限制（50字），则强制断在 maxChars 处
        if totalLength > maxChars * 2 {
            return forceWrapTwoLines(trimmed, maxChars: maxChars, breakPunctuation: breakPunctuation, endPunctuation: endPunctuation)
        }
        
        // 在搜索范围内寻找最佳断点
        var bestBreakIndex: String.Index? = nil
        var bestScore = Int.max
        
        let searchStartIndex = trimmed.index(trimmed.startIndex, offsetBy: searchStart)
        let searchEndIndex = trimmed.index(trimmed.startIndex, offsetBy: searchEnd)
        
        var currentIndex = searchStartIndex
        while currentIndex <= searchEndIndex {
            let char = trimmed[currentIndex]
            if breakPunctuation.contains(char) {
                // 检查断点后的字符是否不是标点
                let nextIndex = trimmed.index(after: currentIndex)
                if nextIndex < trimmed.endIndex {
                    let nextChar = trimmed[nextIndex]
                    if !breakPunctuation.contains(nextChar) && !endPunctuation.contains(nextChar) {
                        // 计算评分：越接近理想断点位置越好
                        let distance = abs(trimmed.distance(from: trimmed.startIndex, to: currentIndex) - idealBreakPos)
                        if distance < bestScore {
                            bestScore = distance
                            bestBreakIndex = trimmed.index(after: currentIndex) // 断在标点之后
                        }
                    }
                }
            }
            currentIndex = trimmed.index(after: currentIndex)
        }
        
        // 如果没找到合适的标点断点，在 maxChars 附近的空格处断行
        if bestBreakIndex == nil {
            currentIndex = searchStartIndex
            while currentIndex <= searchEndIndex {
                let char = trimmed[currentIndex]
                if char == " " {
                    bestBreakIndex = trimmed.index(after: currentIndex)
                    break
                }
                currentIndex = trimmed.index(after: currentIndex)
            }
        }
        
        // 如果还是没有找到合适的断点，在中间位置强制断行
        if bestBreakIndex == nil {
            let midPos = totalLength / 2
            bestBreakIndex = trimmed.index(trimmed.startIndex, offsetBy: midPos)
        }
        
        // 生成分行结果
        if let breakIdx = bestBreakIndex {
            let firstLine = String(trimmed[..<breakIdx]).trimmingCharacters(in: .whitespaces)
            let secondLine = String(trimmed[breakIdx...]).trimmingCharacters(in: .whitespaces)
            
            // 检查第二行是否以标点开头，如果是则调整
            var adjustedFirstLine = firstLine
            var adjustedSecondLine = secondLine
            
            if let firstChar = secondLine.first {
                if breakPunctuation.contains(firstChar) || endPunctuation.contains(firstChar) {
                    // 将标点移到第一行末尾
                    adjustedFirstLine = firstLine + String(firstChar)
                    adjustedSecondLine = String(secondLine.dropFirst())
                }
            }
            
            // 检查第一行是否以标点结尾（不允许标点单独成行）
            // 这里不需要处理，因为第一行是前半部分
            
            // 确保两行长度合理
            if adjustedSecondLine.isEmpty {
                return adjustedFirstLine
            }
            
            return adjustedFirstLine + "\n" + adjustedSecondLine
        }
        
        return trimmed
    }
    
    /// 强制将文本分为两行，每行不超过 maxChars
    private func forceWrapTwoLines(_ text: String, maxChars: Int, breakPunctuation: Set<Character>, endPunctuation: Set<Character>) -> String {
        let breakPos = maxChars
        let breakIndex = text.index(text.startIndex, offsetBy: breakPos)
        
        var firstLine = String(text[..<breakIndex])
        var secondLine = String(text[breakIndex...])
        
        // 调整标点位置，确保标点不单独成行
        if let firstCharOfSecond = secondLine.first {
            if breakPunctuation.contains(firstCharOfSecond) {
                firstLine += String(firstCharOfSecond)
                secondLine = String(secondLine.dropFirst())
            } else if endPunctuation.contains(firstCharOfSecond) {
                firstLine += String(firstCharOfSecond)
                secondLine = String(secondLine.dropFirst())
            }
        }
        
        return firstLine + "\n" + secondLine
    }
}