import Foundation

struct ReportService {
    static let shared = ReportService()

    func generateAnalysisReport(transcription: String, rawTranscription: String, analysis: String, outputDir: URL, screenshotURLs: [URL] = []) async throws -> [URL] {
        // 确保输出目录存在
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        
        let transcriptionURL = outputDir.appendingPathComponent("audio.md")
        let transcriptionContent = """
        # 原始转录文本

        \(rawTranscription)

        ---

        *生成时间: \(Date().formatted())*
        """
        try transcriptionContent.write(to: transcriptionURL, atomically: true, encoding: .utf8)

        let analysisURL = outputDir.appendingPathComponent("audio_analysis.md")
         
        var analysisContent = "# AI 分析结果\n\n"
        analysisContent += analysis
         
        if !screenshotURLs.isEmpty {
            analysisContent = insertScreenshotsIntelligently(content: analysisContent, screenshotURLs: screenshotURLs)
        }
         
        analysisContent += """

        ---

        *生成时间: \(Date().formatted())*
        """
        try analysisContent.write(to: analysisURL, atomically: true, encoding: .utf8)

        return [transcriptionURL, analysisURL]
    }

    private func insertScreenshotsIntelligently(content: String, screenshotURLs: [URL]) -> String {
        guard !screenshotURLs.isEmpty else { return content }
        
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var screenshotIndex = 0
        
        for (index, line) in lines.enumerated() {
            result.append(line)
            
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            let sectionPattern = "^#{1,3}\\s*\\d+[.、]"
            let hasSectionHeader = trimmedLine.range(of: sectionPattern, options: .regularExpression) != nil
            
            let stepPattern = "(步骤|step|操作|过程)[：:]?\\s*\\d+"
            let hasStepHeader = trimmedLine.range(of: stepPattern, options: .caseInsensitive) != nil
            
            let featurePattern = "(功能|特性|亮点|界面)[：:]"
            let hasFeatureHeader = trimmedLine.range(of: featurePattern, options: .caseInsensitive) != nil
            
            let cautionPattern = "(注意|易错|警告|提示)[：:]"
            let hasCautionHeader = trimmedLine.range(of: cautionPattern, options: .caseInsensitive) != nil
            
            if (hasSectionHeader || hasStepHeader || hasFeatureHeader || hasCautionHeader) && screenshotIndex < screenshotURLs.count {
                let screenshotURL = screenshotURLs[screenshotIndex]
                let relativePath = "images/\(screenshotURL.lastPathComponent)"
                screenshotIndex += 1
                
                result.append("")
                result.append("**截图说明：**")
                result.append("")
                result.append("![截图\(screenshotIndex)](\(relativePath))")
                result.append("")
            }
            
            if index == lines.count - 1 && screenshotIndex < screenshotURLs.count {
                result.append("")
                result.append("## 补充截图")
                result.append("")
                
                for i in screenshotIndex..<screenshotURLs.count {
                    let screenshotURL = screenshotURLs[i]
                    let relativePath = "images/\(screenshotURL.lastPathComponent)"
                    result.append("![补充截图\(i + 1)](\(relativePath))")
                    result.append("")
                }
            }
        }
        
        return result.joined(separator: "\n")
    }

    func generateMeetingReport(transcription: String, analysis: String, templateName: String, outputDir: URL, templatePath: String? = nil) async throws -> URL {
        let outputURL = outputDir.appendingPathComponent("meeting_report.html")

        guard let path = templatePath, !path.isEmpty else {
            print("[ReportService] No template path configured")
            throw ProcessingError.templatePathNotConfigured
        }
        
        print("[ReportService] Loading template '\(templateName)' from path: \(path)")

        guard let templateContent = TemplateService.shared.loadTemplate(named: templateName, from: path) else {
            print("[ReportService] Template '\(templateName)' not found at: \(path)")
            throw ProcessingError.templatePathNotConfigured
        }

        let cleanAnalysis = cleanMarkdown(analysis)
        let meetingInfo = parseMeetingInfo(from: cleanAnalysis)
        let contentBlocks = parseContentBlocks(from: cleanAnalysis)
        
        // 构建会议内容
        let fullContent = """
        一、上次会议问题
        \(contentBlocks.previousIssues)

        二、本次会议内容
        \(contentBlocks.currentContent)

        三、本次会议决议
        \(contentBlocks.resolutions)
        """
        
        // 严格分页：每页最多 28 行，留白 2 行，即实际每页 26 行
        let maxLinesPerPage = 28
        let blankLines = 2
        let effectiveLinesPerPage = maxLinesPerPage - blankLines
        
        // 分页逻辑
        let pages = paginateContent(fullContent, linesPerPage: effectiveLinesPerPage)
        print("[ReportService] Pagination created \(pages.count) pages")
        
        // 提取 CSS 和 Header/Footer 结构
        let css = extractCSS(from: templateContent)
        let titleHtml = """
        <h1 class="title">会 议 纪 要</h1>
        <table class="info-table">
            <tr>
                <td class="label">会议主题</td>
                <td class="content-cell">
                    <input type="text" value="\(escapeHTML(meetingInfo.theme))" placeholder="请输入会议主题...">
                </td>
                <td class="label" style="width: 50px;">编号</td>
                <td class="content-cell" style="width: 33%;">
                    <input type="text" placeholder="请输入编号...">
                </td>
            </tr>
            <tr>
                <td class="label">会议时间</td>
                <td class="content-cell">
                    <input type="text" placeholder="请输入会议时间...">
                </td>
                <td class="label" style="width: 50px;">会议地点</td>
                <td class="content-cell" style="width: 33%;">
                    <input type="text" placeholder="请输入会议地点...">
                </td>
            </tr>
            <tr>
                <td class="label">参会人员</td>
                <td class="content-cell" colspan="3">
                    <textarea placeholder="请输入参会人员..."></textarea>
                </td>
            </tr>
        </table>
        """
        
        let signatureTableHtml = """
        <table class="signature-table">
            <tr>
                <td class="label">编制</td>
                <td class="sign-cell"><input type="text" placeholder=""></td>
                <td class="label">审核</td>
                <td class="sign-cell"><input type="text" placeholder=""></td>
                <td class="label">批准</td>
                <td class="sign-cell"><input type="text" placeholder=""></td>
            </tr>
        </table>
        """

        // 构建最终 HTML
        var htmlPages: [String] = []
        for (index, pageContent) in pages.enumerated() {
            let pageNum = index + 1
            let isFirst = (index == 0)
            let isLast = (index == pages.count - 1)
            
            var pageHtml = "<div class=\"page\">\n"
            
            // 第一页包含标题和信息表
            if isFirst {
                pageHtml += titleHtml
            }
            
            // 内容区域
            pageHtml += "<div class=\"content-section\(index > 0 ? " has-top-border" : "")\">\n"
            pageHtml += "<div class=\"content-header\">会议内容</div>\n"
            pageHtml += "<div class=\"content-body\" contenteditable=\"true\">\n"
            pageHtml += formatContentForPage(pageContent)
            pageHtml += "</div>\n"
            pageHtml += "</div>\n"
            
            // 最后一页包含签名表
            if isLast {
                pageHtml += signatureTableHtml
            }
            
            // 页码
            pageHtml += "<div class=\"page-number\">第 \(pageNum) 页 共 \(pages.count) 页</div>\n"
            pageHtml += "</div>\n"
            
            htmlPages.append(pageHtml)
        }
        
        let finalHtml = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>会议纪要</title>
            <style>
                \(css)
            </style>
        </head>
        <body>
            <div id="pages-container">
                \(htmlPages.joined(separator: "\n"))
            </div>
        </body>
        </html>
        """
        
        try finalHtml.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func extractCSS(from template: String) -> String {
        let pattern = "<style>([\\s\\S]*?)</style>"
        if let range = template.range(of: pattern, options: .regularExpression) {
            let styleTag = template[range]
            return styleTag.replacingOccurrences(of: "<style>", with: "").replacingOccurrences(of: "</style>", with: "")
        }
        return ""
    }

    private func paginateContent(_ content: String, linesPerPage: Int) -> [String] {
        let lines = content.components(separatedBy: "\n")
        var pages: [String] = []
        var currentPageLines: [String] = []
        var currentLineCount = 0
        
        let maxCharsPerLine = 40 // 估算每行字符数

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if currentLineCount < linesPerPage {
                    currentPageLines.append("")
                    currentLineCount += 1
                } else {
                    pages.append(currentPageLines.joined(separator: "\n"))
                    currentPageLines = [""]
                    currentLineCount = 1
                }
                continue
            }
            
            // 计算该行实际占据的视觉行数
            let visualLines = max(1, Int(ceil(Double(line.count) / Double(maxCharsPerLine))))
            
            if currentLineCount + visualLines > linesPerPage {
                // 如果当前页放不下，且当前页已有内容，则分页
                if !currentPageLines.isEmpty {
                    pages.append(currentPageLines.joined(separator: "\n"))
                    currentPageLines = []
                    currentLineCount = 0
                }
                
                // 处理超长行跨页（简单截断处理）
                if visualLines > linesPerPage {
                    var remainingText = line
                    while !remainingText.isEmpty {
                        let chunkLength = min(remainingText.count, linesPerPage * maxCharsPerLine)
                        let chunk = String(remainingText.prefix(chunkLength))
                        pages.append(chunk)
                        remainingText = String(remainingText.dropFirst(chunkLength))
                    }
                    continue
                }
            }
            
            currentPageLines.append(line)
            currentLineCount += visualLines
        }
        
        if !currentPageLines.isEmpty {
            pages.append(currentPageLines.joined(separator: "\n"))
        }
        
        return pages.isEmpty ? [""] : pages
    }

    func generateSubtitleFile(segments: [TranscriptionSegment], outputDir: URL, format: String = "SRT", languageOrder: String = "cn-en", baseFileName: String = "subtitles") async throws -> URL {
        let ext = format.lowercased()
        let outputURL = outputDir.appendingPathComponent("\(baseFileName).\(ext)")

        let content: String
        switch ext {
        case "srt":
            content = generateSRT(segments: segments)
        case "vtt":
            content = generateVTT(segments: segments)
        case "ass":
            content = generateASS(segments: segments)
        default:
            content = generateSRT(segments: segments)
        }

        try content.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func generateSRT(segments: [TranscriptionSegment]) -> String {
        var lines: [String] = []
        for (index, segment) in segments.enumerated() {
            lines.append("\(index + 1)")
            lines.append("\(formatSRTTime(segment.startTime)) --> \(formatSRTTime(segment.endTime))")
            // 二次检查：确保字幕内容纯净，移除 [x] 序号等非字幕内容
            let cleanedText = cleanSubtitleContent(segment.text)
            // 自动换行：保持每行字数在18-25字之间，最多两行
            let wrappedText = wrapSubtitleText(cleanedText, minChars: 18, maxChars: 25)
            lines.append(wrappedText)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func formatSRTTime(_ timeString: String) -> String {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else {
            return "00:00:00,000"
        }
        let hours = components[0]
        let minutes = components[1]
        let secondsAndMs = components[2]

        if secondsAndMs.contains(".") {
            let parts = secondsAndMs.components(separatedBy: ".")
            let secs = parts[0]
            let ms = parts.count > 1 ? String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0) : "000"
            return "\(hours):\(minutes):\(secs),\(ms)"
        } else if secondsAndMs.contains(",") {
            let parts = secondsAndMs.components(separatedBy: ",")
            let secs = parts[0]
            let ms = parts.count > 1 ? String(parts[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0) : "000"
            return "\(hours):\(minutes):\(secs),\(ms)"
        } else {
            return "\(hours):\(minutes):\(secondsAndMs),000"
        }
    }

    private func generateVTT(segments: [TranscriptionSegment]) -> String {
        var lines: [String] = ["WEBVTT", ""]
        for segment in segments {
            lines.append("\(formatVTTTime(segment.startTime)) --> \(formatVTTTime(segment.endTime))")
            // 二次检查：确保字幕内容纯净
            let cleanedText = cleanSubtitleContent(segment.text)
            lines.append(cleanedText)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func formatVTTTime(_ timeString: String) -> String {
        return formatSRTTime(timeString).replacingOccurrences(of: ",", with: ".")
    }

    private func generateASS(segments: [TranscriptionSegment]) -> String {
        var lines: [String] = [
            "[Script Info]",
            "Title: Generated by MediaMind",
            "ScriptType: v4.00+",
            "",
            "[V4+ Styles]",
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
            "Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1",
            "",
            "[Events]",
            "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
        ]

        for segment in segments {
            // 二次检查：确保字幕内容纯净
            let cleanedText = cleanSubtitleContent(segment.text)
            lines.append("Dialogue: 0,\(segment.startTime),\(segment.endTime),Default,\(segment.speaker),0,0,0,,\(cleanedText)")
        }

        return lines.joined(separator: "\n")
    }

    private func cleanSubtitleContent(_ text: String) -> String {
        var cleaned = text
        
        // 1. 移除首尾引号
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) || (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // 2. 移除常见的 LLM 误加的标记和注释
        let noisePatterns = [
            "^\\[\\d+\\][:：]?\\s*", // 移除可能残余的 [编号]
            "^译文[:：]\\s*",
            "^翻译[:：]\\s*",
            "^结果[:：]\\s*",
            "\\(.*?翻译.*?\\)",
            "\\[.*?\\]", // 移除所有方括号及其内容
            "\\{.*?\\}", // 移除大括号内容
            "译文[:：].*$", // 移除行尾的“译文：xxx”
            "^序号[:：]\\s*\\d+\\s*", // 移除误加的序号标记
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
    
    /// 字幕文本自动换行，最多只分为上下两行，保持每行字数相当（18-25字之间）
    /// - 标点符号不允许单独占据一行
    private func wrapSubtitleText(_ text: String, minChars: Int = 18, maxChars: Int = 25) -> String {
        // 如果文本已经包含换行符，说明已经格式化过，直接返回
        if text.contains("\n") {
            return text
        }
        
        // 清理文本：去除首尾空白
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // 如果文本长度小于等于最大字符数，不需要换行
        if trimmed.count <= maxChars {
            return trimmed
        }
        
        // 标点符号集合（用于断行，但不能单独成行）
        let breakPunctuation: Set<Character> = ["，", "、", "；", "：", ",", ";", ":", " "]
        let endPunctuation: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        
        // 尝试找到最佳的断行位置
        let totalLength = trimmed.count
        let idealBreakPos = totalLength / 2 // 理想断点位置（中间）
        
        // 搜索范围：在 minChars 到 maxChars 之间寻找最佳断点
        let searchStart = max(minChars, idealBreakPos - 5)
        let searchEnd = min(maxChars, totalLength - minChars)
        
        // 如果总长度超过两行最大限制（50字），则强制断在 maxChars 处
        if totalLength > maxChars * 2 {
            return forceWrapTwoLines(trimmed, maxChars: maxChars, breakPunctuation: breakPunctuation)
        }
        
        // 在搜索范围内寻找最佳断点
        var bestBreakIndex: String.Index? = nil
        var bestScore = Int.max
        
        let searchStartIndex = trimmed.index(trimmed.startIndex, offsetBy: searchStart)
        let searchEndIndex = trimmed.index(trimmed.startIndex, offsetBy: searchEnd)
        
        var currentIndex = searchStartIndex
        while currentIndex <= searchEndIndex {
            let char = trimmed[currentIndex]
            if breakPunctuation.contains(char) {
                // 检查断点后的字符是否不是标点
                let nextIndex = trimmed.index(after: currentIndex)
                if nextIndex < trimmed.endIndex {
                    let nextChar = trimmed[nextIndex]
                    if !breakPunctuation.contains(nextChar) && !endPunctuation.contains(nextChar) {
                        // 计算评分：越接近理想断点位置越好
                        let distance = abs(trimmed.distance(from: trimmed.startIndex, to: currentIndex) - idealBreakPos)
                        if distance < bestScore {
                            bestScore = distance
                            bestBreakIndex = trimmed.index(after: currentIndex) // 断在标点之后
                        }
                    }
                }
            }
            currentIndex = trimmed.index(after: currentIndex)
        }
        
        // 如果没找到合适的标点断点，在范围内寻找空格处断行
        if bestBreakIndex == nil {
            currentIndex = searchStartIndex
            while currentIndex <= searchEndIndex {
                let char = trimmed[currentIndex]
                if char == " " {
                    bestBreakIndex = trimmed.index(after: currentIndex)
                    break
                }
                currentIndex = trimmed.index(after: currentIndex)
            }
        }
        
        // 如果还是没有找到合适的断点，在中间位置强制断行
        if bestBreakIndex == nil {
            let midPos = totalLength / 2
            bestBreakIndex = trimmed.index(trimmed.startIndex, offsetBy: midPos)
        }
        
        // 生成分行结果
        if let breakIdx = bestBreakIndex {
            let firstLine = String(trimmed[..<breakIdx]).trimmingCharacters(in: .whitespaces)
            let secondLine = String(trimmed[breakIdx...]).trimmingCharacters(in: .whitespaces)
            
            // 检查第二行是否以标点开头，如果是则调整到第一行末尾
            var adjustedFirstLine = firstLine
            var adjustedSecondLine = secondLine
            
            if let firstChar = secondLine.first {
                if breakPunctuation.contains(firstChar) || endPunctuation.contains(firstChar) {
                    adjustedFirstLine = firstLine + String(firstChar)
                    adjustedSecondLine = String(secondLine.dropFirst())
                }
            }
            
            // 确保两行长度合理
            if adjustedSecondLine.isEmpty {
                return adjustedFirstLine
            }
            
            return adjustedFirstLine + "\n" + adjustedSecondLine
        }
        
        return trimmed
    }
    
    /// 强制将文本分为两行，每行不超过 maxChars
    private func forceWrapTwoLines(_ text: String, maxChars: Int, breakPunctuation: Set<Character>) -> String {
        let breakPos = maxChars
        let breakIndex = text.index(text.startIndex, offsetBy: breakPos)
        
        var firstLine = String(text[..<breakIndex])
        var secondLine = String(text[breakIndex...])
        
        // 调整标点位置，确保标点不单独成行
        if let firstCharOfSecond = secondLine.first {
            if breakPunctuation.contains(firstCharOfSecond) {
                firstLine += String(firstCharOfSecond)
                secondLine = String(secondLine.dropFirst())
            }
        }
        
        return firstLine + "\n" + secondLine
    }

    private func formatContentForPage(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var html = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed == "&nbsp;" {
                html += "<p>&nbsp;</p>\n"
                continue
            }

            if trimmed.hasPrefix("一、") || trimmed.hasPrefix("二、") || trimmed.hasPrefix("三、") {
                html += "<p class=\"section-title\" contenteditable=\"true\">\(escapeHTML(trimmed))</p>\n"
            } else {
                html += "<p contenteditable=\"true\">\(escapeHTML(trimmed))</p>\n"
            }
        }

        return html
    }

    private func parseMeetingInfo(from analysis: String) -> MeetingInfo {
        var info = MeetingInfo()

        if let themeMatch = analysis.range(of: "会议主题[:：]\\s*(.+)", options: .regularExpression) {
            let matched = String(analysis[themeMatch])
            if let colonIndex = matched.firstIndex(of: ":") ?? matched.firstIndex(of: "：") {
                let startIndex = matched.index(after: colonIndex)
                info.theme = String(matched[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if info.theme.isEmpty {
            let lines = analysis.components(separatedBy: .newlines)
            if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                let cleanLine = firstLine.trimmingCharacters(in: .whitespaces)
                if cleanLine.hasPrefix("#") {
                    info.theme = cleanLine.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                } else {
                    info.theme = cleanLine
                }
            }
        }

        return info
    }

    private func parseContentBlocks(from analysis: String) -> ContentBlocks {
        var blocks = ContentBlocks()

        // 更加宽松的正则表达式，支持多种编号格式和换行
        let pattern1 = "(?:[一1]\\.?、?\\s*)?上次会议问题[\\s:：]*([\\s\\S]*?)(?=(?:[二2]\\.?、?\\s*)?本次会议内容[\\s:：]|$)"
        let pattern2 = "(?:[二2]\\.?、?\\s*)?本次会议内容[\\s:：]*([\\s\\S]*?)(?=(?:[三3]\\.?、?\\s*)?本次会议决议[\\s:：]|$)"
        let pattern3 = "(?:[三3]\\.?、?\\s*)?本次会议决议[\\s:：]*([\\s\\S]*?)$"

        if let range = analysis.range(of: pattern1, options: .regularExpression) {
            let matched = String(analysis[range])
            if let content = extractContentAfterMarker(matched, markers: ["上次会议问题", ":", "："]) {
                blocks.previousIssues = content.isEmpty ? "无" : content
            }
        }

        if let range = analysis.range(of: pattern2, options: .regularExpression) {
            let matched = String(analysis[range])
            if let content = extractContentAfterMarker(matched, markers: ["本次会议内容", ":", "："]) {
                blocks.currentContent = content.isEmpty ? "（无内容）" : content
            }
        }

        if let range = analysis.range(of: pattern3, options: .regularExpression) {
            let matched = String(analysis[range])
            if let content = extractContentAfterMarker(matched, markers: ["本次会议决议", ":", "："]) {
                blocks.resolutions = content.isEmpty ? "（无决议）" : content
            }
        }

        // 如果解析出来的主要内容都是默认值，且原始分析文本不为空，则将整个分析文本放入“本次会议内容”
        if (blocks.currentContent == "（无内容）" || blocks.currentContent.isEmpty) && 
           (blocks.previousIssues == "无" || blocks.previousIssues.isEmpty) && 
           (blocks.resolutions == "（无决议）" || blocks.resolutions.isEmpty) {
            if !analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.currentContent = analysis
            }
        }

        return blocks
    }

    private func extractContentAfterMarker(_ text: String, markers: [String]) -> String? {
        var remaining = text

        for marker in markers {
            if let range = remaining.range(of: marker) {
                remaining = String(remaining[range.upperBound...])
            }
        }

        let content = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        return content
    }

    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }

    private func cleanMarkdown(_ text: String) -> String {
        print("[ReportService] Using raw analysis text without markdown cleaning")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MeetingInfo {
    var theme: String = ""
    var host: String = ""
    var time: String = ""
    var location: String = ""
    var participants: String = ""
}

struct ContentBlocks {
    var previousIssues: String = "无"
    var currentContent: String = "（无内容）"
    var resolutions: String = "（无决议）"
}
