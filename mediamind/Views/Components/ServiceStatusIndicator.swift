import SwiftUI

struct ServiceStatusIndicator: View {
    let status: ServiceStatus?
    var onRefresh: (() async -> Void)?

    @State private var isRefreshing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status?.statusColor ?? .gray)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )

            if let status = status {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.service.displayName)
                        .font(.system(size: 12, weight: .medium))

                    Text(status.statusText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("未检测")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onRefresh = onRefresh {
                Button(action: {
                    Task {
                        await performRefresh(onRefresh)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(isRefreshing ? .secondary : .appleBlue)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(
                            isRefreshing
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                            value: isRefreshing
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRefreshing)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }

    private func performRefresh(_ action: () async -> Void) async {
        isRefreshing = true
        await action()
        try? await Task.sleep(for: .seconds(0.5))
        isRefreshing = false
    }
}

struct ServiceHealthPanel: View {
    @State private var ollamaStatus: ServiceStatus?
    @State private var lmStudioStatus: ServiceStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.green)

                Text("服务健康状态")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("自动刷新间隔: 30秒")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ServiceStatusIndicator(status: ollamaStatus) {
                    await refreshOllama()
                }

                ServiceStatusIndicator(status: lmStudioStatus) {
                    await refreshLMStudio()
                }
            }

            HStack {
                Spacer()

                Button("立即检查全部") {
                    Task {
                        await checkAll()
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appleBlue.opacity(0.1))
                .foregroundColor(.appleBlue)
                .cornerRadius(6)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onAppear {
            Task {
                await startMonitoring()
            }
        }
    }

    private func startMonitoring() async {
        await ServiceHealthMonitor.shared.startMonitoring()
        await checkAll()
    }

    private func checkAll() async {
        await ServiceHealthMonitor.shared.checkAllServices()

        let (ollama, lmStudio) = await ServiceHealthMonitor.shared.getAllStatuses()
        ollamaStatus = ollama
        lmStudioStatus = lmStudio
    }

    private func refreshOllama() async {
        ollamaStatus = await ServiceHealthMonitor.shared.checkOllama()
    }

    private func refreshLMStudio() async {
        lmStudioStatus = await ServiceHealthMonitor.shared.checkLMStudio()
    }
}
