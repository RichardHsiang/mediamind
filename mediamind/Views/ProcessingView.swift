import SwiftUI

struct ProcessingView: View {
    @ObservedObject var viewModel: TaskViewModel

    var body: some View {
        GlassCard {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("正在处理")
                            .font(.system(size: 22, weight: .semibold))

                        Text(viewModel.currentTaskDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.appleGray)
                    }

                    Spacer()

                    ProgressRing(progress: viewModel.progress)
                }

                Divider()

                VStack(spacing: 16) {
                    StepIndicator(
                        title: "文件校验",
                        status: stepStatus(for: .fileValidation),
                        progress: stepProgress(for: .fileValidation)
                    )

                    StepIndicator(
                        title: "音频提取",
                        status: stepStatus(for: .audioExtraction),
                        progress: stepProgress(for: .audioExtraction)
                    )

                    StepIndicator(
                        title: "Whisper转录",
                        status: stepStatus(for: .whisperTranscription),
                        progress: stepProgress(for: .whisperTranscription)
                    )

                    StepIndicator(
                        title: "文本分析",
                        status: stepStatus(for: .textAnalysis),
                        progress: stepProgress(for: .textAnalysis)
                    )

                    StepIndicator(
                        title: "报告生成",
                        status: stepStatus(for: .reportGeneration),
                        progress: stepProgress(for: .reportGeneration)
                    )
                }
            }
        }
    }

    /// 确定步骤的状态
    private func stepStatus(for step: ProcessingStep) -> StepStatus {
        guard let currentStep = viewModel.currentStep else {
            // 如果全部完成，所有步骤显示完成
            if viewModel.progress >= 1.0 {
                return .completed
            }
            return .pending
        }

        let allSteps = ProcessingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              let stepIndex = allSteps.firstIndex(of: step) else {
            return .pending
        }

        if stepIndex < currentIndex {
            return .completed
        } else if stepIndex == currentIndex {
            return .inProgress
        } else {
            return .pending
        }
    }

    /// 计算每个步骤的精确进度 (0.0 - 1.0)
    private func stepProgress(for step: ProcessingStep) -> Double {
        let progress = viewModel.progress

        switch step {
        case .fileValidation:
            // 0% - 10%
            if progress < 0.10 {
                return progress / 0.10
            } else {
                return 1.0
            }

        case .audioExtraction:
            // 10% - 25%
            if progress < 0.10 {
                return 0.0
            } else if progress < 0.25 {
                return (progress - 0.10) / 0.15
            } else {
                return 1.0
            }

        case .whisperTranscription:
            // 25% - 60%
            if progress < 0.25 {
                return 0.0
            } else if progress < 0.60 {
                return (progress - 0.25) / 0.35
            } else {
                return 1.0
            }

        case .textAnalysis:
            // 60% - 82%
            if progress < 0.60 {
                return 0.0
            } else if progress < 0.82 {
                return (progress - 0.60) / 0.22
            } else {
                return 1.0
            }

        case .reportGeneration:
            // 82% - 100%
            if progress < 0.82 {
                return 0.0
            } else if progress < 1.0 {
                return (progress - 0.82) / 0.18
            } else {
                return 1.0
            }
        }
    }
}
