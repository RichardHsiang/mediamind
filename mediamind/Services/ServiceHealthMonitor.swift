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

    // 移除自动监控功能，改为完全手动检查
    // 用户只能通过点击"立即检查全部"按钮来查看服务状态

    func checkAllServices() async {
        async let ollamaResult = checkOllama()
        async let lmStudioResult = checkLMStudio()

        ollamaStatus = await ollamaResult
        lmStudioStatus = await lmStudioResult
    }

    func checkOllama() async -> ServiceStatus {
        let startDate = Date()

        // 检查 Ollama 进程是否存在，不执行可能触发启动的命令
        let isRunning = await checkOllamaProcess()
        let responseTime = Date().timeIntervalSince(startDate)

        if isRunning {
            return ServiceStatus(
                service: .ollama,
                isRunning: true,
                lastChecked: Date(),
                responseTime: responseTime,
                error: nil
            )
        } else {
            return ServiceStatus(
                service: .ollama,
                isRunning: false,
                lastChecked: Date(),
                responseTime: responseTime,
                error: "Ollama 服务未运行"
            )
        }
    }

    private func checkOllamaProcess() async -> Bool {
        // 使用 pgrep 或 ps 命令检查 ollama 进程是否存在
        // 这些命令不会触发服务启动，只是检查进程状态
        
        let checkCommands = [
            ["/usr/bin/pgrep", "-x", "ollama"],
            ["/bin/ps", "aux"],
            ["/usr/bin/ps", "aux"]
        ]
        
        for command in checkCommands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                // 如果是 pgrep 命令，退出码为0表示找到进程
                if command[0].contains("pgrep") {
                    return process.terminationStatus == 0
                }
                
                // 如果是 ps 命令，检查输出中是否包含 ollama 进程
                if command[0].contains("ps") {
                    return output.contains("ollama") && !output.contains("grep")
                }
                
            } catch {
                print("[ServiceHealthMonitor] Failed to check ollama process with \(command[0]): \(error)")
                continue
            }
        }
        
        return false
    }

    func checkLMStudio() async -> ServiceStatus {
        let startDate = Date()

        // 检查 LM Studio 进程是否存在，不执行可能触发启动的命令
        let isRunning = await checkLMStudioProcess()
        let responseTime = Date().timeIntervalSince(startDate)

        if isRunning {
            return ServiceStatus(
                service: .lmstudio,
                isRunning: true,
                lastChecked: Date(),
                responseTime: responseTime,
                error: nil
            )
        } else {
            return ServiceStatus(
                service: .lmstudio,
                isRunning: false,
                lastChecked: Date(),
                responseTime: responseTime,
                error: "LM Studio 服务未运行"
            )
        }
    }

    private func checkLMStudioProcess() async -> Bool {
        // LM Studio 在 macOS 上的进程名称通常是 "LM Studio" 或 "lm-studio"
        // 使用 pgrep 或 ps 命令检查进程是否存在
        
        let processNames = ["LM Studio", "lm-studio", "LM-Studio"]
        
        for processName in processNames {
            let checkCommands = [
                ["/usr/bin/pgrep", "-x", processName],
                ["/usr/bin/pgrep", "-fi", processName],
                ["/bin/ps", "aux"],
                ["/usr/bin/ps", "aux"]
            ]
            
            for command in checkCommands {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command[0])
                process.arguments = Array(command.dropFirst())
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    // 如果是 pgrep 命令，退出码为0表示找到进程
                    if command[0].contains("pgrep") {
                        if process.terminationStatus == 0 {
                            return true
                        }
                    }
                    
                    // 如果是 ps 命令，检查输出中是否包含进程名称
                    if command[0].contains("ps") {
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        if output.contains(processName) && !output.contains("grep") {
                            return true
                        }
                    }
                    
                } catch {
                    print("[ServiceHealthMonitor] Failed to check LM Studio process with \(command[0]): \(error)")
                    continue
                }
            }
        }
        
        return false
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