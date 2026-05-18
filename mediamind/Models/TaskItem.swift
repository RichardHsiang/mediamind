import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var fileName: String
    var filePath: String
    var fileType: String
    var fileSize: Int64
    var outputType: String
    var status: String
    var createdAt: Date
    var completedAt: Date?
    var outputFiles: [String]
    var errorMessage: String?
    var taskName: String
    var processingType: String

    init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        fileType: String,
        fileSize: Int64,
        outputType: String,
        status: String = TaskStatus.created.rawValue,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        outputFiles: [String] = [],
        errorMessage: String? = nil,
        taskName: String = "",
        processingType: String = ""
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.fileType = fileType
        self.fileSize = fileSize
        self.outputType = outputType
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.outputFiles = outputFiles
        self.errorMessage = errorMessage
        self.taskName = taskName
        self.processingType = processingType
    }
}
