import Foundation

class ResourceMonitor {
    static let shared = ResourceMonitor()
    
    private init() {}
    
    // 检查并清理所有遗留进程
    func cleanupAllResources() {
        print("[ResourceMonitor] 开始清理所有资源...")
        
        // 1. 清理Python进程
        cleanupPythonProcesses()
        
        // 2. 清理mlx_whisper相关进程
        cleanupMLXWhisperProcesses()
        
        // 3. 清理URLSession缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 4. 触发内存清理
        autoreleasepool {
            // 强制清理
        }
        
        print("[ResourceMonitor] 资源清理完成")
    }
    
    // 清理所有Python进程
    private func cleanupPythonProcesses() {
        print("[ResourceMonitor] 检查Python进程...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["aux"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: .newlines)
            var pythonPIDs: [Int32] = []
            
            for line in lines {
                if line.contains("python3") && line.contains("transcribe.py") {
                    let components = line.split(separator: " ", omittingEmptySubsequences: true)
                    if components.count >= 2, let pid = Int32(components[1]) {
                        pythonPIDs.append(pid)
                        print("[ResourceMonitor] 发现Python进程: PID=\(pid)")
                    }
                }
            }
            
            // 终止Python进程
            for pid in pythonPIDs {
                terminateProcess(pid: pid)
            }
            
            if pythonPIDs.isEmpty {
                print("[ResourceMonitor] 没有发现遗留的Python进程")
            } else {
                print("[ResourceMonitor] 已终止 \(pythonPIDs.count) 个Python进程")
            }
            
        } catch {
            print("[ResourceMonitor] 检查Python进程失败: \(error)")
        }
    }
    
    // 清理MLX Whisper相关进程
    private func cleanupMLXWhisperProcesses() {
        print("[ResourceMonitor] 检查MLX Whisper进程...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["aux"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: .newlines)
            var mlxPIDs: [Int32] = []
            
            for line in lines {
                // 检查包含mlx_whisper或相关关键词的进程
                if line.contains("mlx_whisper") || line.contains("mlx") || line.contains("whisper") {
                    let components = line.split(separator: " ", omittingEmptySubsequences: true)
                    if components.count >= 2, let pid = Int32(components[1]) {
                        mlxPIDs.append(pid)
                        print("[ResourceMonitor] 发现MLX相关进程: PID=\(pid)")
                    }
                }
            }
            
            // 终止MLX进程
            for pid in mlxPIDs {
                terminateProcess(pid: pid)
            }
            
            if mlxPIDs.isEmpty {
                print("[ResourceMonitor] 没有发现MLX相关进程")
            } else {
                print("[ResourceMonitor] 已终止 \(mlxPIDs.count) 个MLX相关进程")
            }
            
        } catch {
            print("[ResourceMonitor] 检查MLX进程失败: \(error)")
        }
    }
    
    // 终止进程
    private func terminateProcess(pid: Int32) {
        print("[ResourceMonitor] 尝试终止进程: \(pid)")
        
        // 首先尝试正常终止
        let termResult = kill(pid, SIGTERM)
        if termResult == 0 {
            print("[ResourceMonitor] 进程 \(pid) 已发送SIGTERM信号")
            
            // 等待进程终止
            usleep(200000) // 200ms
            
            // 检查进程是否还在运行
            if kill(pid, 0) == 0 {
                print("[ResourceMonitor] 进程 \(pid) 仍在运行，发送SIGKILL")
                kill(pid, SIGKILL)
                usleep(100000) // 100ms
            }
        } else {
            print("[ResourceMonitor] 无法终止进程 \(pid): errno=\(termResult)")
        }
    }
    
    // 等待资源释放
    func waitForResourcesReleased(maxWaitSeconds: Int = 10) async {
        print("[ResourceMonitor] 等待资源释放...")
        
        for i in 0..<maxWaitSeconds {
            // 检查是否还有遗留进程
            let hasOrphaned = checkForOrphanedProcesses()
            
            if !hasOrphaned {
                print("[ResourceMonitor] 资源已释放")
                return
            }
            
            print("[ResourceMonitor] 等待资源释放... (\(i+1)/\(maxWaitSeconds)s)")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        print("[ResourceMonitor] 资源等待超时，强制清理")
        cleanupAllResources()
    }
    
    // 检查是否有遗留进程
    private func checkForOrphanedProcesses() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["aux"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            for line in output.components(separatedBy: .newlines) {
                if (line.contains("python3") && line.contains("transcribe.py")) ||
                   line.contains("mlx_whisper") {
                    return true
                }
            }
            
            return false
            
        } catch {
            return false
        }
    }
    
    // 完整的资源检查和清理
    func performFullCleanup() {
        print("[ResourceMonitor] 执行完整清理...")
        
        // 1. 强制终止所有相关进程
        cleanupAllResources()
        
        // 2. 等待
        usleep(500000) // 500ms
        
        // 3. 再次检查并清理
        cleanupAllResources()
        
        print("[ResourceMonitor] 完整清理完成")
    }
}