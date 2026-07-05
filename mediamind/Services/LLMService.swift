import Foundation

struct LLMService {
    static let shared = LLMService()

    func analyzeContent(transcription: String, prompt: String, settings: AppSettings) async throws -> String {
        // 将audio.md的转录内容替换到提示词中的{{transcription}}占位符
        // LLM无法直接访问文件系统，需要将内容传递给它
        // 注意：此操作创建新字符串，不修改原始prompt模板，确保模板纯净
        let finalPrompt = prompt.replacingOccurrences(of: "{{transcription}}", with: transcription)
        
        // 验证：检查原始模板是否被污染
        if prompt.contains("{{transcription}}") {
            print("[LLMService] ✅ 原始提示词模板保持纯净，仍包含占位符")
        } else {
            print("[LLMService] ⚠️ 警告：原始提示词模板可能被污染")
        }
        
        // 验证：检查最终提示词是否包含转录内容
        if transcription.isEmpty {
            print("[LLMService] ℹ️ 转录内容为空，提示词替换将仅移除占位符")
        } else if finalPrompt.contains(transcription) {
            print("[LLMService] ✅ 最终提示词包含转录内容 (长度: \(transcription.count))，替换成功")
        } else {
            print("[LLMService] ⚠️ 警告：转录内容替换可能失败 (转录长度: \(transcription.count))")
            print("[LLMService] 提示词前100字符: \(finalPrompt.prefix(100))...")
        }

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
        let batchSize = 20
        var allTranslatedTexts: [String] = []

        for batchStart in stride(from: 0, to: segments.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, segments.count)
            let batchSegments = Array(segments[batchStart..<batchEnd])

            var translatedDict = try await translateBatchWithVerification(
                batchSegments: batchSegments,
                batchOffset: batchStart,
                targetLanguage: targetLanguage,
                settings: settings,
                maxRetries: 2
            )

            for i in batchStart..<batchEnd {
                if let translated = translatedDict[i] {
                    allTranslatedTexts.append(translated)
                } else {
                    print("[LLMService] ⚠️ Missing translation for index \(i), using original text")
                    allTranslatedTexts.append(segments[i].text)
                }
            }
        }

        var result: [TranscriptionSegment] = []
        for (index, segment) in segments.enumerated() {
            let translatedText = index < allTranslatedTexts.count ? allTranslatedTexts[index] : segment.text

            result.append(TranscriptionSegment(
                startTime: segment.startTime,
                endTime: segment.endTime,
                speaker: segment.speaker,
                text: translatedText
            ))
        }

        print("[LLMService] ✅ Subtitle translation completed for \(segments.count) segments (target language only)")
        return result
    }

    func translateSegmentsToTargetLanguage(
        segments: [TranscriptionSegment],
        targetLanguage: String,
        settings: AppSettings
    ) async throws -> [TranscriptionSegment] {
        let (needsTranslation, skipIndices) = preFilterSegments(segments, targetLanguage: targetLanguage)
        print("[LLMService] 📊 Pre-filter: \(segments.count) total, \(needsTranslation.count) need translation, \(skipIndices.count) skipped")

        if needsTranslation.isEmpty {
            return segments
        }

        let batchSize = 30
        let maxConcurrency = min(4, (needsTranslation.count + batchSize - 1) / batchSize)
        var allTranslatedTexts: [(Int, String)] = []

        try await withThrowingTaskGroup(of: (Int, [Int: String]).self) { group in
            var batchIndex = 0
            for batchStart in stride(from: 0, to: needsTranslation.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, needsTranslation.count)
                let batchSegments = Array(needsTranslation[batchStart..<batchEnd])
                let originalIndices = Array((batchStart..<batchEnd).map { needsTranslation[$0].originalIndex })
                let currentBatchIndex = batchIndex

                if currentBatchIndex < maxConcurrency {
                    group.addTask {
                        let dict = try await self.translateBatchWithVerification(
                            batchSegments: batchSegments.map { TranscriptionSegment(startTime: $0.segment.startTime, endTime: $0.segment.endTime, speaker: $0.segment.speaker, text: $0.segment.text) },
                            batchOffset: originalIndices.first ?? 0,
                            targetLanguage: targetLanguage,
                            settings: settings,
                            maxRetries: 2
                        )
                        return (currentBatchIndex, dict)
                    }
                } else {
                    let dict = try await self.translateBatchWithVerification(
                        batchSegments: batchSegments.map { TranscriptionSegment(startTime: $0.segment.startTime, endTime: $0.segment.endTime, speaker: $0.segment.speaker, text: $0.segment.text) },
                        batchOffset: originalIndices.first ?? 0,
                        targetLanguage: targetLanguage,
                        settings: settings,
                        maxRetries: 2
                    )
                    for idx in originalIndices {
                        allTranslatedTexts.append((idx, dict[idx] ?? ""))
                    }
                }

                batchIndex += 1
            }

            var batchResults: [(Int, [Int: String])] = []
            for try await result in group {
                batchResults.append(result)
            }
            batchResults.sort { $0.0 < $1.0 }

            for (_, dict) in batchResults {
                for (idx, text) in dict {
                    allTranslatedTexts.append((idx, text))
                }
            }
        }

        allTranslatedTexts.sort { $0.0 < $1.0 }

        var translatedMap: [Int: String] = [:]
        for (idx, text) in allTranslatedTexts {
            translatedMap[idx] = text
        }

        var result: [TranscriptionSegment] = []
        for (index, segment) in segments.enumerated() {
            if skipIndices.contains(index) {
                result.append(segment)
            } else if let translated = translatedMap[index] {
                result.append(TranscriptionSegment(
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    speaker: segment.speaker,
                    text: translated.isEmpty ? segment.text : translated
                ))
            } else {
                result.append(segment)
            }
        }

        print("[LLMService] ✅ Parallel translation completed for \(segments.count) segments (\(maxConcurrency) concurrent batches)")
        return result
    }

    private struct FilteredSegment {
        let originalIndex: Int
        let segment: TranscriptionSegment
    }

    private func preFilterSegments(_ segments: [TranscriptionSegment], targetLanguage: String) -> (needsTranslation: [FilteredSegment], skipIndices: Set<Int>) {
        var needsTranslation: [FilteredSegment] = []
        var skipIndices: Set<Int> = []

        let numberPattern = try? NSRegularExpression(pattern: "^[\\d\\s\\.,\\-+]+$", options: [])
        let punctuationOnly = CharacterSet(charactersIn: "\u{FF0C}\u{3001}\u{3002}\u{FF01}\u{FF1F}\u{FF1B}\u{FF1A}\u{201C}\u{201D}\u{2018}\u{2019}\u{FF08}\u{FF09}\u{3010}\u{3011}\u{300A}\u{300B}\u{2014}\u{2026}\u{00B7},.?!;:'\"()-_")

        for (index, segment) in segments.enumerated() {
            let trimmed = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                skipIndices.insert(index)
                continue
            }

            if trimmed.count <= 2 && trimmed.range(of: "[\\d\\.,]", options: .regularExpression) != nil {
                skipIndices.insert(index)
                continue
            }

            if let pattern = numberPattern, let match = pattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                if match.range.length == trimmed.count {
                    skipIndices.insert(index)
                    continue
                }
            }

            var isPunctuationOnly = true
            let letterChars = CharacterSet.letters
            for char in trimmed.unicodeScalars {
                if !char.isASCII && !punctuationOnly.contains(char) && char != Unicode.Scalar(32) {
                    isPunctuationOnly = false
                    break
                }
                if char.isASCII && letterChars.contains(char) {
                    isPunctuationOnly = false
                    break
                }
            }
            if isPunctuationOnly && trimmed.count > 0 {
                skipIndices.insert(index)
                continue
            }

            needsTranslation.append(FilteredSegment(originalIndex: index, segment: segment))
        }

        return (needsTranslation, skipIndices)
    }

    func translateSingleText(text: String, targetLanguage: String, settings: AppSettings) async throws -> String {
        let prompt = """
【字幕翻译任务】

目标语言：\(targetLanguage)

【严格要求】
1. 将以下文本完整翻译为\(targetLanguage)
2. 绝对不能保留任何原始语言的词汇、短语或字符
3. 禁止输出类似"原文 -> 译文"的格式
4. 禁止在译文中夹杂原文（包括括号注释）
5. 只输出纯\(targetLanguage)翻译结果

待翻译文本：
\(text)

请直接输出翻译结果（不要添加任何解释）：
"""

        let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
        let baseURL = settings.llmBaseURL.isEmpty ? serviceType.defaultBaseURL : settings.llmBaseURL

        let translation: String
        switch serviceType {
        case .ollama:
            translation = try await callOllama(baseURL: baseURL, model: settings.llmModel, prompt: prompt)
        case .lmstudio:
            translation = try await callLMStudio(baseURL: baseURL, model: settings.llmModel, prompt: prompt)
        }

        var cleanedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)

        cleanedTranslation = removeOriginalLanguageResidue(from: cleanedTranslation, original: text)

        print("[LLMService] ✅ Single text translation completed")
        return cleanedTranslation
    }

    private func removeOriginalLanguageResidue(from translated: String, original: String) -> String {
        var cleaned = translated

        if cleaned.contains("->") || cleaned.contains("→") || cleaned.contains("-> ") {
            let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: "->→"))
            if parts.count >= 2 {
                let lastPart = parts.last?.trimmingCharacters(in: .whitespaces) ?? ""
                if !lastPart.isEmpty && lastPart.lowercased() != original.lowercased() {
                    cleaned = lastPart
                }
            }
        }

        return cleaned
    }
    
    private func translateBatchWithVerification(
        batchSegments: [TranscriptionSegment],
        batchOffset: Int,
        targetLanguage: String,
        settings: AppSettings,
        maxRetries: Int
    ) async throws -> [Int: String] {
        let expectedCount = batchSegments.count
        
        for attempt in 0...maxRetries {
            let indexedTexts = batchSegments.enumerated().map { (index, segment) in
                return "[\(batchOffset + index)] \(segment.text)"
            }.joined(separator: "\n")
            
            let prompt: String
            if attempt == 0 {
                prompt = """
【字幕批量翻译任务】

目标语言：\(targetLanguage)

【核心要求 - 必须严格遵守】
1. 将以下每一行文本完整翻译为纯\(targetLanguage)
2. 绝对禁止保留任何原始语言的词汇、字符或短语
3. 禁止输出"原文 -> 译文"或"原文（译文）"格式
4. 每行必须以 [编号] 开头，编号与原文完全一致
5. 不要合并、拆分或跳过任何行
6. 翻译结果必须是纯净的\(targetLanguage)文本，不能夹杂任何其他语言

【示例说明】
如果原文是法语，目标是中文：
❌ 错误：[0] Le polonier -> 波洛尼耶（保留了法文）
✅ 正确：[0] 波洛尼耶（完全翻译）

如果原文是英文，目标是中文：
❌ 错误：[0] Hello world -> 你好世界（格式错误）
✅ 正确：[0] 你好世界

待翻译文本（共 \(expectedCount) 行）：
\(indexedTexts)

请逐行输出翻译结果，每行格式为 [编号] 译文：
"""
            } else {
                prompt = """
【严重警告：前次翻译未通过校验，这是第 \(attempt + 1)/\(maxRetries + 1) 次重试】

【上次失败原因】
检测到翻译结果中仍包含原始语言内容或格式不符合要求

【本次必须做到】
1. 输出恰好 \(expectedCount) 行翻译结果
2. 每行格式：[编号] 纯\(targetLanguage)译文
3. 编号从 \(batchOffset) 到 \(batchOffset + expectedCount - 1)，连续不跳跃
4. 每一行都必须是100%的\(targetLanguage)，不能有任何一个外文字符
5. 绝对禁止：原文残留、混合语言、括号注释、箭头标记

原始文本（共 \(expectedCount) 行）：
\(indexedTexts)

请直接输出纯净的翻译结果：
"""
            }
            
            let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
            let baseURL = settings.llmBaseURL.isEmpty ? serviceType.defaultBaseURL : settings.llmBaseURL
            
            let translation: String
            switch serviceType {
            case .ollama:
                translation = try await callOllama(baseURL: baseURL, model: settings.llmModel, prompt: prompt)
            case .lmstudio:
                translation = try await callLMStudio(baseURL: baseURL, model: settings.llmModel, prompt: prompt)
            }
            
            let translationDict = parseIndexedTranslations(translation)
            
            let verificationResult = verifyTranslationConsistency(
                originalSegments: batchSegments,
                translatedDict: translationDict,
                batchOffset: batchOffset
            )
            
            print("[LLMService] Translation verification (attempt \(attempt + 1)): matched=\(verificationResult.matched), missing=\(verificationResult.missing), extra=\(verificationResult.extra)")
            
            if verificationResult.isFullyMatched {
                print("[LLMService] ✅ All translations verified successfully")
                return translationDict
            } else if attempt < maxRetries {
                print("[LLMService] ⚠️ Translation mismatch detected, retrying... (\(verificationResult.missing) missing, \(verificationResult.extra) extra)")
            }
        }
        
        let lastPrompt = batchSegments.enumerated().map { "[\(batchOffset + $0)] \($1.text)" }.joined(separator: "\n")
        let serviceType = LLMServiceType(rawValue: settings.llmService) ?? .ollama
        let baseURL = settings.llmBaseURL.isEmpty ? serviceType.defaultBaseURL : settings.llmBaseURL
        
        let fallbackTranslation: String
        switch serviceType {
        case .ollama:
            fallbackTranslation = try await callOllama(baseURL: baseURL, model: settings.llmModel, prompt: "Translate to \(targetLanguage). Keep one line per input line:\n\n\(lastPrompt)")
        case .lmstudio:
            fallbackTranslation = try await callLMStudio(baseURL: baseURL, model: settings.llmModel, prompt: "Translate to \(targetLanguage). Keep one line per input line:\n\n\(lastPrompt)")
        }
        
        let lines = fallbackTranslation.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var fallbackDict: [Int: String] = [:]
        
        for (lineIdx, line) in lines.enumerated() {
            let globalIdx = batchOffset + lineIdx
            if globalIdx < batchOffset + batchSegments.count {
                fallbackDict[globalIdx] = line
            }
        }
        
        print("[LLMService] Using fallback translation after \(maxRetries + 1) attempts")
        return fallbackDict
    }
    
    private struct VerificationResult {
        let matched: Int
        let missing: Int
        let extra: Int
        var isFullyMatched: Bool { return missing == 0 && extra == 0 }
    }
    
    private func verifyTranslationConsistency(
        originalSegments: [TranscriptionSegment],
        translatedDict: [Int: String],
        batchOffset: Int
    ) -> VerificationResult {
        var matched = 0
        var missing = 0
        
        for i in 0..<originalSegments.count {
            let globalIndex = batchOffset + i
            if let _ = translatedDict[globalIndex] {
                matched += 1
            } else {
                missing += 1
            }
        }
        
        let extraKeys = translatedDict.keys.filter { $0 < batchOffset || $0 >= batchOffset + originalSegments.count }
        let extra = extraKeys.count
        
        return VerificationResult(matched: matched, missing: missing, extra: extra)
    }
    
    private func parseIndexedTranslations(_ translation: String) -> [Int: String] {
        var dict: [Int: String] = [:]
        let lines = translation.components(separatedBy: .newlines)
        
        // 更严格的正则，捕获 [编号] 后的所有内容
        let pattern = "^\\[(\\d+)\\][:：]?\\s*(.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return dict
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            guard let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
                continue
            }
            
            if let indexRange = Range(match.range(at: 1), in: trimmed),
               let textRange = Range(match.range(at: 2), in: trimmed),
               let index = Int(trimmed[indexRange]) {
                var text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                
                // 二次检查：清理 LLM 可能误加的标记（如序号、引号、括号说明等）
                text = cleanTranslatedText(text)
                
                if !text.isEmpty {
                    dict[index] = text
                }
            }
        }
        
        return dict
    }

    private func cleanTranslatedText(_ text: String) -> String {
        var cleaned = text
        
        // 1. 移除首尾引号
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) || (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // 2. 移除常见的 LLM 注释/说明（如 "(翻译结果)", "[中文]", "译文：" 等）
        let noisePatterns = [
            "^译文[:：]\\s*",
            "^翻译[:：]\\s*",
            "^结果[:：]\\s*",
            "\\(.*?翻译.*?\\)",
            "\\[.*?\\]" // 移除所有方括号内容，因为我们已经提取了编号，内容里不应再有方括号
        ]
        
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        // 3. 移除行首可能误加的数字序号（如 "1. 内容"）
        let leadingNumberPattern = "^\\d+[\\.、\\s]+"
        if let regex = try? NSRegularExpression(pattern: leadingNumberPattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func callOllama(baseURL: String, model: String, prompt: String) async throws -> String {
        let apiPath = LLMServiceType.ollama.apiPath
        let fullURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + apiPath
        guard let url = URL(string: fullURL) else {
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
            
            // 直接返回原始响应，不做任何格式化处理，确保严格按照提示词要求输出
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
        let apiPath = LLMServiceType.lmstudio.apiPath
        let fullURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + apiPath
        guard let url = URL(string: fullURL) else {
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
        // Ollama 根路径返回 200；LM Studio /v1 路径返回 200
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