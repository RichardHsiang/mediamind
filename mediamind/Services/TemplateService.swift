import Foundation
import AppKit
import AppKit

/// Service for scanning and loading custom report templates
final class TemplateService {
    static let shared = TemplateService()
    
    private init() {}
    
    /// Scan template folder and return available template files
    /// - Parameter templatePath: Custom template folder path (required - no default)
    /// - Returns: Array of template file names (without extension)
    func scanTemplates(from templatePath: String?) -> [String] {
        guard let path = templatePath, !path.isEmpty else {
            print("[TemplateService] No template path configured")
            return []
        }
        
        let folderURL = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            print("[TemplateService] Template folder does not exist: \(folderURL.path)")
            return []
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            // Filter for HTML template files
            let templates = contents
                .filter { $0.pathExtension.lowercased() == "html" || $0.pathExtension.lowercased() == "htm" }
                .map { $0.deletingPathExtension().lastPathComponent }
            
            return templates.sorted()
        } catch {
            print("[TemplateService] Failed to scan templates: \(error)")
            return []
        }
    }
    
    /// Read template content from file
    /// - Parameters:
    ///   - templateName: Template file name (without extension)
    ///   - templatePath: Custom template folder path (required - no default)
    /// - Returns: Template content as String, or nil if not found
    func loadTemplate(named templateName: String, from templatePath: String?) -> String? {
        guard let path = templatePath, !path.isEmpty else {
            print("[TemplateService] No template path configured")
            return nil
        }
        
        let folderURL = URL(fileURLWithPath: path)
        
        // Try both .html and .htm extensions
        let htmlURL = folderURL.appendingPathComponent("\(templateName).html")
        let htmURL = folderURL.appendingPathComponent("\(templateName).htm")
        
        if FileManager.default.fileExists(atPath: htmlURL.path) {
            return try? String(contentsOf: htmlURL, encoding: .utf8)
        } else if FileManager.default.fileExists(atPath: htmURL.path) {
            return try? String(contentsOf: htmURL, encoding: .utf8)
        }
        
        print("[TemplateService] Template not found: \(templateName)")
        return nil
    }
    
    /// Open template folder in Finder
    func openTemplateFolder(at path: String?) {
        guard let path = path, !path.isEmpty else {
            print("[TemplateService] No template path configured")
            return
        }
        
        let folderURL = URL(fileURLWithPath: path)
        
        // Ensure folder exists before opening
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                print("[TemplateService] Failed to create template folder: \(error)")
                return
            }
        }
        
        NSWorkspace.shared.open(folderURL)
    }
}