import Foundation

struct LLMService {
    static let shared = LLMService()

    func analyzeContent(transcription: String, prompt: String, settings: AppSettings) async throws -> String {
        let finalPrompt = prompt.replacingOccurrences(of: "{{transcription}}", with: transcription)

        let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
        let baseURL = settings.llmBaseURL.isEmpty ? serviceType.defaultBaseURL : settings.llmBaseURL

        switch serviceType {
        case .ollama:
            return try await callOllama(baseURL: baseURL, model: settings.llmModel, prompt: finalPrompt)
        case .lmstudio:
            return try await callLMStudio(baseURL: baseURL, model: settings.llmModel, prompt: finalPrompt)
        }
    }

    func translateSegments(_ segments: [TranscriptionSegment], targetLanguage: String, settings: AppSettings) async throws -> [TranscriptionSegment] {
        let texts = segments.map { $0.text }.joined(separator: "\n")
        let prompt = "请将以下文本翻译为\(targetLanguage)，保持原有行数和格式，每行对应翻译：\n\n\(texts)"

        let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
        let baseURL = settings.llmBaseURL.isEmpty ? serviceType.defaultBaseURL : settings.llmBaseURL

        let translation: String
        switch serviceType {
        case .ollama:
            translation = try await callOllama(baseURL: baseURL, model: settings.llmModel, prompt: prompt)
        case .lmstudio:
            translation = try await callLMStudio(baseURL: baseURL, model: settings.llmModel, prompt: prompt)
        }

        let translatedLines = translation.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var result: [TranscriptionSegment] = []
        for (index, segment) in segments.enumerated() {
            let translatedText = index < translatedLines.count ? translatedLines[index] : segment.text
            result.append(TranscriptionSegment(
                startTime: segment.startTime,
                endTime: segment.endTime,
                speaker: segment.speaker,
                text: "\(segment.text)\n\(translatedText)"
            ))
        }

        return result
    }

    private func callOllama(baseURL: String, model: String, prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.invalidURL
        }

        print("[LLMService] Calling Ollama at: \(url.absoluteString), model: \(model)")

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 300

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[LLMService] Invalid response type from Ollama")
                throw LLMError.requestFailed
            }

            print("[LLMService] Ollama response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("[LLMService] Ollama request failed with status \(httpResponse.statusCode): \(errorBody)")
                throw LLMError.requestFailed
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                print("[LLMService] Failed to parse Ollama response")
                throw LLMError.invalidResponse
            }

            print("[LLMService] Ollama response received, length: \(responseText.count) chars")
            return responseText
        } catch {
            if Task.isCancelled {
                print("[LLMService] Request cancelled by user")
                throw LLMError.cancelled
            }
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("[LLMService] URL session cancelled")
                throw LLMError.cancelled
            }
            throw error
        }
    }

    private func callLMStudio(baseURL: String, model: String, prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw LLMError.invalidURL
        }

        print("[LLMService] Calling LM Studio at: \(url.absoluteString), model: \(model)")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 300

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[LLMService] Invalid response type from LM Studio")
                throw LLMError.requestFailed
            }

            print("[LLMService] LM Studio response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("[LLMService] LM Studio request failed with status \(httpResponse.statusCode): \(errorBody)")
                throw LLMError.requestFailed
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("[LLMService] Failed to parse LM Studio response")
                throw LLMError.invalidResponse
            }

            print("[LMService] LM Studio response received, length: \(content.count) chars")
            return content
        } catch {
            if Task.isCancelled {
                print("[LLMService] Request cancelled by user")
                throw LLMError.cancelled
            }
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("[LLMService] URL session cancelled")
                throw LLMError.cancelled
            }
            throw error
        }
    }

    func checkServiceAvailability(baseURL: String) async -> Bool {
        guard let url = URL(string: baseURL) else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

enum LLMError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case serviceUnavailable
    case notInstalled
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .requestFailed:
            return "请求失败，请检查 LLM 服务是否运行"
        case .invalidResponse:
            return "无效的响应格式"
        case .serviceUnavailable:
            return "LLM 服务不可用"
        case .notInstalled:
            return "LLM 服务未安装，请安装 Ollama 或 LM Studio"
        case .cancelled:
            return nil
        }
    }
}
