import Foundation

enum ModelDiscoveryError: LocalizedError {
    case ollamaNotFound(String)
    case ollamaCommandFailed(String)
    case ollamaProcessStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .ollamaNotFound(let message):
            return message
        case .ollamaCommandFailed(let message):
            return message
        case .ollamaProcessStartFailed(let message):
            return message
        }
    }
}

actor ModelDiscoveryService {
    static let shared = ModelDiscoveryService()

    // MARK: - Cache Configuration

    private struct ModelCache {
        var models: [String]
        var timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    private var ollamaCache: ModelCache?
    private var lmStudioCache: ModelCache?
    private var whisperCache: [String: ModelCache] = [:]

    private let cacheTTL: TimeInterval = 60 // 60 seconds

    // MARK: - Ollama Models

    private func findOllamaExecutable() -> (path: String, error: String?) {
        // 首先尝试使用 `which` 命令查找（通过 /usr/bin/env 来确保 PATH 正确传递）
        let envPaths = [
            "/usr/bin/env",
            "/bin/sh",
        ]
        
        for envPath in envPaths {
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: envPath)
            whichProcess.arguments = ["which", "ollama"]
            
            let pipe = Pipe()
            whichProcess.standardOutput = pipe
            
            do {
                try whichProcess.run()
                whichProcess.waitUntilExit()
                
                if whichProcess.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                        print("[ModelDiscoveryService] Found ollama via 'which' at: \(path)")
                        return (path, nil)
                    }
                }
            } catch {
                print("[ModelDiscoveryService] Error running 'which ollama' via \(envPath): \(error)")
            }
        }
        
        // 尝试使用 `command -v` 查找（bash 内建命令）
        let bashProcess = Process()
        bashProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        bashProcess.arguments = ["-c", "command -v ollama"]
        
        let bashPipe = Pipe()
        bashProcess.standardOutput = bashPipe
        
        do {
            try bashProcess.run()
            bashProcess.waitUntilExit()
            
            if bashProcess.terminationStatus == 0 {
                let data = bashPipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                    print("[ModelDiscoveryService] Found ollama via 'command -v' at: \(path)")
                    return (path, nil)
                }
            }
        } catch {
            print("[ModelDiscoveryService] Error running 'command -v ollama': \(error)")
        }

        // 最后检查常见路径
        let possiblePaths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/usr/bin/ollama",
            "\(NSHomeDirectory())/.ollama/bin/ollama",
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                print("[ModelDiscoveryService] Found ollama at common location: \(path)")
                return (path, nil)
            }
        }

        let errorMsg = """
        Ollama 未找到或未安装。

        请确认：
        • 已安装 Ollama：https://ollama.ai
        • 安装后重启终端或应用
        • 如果使用 Homebrew 安装，运行: brew install ollama
        • 当前 PATH 环境变量包含 ollama 的安装路径
        """

        return ("", errorMsg)
    }

    func getOllamaModels(forceRefresh: Bool = false) async throws -> [String] {
        if !forceRefresh, let cache = ollamaCache, !cache.isExpired {
            let ttlRemaining = cache.ttl - Date().timeIntervalSince(cache.timestamp)
            print("[ModelDiscoveryService] Returning cached Ollama models (\(cache.models.count) models), cached at \(cache.timestamp), TTL remaining: \(String(format: "%.1f", max(0, ttlRemaining)))s")
            return cache.models
        }

        let (ollamaPath, findError) = findOllamaExecutable()

        guard !ollamaPath.isEmpty else {
            print("[ModelDiscoveryService] \(findError ?? "Unknown error")")
            throw ModelDiscoveryError.ollamaNotFound(findError ?? "Unknown error")
        }

        print("[ModelDiscoveryService] Executing command: \(ollamaPath) list")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaPath)
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    print("[ModelDiscoveryService] Raw command output (first 500 chars): \(String(output.prefix(500)))")

                    let models = Self.parseOllamaOutput(output)
                    print("[ModelDiscoveryService] Parsed \(models.count) Ollama models: \(models)")

                    Task {
                        await self.cacheOllamaModels(models)
                    }

                    continuation.resume(returning: models)
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("[ModelDiscoveryService] Ollama list command failed with exit status code \(proc.terminationStatus), error output: \(errorOutput)")

                    var userFriendlyMessage = "Ollama 命令执行失败\n\n"
                    if proc.terminationStatus == 127 {
                        userFriendlyMessage += "错误：命令不存在（exit code 127）\n\n请确认：\n• Ollama 已正确安装\n• 安装路径正确：\(ollamaPath)\n• 文件有执行权限"
                    } else if proc.terminationStatus == 1 {
                        userFriendlyMessage += "错误：命令返回错误（exit code 1）\n\n可能原因：\n• Ollama 服务未启动，请运行 `ollama serve`\n• 无已安装的模型，请运行 `ollama pull <model-name>`\n• 详细错误：\(errorOutput)"
                    } else {
                        userFriendlyMessage += "错误码：\(proc.terminationStatus)\n\n详细错误信息：\(errorOutput)"
                    }

                    continuation.resume(throwing: ModelDiscoveryError.ollamaCommandFailed(userFriendlyMessage))
                }
            }

            do {
                try process.run()
            } catch {
                print("[ModelDiscoveryService] Failed to run ollama list at \(ollamaPath): \(error)")

                var userFriendlyMessage = "无法启动 Ollama 进程\n\n"
                if error.localizedDescription.contains("No such file") || error.localizedDescription.contains("not found") {
                    userFriendlyMessage += "错误：找不到可执行文件\n\n路径：\(ollamaPath)\n\n请确认：\n• Ollama 已安装在此路径\n• 文件存在且有执行权限"
                } else if error.localizedDescription.contains("Permission denied") {
                    userFriendlyMessage += "错误：权限不足\n\n路径：\(ollamaPath)\n\n请检查文件权限"
                } else {
                    userFriendlyMessage += "错误详情：\(error.localizedDescription)"
                }

                continuation.resume(throwing: ModelDiscoveryError.ollamaProcessStartFailed(userFriendlyMessage))
            }
        }
    }

    private func cacheOllamaModels(_ models: [String]) {
        ollamaCache = ModelCache(
            models: models,
            timestamp: Date(),
            ttl: cacheTTL
        )
    }

    private static func parseOllamaOutput(_ output: String) -> [String] {
        var models: [String] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 {
                let name = components[0]
                if name != "NAME" && !name.contains("---") {
                    models.append(name)
                }
            }
        }

        return models
    }

    // MARK: - Whisper Models

    // MARK: - Path Resolution Helper
    
    private func resolveModelPath(_ input: String) -> (absolutePath: String, exists: Bool, error: String?) {
        var path = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("[ModelDiscoveryService] Resolving model path: '\(input)'")
        
        if path.isEmpty {
            let defaultPath = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".cache/whisper").path
            print("[ModelDiscoveryService] Empty path provided, using default: \(defaultPath)")
            return (defaultPath, false, "使用默认路径")
        }
        
        if path.hasPrefix("~") {
            path = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
            print("[ModelDiscoveryService] Expanded ~ to home directory: \(path)")
        }
        
        if !path.hasPrefix("/") {
            print("[ModelDiscoveryService] Relative path detected, attempting resolution...")
            
            let possiblePaths = [
                URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path).path,
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path).path,
                "/" + path
            ]
            
            for possiblePath in possiblePaths {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: possiblePath, isDirectory: &isDir) && isDir.boolValue {
                    print("[ModelDiscoveryService] Found existing directory at: \(possiblePath)")
                    return (possiblePath, true, nil)
                }
            }
            
            let chosenPath = possiblePaths[0]
            print("[ModelDiscoveryService] No existing directory found, using: \(chosenPath)")
            return (chosenPath, false, "相对路径已转换为绝对路径，但目录不存在。已尝试: \(possiblePaths.joined(separator: ", "))")
        }
        
        let standardized = (path as NSString).standardizingPath
        print("[ModelDiscoveryService] Standardized absolute path: \(standardized)")
        
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: standardized, isDirectory: &isDir)
        
        if !exists {
            print("[ModelDiscoveryService] Path does not exist: \(standardized)")
            return (standardized, false, "路径不存在: \(standardized)")
        } else if !isDir.boolValue {
            print("[ModelDiscoveryService] Path exists but is not a directory: \(standardized)")
            return (standardized, false, "指定路径不是目录: \(standardized)")
        }
        
        print("[ModelDiscoveryService] Path resolved successfully: \(standardized)")
        return (standardized, true, nil)
    }

    func getWhisperModels(modelPath: String? = nil, forceRefresh: Bool = false) -> [String] {
        let cacheKey = modelPath ?? "default"

        if !forceRefresh, let cache = whisperCache[cacheKey], !cache.isExpired {
            let ttlRemaining = cache.ttl - Date().timeIntervalSince(cache.timestamp)
            print("[ModelDiscoveryService] Returning cached Whisper models for path \(cacheKey) (\(cache.models.count) models), cached at \(cache.timestamp), TTL remaining: \(String(format: "%.1f", max(0, ttlRemaining)))s")
            return cache.models
        }

        let rawPath = modelPath ?? ""
        let resolved = resolveModelPath(rawPath)
        let resolvedPath = resolved.absolutePath
        
        if !resolved.exists {
            print("[ModelDiscoveryService] ⚠️ Path validation warning: \(resolved.error ?? "Unknown error")")
        }

        print("[ModelDiscoveryService] Scanning Whisper models at resolved path: \(resolvedPath)")

        let pathURL = URL(fileURLWithPath: resolvedPath)
        var models: Set<String> = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: pathURL, includingPropertiesForKeys: nil)
            let fileNames = contents.map { $0.lastPathComponent }
            print("[ModelDiscoveryService] Found \(fileNames.count) items in directory: \(fileNames)")
            
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent
                let fileNameLower = fileName.lowercased()
                
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues?.isDirectory == true
                
                if isDirectory {
                    if !fileName.hasPrefix(".") && !["Assets", "Library", ".DS_Store"].contains(fileName) {
                        print("[ModelDiscoveryService] Found model directory: \(fileName)")
                        models.insert(fileName)
                    }
                    continue
                }
                
                if fileName.hasPrefix(".") {
                    continue
                }
                
                if fileNameLower.hasSuffix(".bin") {
                    var name = fileName.replacingOccurrences(of: ".bin", with: "")
                    name = name.replacingOccurrences(of: "ggml-", with: "")
                    print("[ModelDiscoveryService] Found .bin model: \(fileName) -> \(name)")
                    models.insert(name)
                } else if fileNameLower.hasSuffix(".pt") {
                    let name = fileName.replacingOccurrences(of: ".pt", with: "")
                    print("[ModelDiscoveryService] Found .pt model: \(fileName) -> \(name)")
                    models.insert(name)
                } else if fileNameLower.hasSuffix(".safetensors") {
                    var name = fileName
                    let quantizationPatterns = ["-fp32", "-fp16", "-q4_0", "-q4_1", "-q5_0", "-q5_1", "-q8_0", "-int8"]
                    for pattern in quantizationPatterns {
                        name = name.replacingOccurrences(of: "\(pattern).safetensors", with: "")
                    }
                    name = name.replacingOccurrences(of: ".safetensors", with: "")
                    print("[ModelDiscoveryService] Found .safetensors model: \(fileName) -> \(name)")
                    models.insert(name)
                } else if fileNameLower.hasSuffix(".onnx") {
                    var name = fileName.replacingOccurrences(of: ".onnx", with: "")
                    name = name.replacingOccurrences(of: "-int8", with: "")
                        .replacingOccurrences(of: "-fp16", with: "")
                        .replacingOccurrences(of: "-fp32", with: "")
                    print("[ModelDiscoveryService] Found .onnx model: \(fileName) -> \(name)")
                    models.insert(name)
                } else if fileNameLower.hasSuffix(".mlx") || fileNameLower.hasSuffix(".mlpackage") {
                    let ext = fileNameLower.hasSuffix(".mlx") ? ".mlx" : ".mlpackage"
                    let name = fileName.replacingOccurrences(of: ext, with: "")
                    print("[ModelDiscoveryService] Found \(ext) model: \(fileName) -> \(name)")
                    models.insert(name)
                } else {
                    let knownExtensions = ["bin", "pt", "safetensors", "onnx", "mlx", "mlpackage", "json", "md", "txt", "yaml", "yml", "cfg", "ini"]
                    let fileExt = (fileName as NSString).pathExtension.lowercased()
                    if !knownExtensions.contains(fileExt) && !fileName.isEmpty {
                        print("[ModelDiscoveryService] Found potential model file (unknown extension): \(fileName)")
                        models.insert(fileName)
                    }
                }
            }

            if models.isEmpty {
                let knownModels = ["tiny", "base", "small", "medium", "large", "large-v3", "large-v2", "turbo"]
                for model in knownModels {
                    let modelPath = pathURL.appendingPathComponent(model)
                    if FileManager.default.fileExists(atPath: modelPath.path) ||
                       FileManager.default.fileExists(atPath: modelPath.appendingPathExtension("bin").path) ||
                       FileManager.default.fileExists(atPath: modelPath.appendingPathExtension("pt").path) {
                        models.insert(model)
                    }
                }
            }
        } catch {
            print("[ModelDiscoveryService] Error scanning Whisper models at path '\(resolvedPath)': \(error.localizedDescription) (Error code: \((error as NSError).code), Domain: \((error as NSError).domain))")
            return []
        }

        let result = Array(models).sorted()
        print("[ModelDiscoveryService] Matched Whisper models: \(result)")

        whisperCache[cacheKey] = ModelCache(
            models: result,
            timestamp: Date(),
            ttl: cacheTTL
        )

        return result
    }

    func invalidateWhisperCache(modelPath: String? = nil) {
        let cacheKey = modelPath ?? "default"
        whisperCache.removeValue(forKey: cacheKey)
        print("[ModelDiscoveryService] Invalidated Whisper cache for path '\(cacheKey)' at \(Date())")
        
        if modelPath == nil {
            print("[ModelDiscoveryService] Note: Only invalidated default cache key. Other path-specific caches remain.")
        }
    }
    
    func invalidateAllWhisperCaches() {
        let count = whisperCache.count
        whisperCache.removeAll()
        print("[ModelDiscoveryService] Invalidated all \(count) Whisper cache entries at \(Date())")
    }

    // MARK: - LM Studio Models

    func getLMStudioModels(forceRefresh: Bool = false) async -> [String] {
        if !forceRefresh, let cache = lmStudioCache, !cache.isExpired {
            let ttlRemaining = cache.ttl - Date().timeIntervalSince(cache.timestamp)
            print("[ModelDiscoveryService] Returning cached LM Studio models (\(cache.models.count) models), cached at \(cache.timestamp), TTL remaining: \(String(format: "%.1f", max(0, ttlRemaining)))s")
            return cache.models
        }

        let endpoints = [
            "http://127.0.0.1:1234/v1/models",
            "http://127.0.0.1:1234/api/models",
            "http://localhost:1234/v1/models",
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else {
                print("[ModelDiscoveryService] Invalid LM Studio URL: \(endpoint)")
                continue
            }

            print("[ModelDiscoveryService] Requesting LM Studio models from URL: \(url.absoluteString)")

            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.httpMethod = "GET"

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ModelDiscoveryService] Invalid HTTP response from LM Studio at \(endpoint)")
                    continue
                }

                print("[ModelDiscoveryService] LM Studio responded with HTTP status code: \(httpResponse.statusCode) at \(endpoint)")

                if httpResponse.statusCode == 200 {
                    let models = parseLMStudioResponse(data, endpoint: endpoint)
                    if !models.isEmpty {
                        let sortedModels = models.sorted()
                        print("[ModelDiscoveryService] Successfully retrieved \(sortedModels.count) LM Studio models from \(endpoint)")

                        lmStudioCache = ModelCache(
                            models: sortedModels,
                            timestamp: Date(),
                            ttl: cacheTTL
                        )

                        return sortedModels
                    }
                } else if httpResponse.statusCode != 404 {
                    print("[ModelDiscoveryService] Endpoint \(endpoint) returned status \(httpResponse.statusCode)")
                }
            } catch let error as URLError {
                classifyAndLogError(error, endpoint: endpoint)
                if error.code == .cannotConnectToHost {
                    break
                }
            } catch {
                print("[ModelDiscoveryService] Unexpected error fetching LM Studio models from \(endpoint): \(error.localizedDescription)")
            }
        }

        print("[ModelDiscoveryService] All endpoints failed, trying fallback method")
        return getLMStudioModelsFromFallback()
    }

    private func parseLMStudioResponse(_ data: Data, endpoint: String) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[ModelDiscoveryService] Failed to parse JSON response from \(endpoint)")
            return []
        }

        var models: [String] = []

        if let modelData = json["data"] as? [[String: Any]] {
            for modelInfo in modelData {
                if let modelName = modelInfo["id"] as? String {
                    models.append(modelName)
                }
            }
        } else if let modelName = json["model"] as? String {
            models.append(modelName)
        } else if let modelName = json["id"] as? String {
            models.append(modelName)
        }

        print("[ModelDiscoveryService] Parsed \(models.count) models from \(endpoint): \(models)")
        return models
    }

    private func classifyAndLogError(_ error: URLError, endpoint: String) {
        switch error.code {
        case .timedOut:
            print("[ModelDiscoveryService] ⏰ 连接超时 (\(endpoint)): LM Studio 可能正在启动中，请稍后再试")
        case .cannotConnectToHost:
            print("[ModelDiscoveryService] ❌ 无法连接 (\(endpoint)): LM Studio 服务未运行，请先启动应用")
        case .notConnectedToInternet:
            print("[ModelDiscoveryService] 🌐 无网络连接")
        case .dnsLookupFailed, .cannotFindHost:
            print("[ModelDiscoveryService] 🔍 DNS 解析失败 (\(endpoint))")
        default:
            print("[ModelDiscoveryService] ⚠️ 请求失败 (\(endpoint)): \(error.localizedDescription) (code: \(error.code.rawValue))")
        }
    }

    private func getLMStudioModelsFromFallback() -> [String] {
        let lmStudioModelsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/LM Studio/models")

        var models: [String] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: lmStudioModelsDir, includingPropertiesForKeys: nil)
            for fileURL in contents {
                if fileURL.hasDirectoryPath {
                    let modelName = fileURL.lastPathComponent
                    models.append(modelName)
                }
            }
        } catch {
            print("[ModelDiscoveryService] Fallback scan failed: \(error)")
        }

        return models.sorted()
    }

    // MARK: - Cache Management

    func invalidateAllCaches() {
        ollamaCache = nil
        lmStudioCache = nil
        whisperCache.removeAll()
        print("[ModelDiscoveryService] All caches invalidated")
    }

    func getCacheStatus() -> (ollama: Bool, lmStudio: Bool, whisper: Int) {
        let ollamaCached = ollamaCache != nil && !(ollamaCache?.isExpired ?? true)
        let lmStudioCached = lmStudioCache != nil && !(lmStudioCache?.isExpired ?? true)
        return (ollamaCached, lmStudioCached, whisperCache.count)
    }

    // MARK: - Check Service Availability

    func isOllamaRunning() async -> Bool {
        let (ollamaPath, _) = findOllamaExecutable()
        guard !ollamaPath.isEmpty else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaPath)
        process.arguments = ["ps"]

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                print("[ModelDiscoveryService] Failed to check Ollama status: \(error)")
                continuation.resume(returning: false)
            }
        }
    }

    func isLMStudioRunning() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://127.0.0.1:1234/v1/models"]

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}