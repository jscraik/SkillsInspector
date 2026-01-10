import Foundation

/// Export format for validation reports
public enum ExportFormat: String, CaseIterable, Sendable {
    case json = "JSON"
    case csv = "CSV"
    case html = "HTML"
    case markdown = "Markdown"
    case junit = "JUnit XML"
    
    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .html: return "html"
        case .markdown: return "md"
        case .junit: return "xml"
        }
    }
}

/// Service for exporting validation findings to various formats
public struct ExportService: Sendable {
    
    /// Export findings to a file
    public static func export(findings: [Finding], format: ExportFormat, to url: URL) throws {
        let content = try generate(findings: findings, format: format)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Generate export content in the specified format
    public static func generate(findings: [Finding], format: ExportFormat) throws -> String {
        switch format {
        case .json:
            return try generateJSON(findings: findings)
        case .csv:
            return generateCSV(findings: findings)
        case .html:
            return generateHTML(findings: findings)
        case .markdown:
            return generateMarkdown(findings: findings)
        case .junit:
            return generateJUnit(findings: findings)
        }
    }
    
    // MARK: - Format Generators
    
    private static func generateJSON(findings: [Finding]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let export = JSONExport(
            timestamp: Date(),
            totalFindings: findings.count,
            errorCount: findings.filter { $0.severity == .error }.count,
            warningCount: findings.filter { $0.severity == .warning }.count,
            infoCount: findings.filter { $0.severity == .info }.count,
            findings: findings
        )
        
        let data = try encoder.encode(export)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private static func generateCSV(findings: [Finding]) -> String {
        var csv = "Severity,Rule ID,Agent,File,Line,Column,Message\n"
        
        for finding in findings {
            let severity = finding.severity.rawValue
            let ruleID = csvEscape(finding.ruleID)
            let agent = finding.agent.rawValue
            let file = csvEscape(finding.fileURL.lastPathComponent)
            let line = finding.line.map { String($0) } ?? ""
            let column = finding.column.map { String($0) } ?? ""
            let message = csvEscape(finding.message)
            
            csv += "\(severity),\(ruleID),\(agent),\(file),\(line),\(column),\(message)\n"
        }
        
        return csv
    }
    
    private static func generateHTML(findings: [Finding]) -> String {
        let grouped = Dictionary(grouping: findings) { $0.severity }
        
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Skills Validation Report</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                    max-width: 1200px;
                    margin: 40px auto;
                    padding: 0 20px;
                    background: #f5f5f7;
                }
                .header {
                    background: white;
                    padding: 24px;
                    border-radius: 12px;
                    margin-bottom: 20px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                h1 { margin: 0 0 16px 0; color: #1d1d1f; }
                .stats {
                    display: flex;
                    gap: 16px;
                    flex-wrap: wrap;
                }
                .stat {
                    padding: 12px 16px;
                    background: #f5f5f7;
                    border-radius: 8px;
                }
                .stat-label { font-size: 12px; color: #86868b; text-transform: uppercase; }
                .stat-value { font-size: 24px; font-weight: 600; }
                .section {
                    background: white;
                    padding: 24px;
                    border-radius: 12px;
                    margin-bottom: 20px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                }
                th {
                    text-align: left;
                    padding: 12px;
                    border-bottom: 2px solid #e5e5e7;
                    font-weight: 600;
                    color: #1d1d1f;
                }
                td {
                    padding: 12px;
                    border-bottom: 1px solid #e5e5e7;
                    vertical-align: top;
                }
                .severity-error { color: #ff3b30; }
                .severity-warning { color: #ff9500; }
                .severity-info { color: #007aff; }
                .badge {
                    display: inline-block;
                    padding: 4px 8px;
                    border-radius: 4px;
                    font-size: 11px;
                    font-weight: 600;
                    text-transform: uppercase;
                }
                .badge-error { background: #ffebee; color: #ff3b30; }
                .badge-warning { background: #fff3e0; color: #ff9500; }
                .badge-info { background: #e3f2fd; color: #007aff; }
                code {
                    background: #f5f5f7;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 12px;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Skills Validation Report</h1>
                <div class="stats">
                    <div class="stat">
                        <div class="stat-label">Total Findings</div>
                        <div class="stat-value">\(findings.count)</div>
                    </div>
                    <div class="stat">
                        <div class="stat-label">Errors</div>
                        <div class="stat-value severity-error">\(grouped[.error]?.count ?? 0)</div>
                    </div>
                    <div class="stat">
                        <div class="stat-label">Warnings</div>
                        <div class="stat-value severity-warning">\(grouped[.warning]?.count ?? 0)</div>
                    </div>
                    <div class="stat">
                        <div class="stat-label">Info</div>
                        <div class="stat-value severity-info">\(grouped[.info]?.count ?? 0)</div>
                    </div>
                </div>
            </div>
        """
        
        for severity in Severity.allCases {
            guard let items = grouped[severity], !items.isEmpty else { continue }
            
            html += """
            <div class="section">
                <h2>\(severity.rawValue.capitalized) (\(items.count))</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Rule</th>
                            <th>Agent</th>
                            <th>File</th>
                            <th>Location</th>
                            <th>Message</th>
                        </tr>
                    </thead>
                    <tbody>
            """
            
            for finding in items {
                let location = [
                    finding.line.map { "Line \($0)" },
                    finding.column.map { "Col \($0)" }
                ].compactMap { $0 }.joined(separator: ", ")
                
                html += """
                        <tr>
                            <td><code>\(htmlEscape(finding.ruleID))</code></td>
                            <td><span class="badge badge-\(severity.rawValue)">\(finding.agent.rawValue)</span></td>
                            <td><code>\(htmlEscape(finding.fileURL.lastPathComponent))</code></td>
                            <td>\(location)</td>
                            <td>\(htmlEscape(finding.message))</td>
                        </tr>
                """
            }
            
            html += """
                    </tbody>
                </table>
            </div>
            """
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private static func generateMarkdown(findings: [Finding]) -> String {
        var md = "# Skills Validation Report\n\n"
        
        md += "## Summary\n\n"
        md += "- **Total Findings:** \(findings.count)\n"
        md += "- **Errors:** \(findings.filter { $0.severity == .error }.count)\n"
        md += "- **Warnings:** \(findings.filter { $0.severity == .warning }.count)\n"
        md += "- **Info:** \(findings.filter { $0.severity == .info }.count)\n\n"
        
        let grouped = Dictionary(grouping: findings) { $0.severity }
        
        for severity in Severity.allCases {
            guard let items = grouped[severity], !items.isEmpty else { continue }
            
            md += "## \(severity.rawValue.capitalized) (\(items.count))\n\n"
            
            for finding in items {
                let location = [
                    finding.line.map { "Line \($0)" },
                    finding.column.map { "Col \($0)" }
                ].compactMap { $0 }.joined(separator: ", ")
                
                md += "### `\(finding.ruleID)`\n\n"
                md += "- **Agent:** \(finding.agent.rawValue)\n"
                md += "- **File:** `\(finding.fileURL.lastPathComponent)`\n"
                if !location.isEmpty {
                    md += "- **Location:** \(location)\n"
                }
                md += "- **Message:** \(finding.message)\n\n"
            }
        }
        
        return md
    }
    
    private static func generateJUnit(findings: [Finding]) -> String {
        let errorCount = findings.filter { $0.severity == .error }.count
        let warningCount = findings.filter { $0.severity == .warning }.count
        
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites>
            <testsuite name="Skills Validation" tests="\(findings.count)" failures="\(errorCount + warningCount)" errors="0" skipped="0">
        """
        
        let grouped = Dictionary(grouping: findings) { $0.fileURL.path }
        
        for (file, items) in grouped.sorted(by: { $0.key < $1.key }) {
            for finding in items {
                let testName = "\(finding.fileURL.lastPathComponent) - \(finding.ruleID)"
                
                xml += """
                    <testcase name="\(xmlEscape(testName))" classname="\(xmlEscape(file))">
                """
                
                if finding.severity != .info {
                    xml += """
                        <failure message="\(xmlEscape(finding.message))" type="\(finding.severity.rawValue)">
                File: \(xmlEscape(file))
                Rule: \(xmlEscape(finding.ruleID))
                Agent: \(finding.agent.rawValue)
                Location: Line \(finding.line ?? 0), Column \(finding.column ?? 0)
                        </failure>
                """
                }
                
                xml += """
                    </testcase>
                """
            }
        }
        
        xml += """
            </testsuite>
        </testsuites>
        """
        
        return xml
    }
    
    // MARK: - Helpers
    
    private static func csvEscape(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
    
    private static func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
    
    private static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Export Models

private struct JSONExport: Codable {
    let timestamp: Date
    let totalFindings: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let findings: [Finding]
}

extension Severity {
    static let allCases: [Severity] = [.error, .warning, .info]
}
