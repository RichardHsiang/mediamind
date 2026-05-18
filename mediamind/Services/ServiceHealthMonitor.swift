import Foundation
import SwiftUI

struct ServiceStatus: Equatable {
    let service: LLMServiceType
    var isRunning: Bool
    var lastChecked: Date
    var responseTime: TimeInterval?
    var error: String?

    var statusColor: Color {
        isRunning ? .green : .red
    }

    var statusText: String {
        if isRunning {
            if let responseTime = responseTime {
                return "运行中 (\(Int(responseTime * 1000))ms)"
            } else {
                return "运行中"
            }
        } else {
            if let error = error {
                return "未运行 - \(error)"
            } else {
                return "未运行"
            }
        }
    }
}

actor ServiceHealthMonitor {
    static let shared = ServiceHealthMonitor()

    private var ollamaStatus: ServiceStatus?
    private var lmStudioStatus: ServiceStatus?

    private var monitoringTask: Task<Void, Never>?
    private let checkInterval: TimeInterval = 30 // 30 seconds

    func startMonitoring() {
        guard monitoringTask == nil else { return }

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkAllServices()
                try? await Task.sleep(for: .seconds(checkInterval))
            }
        }

        print("[ServiceHealthMonitor] Started monitoring (interval: \(checkInterval)s)")
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        print("[ServiceHealthMonitor] Stopped monitoring")
    }

    func checkAllServices() async {
        async let ollamaResult = checkOllama()
        async let lmStudioResult = checkLMStudio()

        ollamaStatus = await ollamaResult
        lmStudioStatus = await lmStudioResult
    }

    func checkOllama() async -> ServiceStatus {
        let startDate = Date()

        // 使用与 ModelDiscoveryService 相同的逻辑来查找 ollama
        let (ollamaPath, findError) = await findOllamaExecutable()

        if let findError = findError {
            print("[ServiceHealthMonitor] Ollama not found: \(findError)")
            return ServiceStatus(
                service: .ollama,
                isRunning: false,
                lastChecked: Date(),
                responseTime: nil,
                error: "Ollama 未安装"
            )
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ollamaPath)
            process.arguments = ["list"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let isRunning: Bool = await withCheckedContinuation { continuation in
                process.terminationHandler = { proc in
                    continuation.resume(returning: proc.terminationStatus == 0)
                }

                do {
                    try process.run()
                } catch {
                    print("[ServiceHealthMonitor] Failed to run ollama: \(error)")
                    continuation.resume(returning: false)
                }
            }

            let responseTime = Date().timeIntervalSince(startDate)

            return ServiceStatus(
                service: .ollama,
                isRunning: isRunning,
                lastChecked: Date(),
                responseTime: responseTime,
                error: isRunning ? nil : "Ollama 服务未运行"
            )
        } catch {
            return ServiceStatus(
                service: .ollama,
                isRunning: false,
                lastChecked: Date(),
                responseTime: nil,
                error: error.localizedDescription
            )
        }
    }

    private func findOllamaExecutable() async -> (path: String, error: String?) {
        // 尝试使用 which 命令查找
        let envPaths = ["/usr/bin/env", "/bin/sh"]

        for envPath in envPaths {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: envPath)
            process.arguments = ["which", "ollama"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                        return (path, nil)
                    }
                }
            } catch {
                print("[ServiceHealthMonitor] Error finding ollama via \(envPath): \(error)")
            }
        }

        // 检查常见路径
        let possiblePaths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/usr/bin/ollama",
            "\(NSHomeDirectory())/.ollama/bin/ollama",
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return (path, nil)
            }
        }

        return ("", "Ollama 未安装或未找到")
    }

    func checkLMStudio() async -> ServiceStatus {
        let startDate = Date()
        let urlString = "http://127.0.0.1:1234/v1/models"

        guard let url = URL(string: urlString) else {
            return ServiceStatus(
                service: .lmstudio,
                isRunning: false,
                lastChecked: Date(),
                responseTime: nil,
                error: "Invalid URL"
            )
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let isRunning = httpResponse?.statusCode == 200
            let responseTime = Date().timeIntervalSince(startDate)

            return ServiceStatus(
                service: .lmstudio,
                isRunning: isRunning,
                lastChecked: Date(),
                responseTime: responseTime,
                error: isRunning ? nil : "HTTP \(httpResponse?.statusCode ?? 0)"
            )
        } catch {
            return ServiceStatus(
                service: .lmstudio,
                isRunning: false,
                lastChecked: Date(),
                responseTime: nil,
                error: error.localizedDescription
            )
        }
    }

    func getStatus(for service: LLMServiceType) -> ServiceStatus? {
        switch service {
        case .ollama:
            return ollamaStatus
        case .lmstudio:
            return lmStudioStatus
        }
    }

    func getAllStatuses() -> (ollama: ServiceStatus?, lmStudio: ServiceStatus?) {
        (ollamaStatus, lmStudioStatus)
    }
}
