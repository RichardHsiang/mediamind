import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var savedTasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TaskViewModel()
    @State private var selectedFile: URL?
    @State private var selectedOption: OutputType?
    @State private var showProcessing = false
    @State private var showResults = false
    @State private var isProcessing = false

    var settings: AppSettings {
        let s = settingsList.first ?? AppSettings()
        print("[HomeView] Accessing settings, outputPath: \(s.outputPath)")
        return s
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Upload
                UploadView(selectedFile: $selectedFile)

                // Options
                OptionsView(selectedOption: $selectedOption)

                // Start/Stop Button
                startButton

                // Processing
                if showProcessing {
                    ProcessingView(viewModel: viewModel)
                }

                // Results
                if showResults {
                    ResultsView(viewModel: viewModel)
                }

                // Recent Tasks
                recentTasksSection
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
             Text("智能音视频处理")
                 .font(.system(size: 36, weight: .bold))
                 .foregroundStyle(
                     LinearGradient(
                         colors: [.appleBlue, .applePurple],
                         startPoint: .leading,
                         endPoint: .trailing
                     )
                 )

            Text("上传音频或视频文件，自动完成转录、分析与报告生成")
                .font(.system(size: 16))
                .foregroundColor(.appleGray)
        }
        .frame(maxWidth: .infinity)
    }

    private var startButton: some View {
        Button(action: isProcessing ? stopProcessing : startProcessing) {
            HStack {
                Image(systemName: isProcessing ? "stop.fill" : "play.fill")
                Text(isProcessing ? "停止处理" : "开始处理")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isProcessing ? [.red, .orange] : [.appleBlue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedFile == nil || selectedOption == nil)
        .opacity(selectedFile == nil || selectedOption == nil ? 0.5 : 1)
    }

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近任务")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button("查看全部") {
                    // Navigate to history
                }
                .font(.system(size: 14))
                .foregroundColor(.appleBlue)
            }

            let tasksToShow = viewModel.recentTasks.isEmpty
                ? Array(savedTasks.prefix(5))
                : removeDuplicates(from: viewModel.recentTasks)
            ForEach(tasksToShow) { task in
                TaskRow(task: task, onDelete: {
                    deleteTask(task)
                })
            }
        }
    }

    private func deleteTask(_ task: TaskItem) {
        // Remove from viewModel's recentTasks
        viewModel.recentTasks.removeAll { $0.id == task.id }

        // Remove from SwiftData if persisted
        if let existingTask = savedTasks.first(where: { $0.id == task.id }) {
            modelContext.delete(existingTask)
            do {
                try modelContext.save()
                print("[HomeView] Task deleted from database: \(task.taskName)")
            } catch {
                print("[HomeView] Failed to delete task from database: \(error)")
            }
        } else {
            print("[HomeView] Task removed from recent list: \(task.taskName)")
        }
    }

    private func startProcessing() {
        guard let file = selectedFile, let option = selectedOption else { return }
        showProcessing = true
        showResults = false
        isProcessing = true

        // Get the latest settings at the moment of starting processing
        let currentSettings = settings
        print("[HomeView] Starting processing with outputPath: \(currentSettings.outputPath)")
        viewModel.processFile(file, outputType: option, settings: currentSettings)
        
        // Observe completion
        Task {
            while viewModel.progress < 1.0 && viewModel.errorMessage == nil && isProcessing {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await MainActor.run {
                isProcessing = false
                showProcessing = false
                showResults = viewModel.errorMessage == nil && viewModel.progress >= 1.0
            }
        }
    }

    private func stopProcessing() {
        viewModel.cancelProcessing()
        isProcessing = false
        showProcessing = false
    }

    private func removeDuplicates(from tasks: [TaskItem]) -> [TaskItem] {
        var seenIDs: Set<UUID> = []
        return tasks.filter { task in
            seenIDs.insert(task.id).inserted
        }
    }
}
