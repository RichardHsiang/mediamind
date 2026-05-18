import Foundation

protocol ProcessingStage {
    func process(_ context: ProcessingContext) async throws
}

class FileValidationStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        context.tempDir = try FileService.shared.createTempDirectory()
        guard context.tempDir != nil else { throw ProcessingError.fileValidationFailed }

        _ = try FileService.shared.validateFile(context.fileURL)
    }
}

class AudioExtractionStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        if AppConstants.supportedAudioFormats.contains(context.fileExtension) {
            context.audioURL = context.fileURL
        } else {
            guard let tempDir = context.tempDir else { throw ProcessingError.fileValidationFailed }
            context.audioURL = try await FFmpegService.shared.extractAudio(
                from: context.fileURL,
                outputDir: tempDir,
                settings: context.settings
            )
        }
    }
}

class TranscriptionStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        guard let audioURL = context.audioURL else { throw ProcessingError.audioExtractionFailed }
        guard let tempDir = context.tempDir else { throw ProcessingError.fileValidationFailed }

        let whisperModel = context.settings.whisperModel == "auto" ? "base" : context.settings.whisperModel
        let result = try await WhisperService.shared.transcribe(
            audioURL: audioURL,
            model: whisperModel,
            outputDir: tempDir,
            settings: context.settings
        )
        context.transcriptionResult = result

        if !AppConstants.supportedAudioFormats.contains(context.fileExtension) {
            try? FileManager.default.removeItem(at: audioURL)
        }
    }
}

class AnalysisStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        guard context.outputType == .analysis || context.outputType == .report else { return }
        guard let transcriptionResult = context.transcriptionResult else { throw ProcessingError.transcriptionFailed }

        context.analysis = try await LLMService.shared.analyzeContent(
            transcription: transcriptionResult.text,
            prompt: context.settings.analysisPrompt,
            settings: context.settings
        )
    }
}

class ScreenshotExtractionStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
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

            while currentTime < duration {
                let frameURL = try? await FFmpegService.shared.extractFrame(
                    at: currentTime,
                    from: context.fileURL,
                    outputDir: imagesDir
                )
                if let url = frameURL {
                    context.screenshotURLs.append(url)
                }
                currentTime += interval
            }
        } catch {
            print("Screenshot extraction failed: \(error)")
        }
    }
}

class ReportGenerationStage: ProcessingStage {
    func process(_ context: ProcessingContext) async throws {
        let currentOutputPath = context.settings.outputPath
        let finalOutputDir = URL(fileURLWithPath: currentOutputPath.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        try FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true)

        let taskOutputDir: URL
        switch context.outputType {
        case .subtitle:
            taskOutputDir = finalOutputDir
        case .analysis, .report:
            taskOutputDir = finalOutputDir.appendingPathComponent(context.baseName)
            try FileManager.default.createDirectory(at: taskOutputDir, withIntermediateDirectories: true)
        }

        try await generateAudioMD(context: context, outputDir: taskOutputDir)

        switch context.outputType {
        case .subtitle:
            try await generateSubtitle(context: context, outputDir: taskOutputDir)
        case .analysis:
            try await generateAnalysis(context: context, outputDir: taskOutputDir)
        case .report:
            try await generateReport(context: context, outputDir: taskOutputDir)
        }

        try await generateMetadata(context: context, outputDir: taskOutputDir)
    }

    private func generateAudioMD(context: ProcessingContext, outputDir: URL) async throws {
        guard let transcriptionResult = context.transcriptionResult else { throw ProcessingError.transcriptionFailed }

        let audioMDURL = outputDir.appendingPathComponent("audio.md")
        let audioMDContent = """
        # 原始转录文本

        \(transcriptionResult.rawText)

        ---

        *生成时间: \(Date().formatted())*
        """
        try audioMDContent.write(to: audioMDURL, atomically: true, encoding: .utf8)
        context.generatedFiles.append(audioMDURL)
    }

    private func generateSubtitle(context: ProcessingContext, outputDir: URL) async throws {
        guard let transcriptionResult = context.transcriptionResult else { throw ProcessingError.transcriptionFailed }

        var segments = transcriptionResult.segments
        if context.settings.enableBilingualSubtitle {
            segments = try await LLMService.shared.translateSegments(
                segments,
                targetLanguage: context.settings.subtitleLanguageOrder == "cn-en" ? "English" : "Chinese",
                settings: context.settings
            )
        }

        for format in context.settings.subtitleFormats {
            let subtitleURL = try await ReportService.shared.generateSubtitleFile(
                segments: segments,
                outputDir: outputDir,
                format: format,
                languageOrder: context.settings.subtitleLanguageOrder,
                baseFileName: context.baseName
            )
            context.generatedFiles.append(subtitleURL)
        }
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

        let template = ReportTemplate(rawValue: context.settings.uploadTemplate) ?? .meeting
        let reportURL = try await ReportService.shared.generateMeetingReport(
            transcription: transcriptionResult.text,
            analysis: analysis,
            template: template,
            outputDir: outputDir
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
}
