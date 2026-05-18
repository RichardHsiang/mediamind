import Foundation

class FileProcessingCoordinator {
    private let stages: [ProcessingStage]

    init(stages: [ProcessingStage]) {
        self.stages = stages
    }

    func process(context: ProcessingContext) async throws {
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
