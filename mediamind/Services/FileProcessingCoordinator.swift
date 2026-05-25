import Foundation

class FileProcessingCoordinator {
    private let stages: [ProcessingStage]

    init(stages: [ProcessingStage]) {
        self.stages = stages
    }

    func process(context: ProcessingContext) async throws {
        // 前置配置检查
        let checkResult = context.checkRequiredConfiguration()
        if !checkResult.isValid {
            let missingItems = checkResult.missingItems.map { $0.item.rawValue }.joined(separator: "、")
            throw ProcessingError.configurationIncomplete(
                items: checkResult.missingItems,
                message: "缺少必要配置: \(missingItems)"
            )
        }
        
        for stage in stages {
            try await stage.process(context)
        }
    }

    static func createDefaultCoordinator() -> FileProcessingCoordinator {
        return FileProcessingCoordinator(stages: [
            FileValidationStage(),
            AudioExtractionStage(),
            TranscriptionStage(),
            AnalysisStage(),
            ScreenshotExtractionStage(),
            ReportGenerationStage()
        ])
    }
}
