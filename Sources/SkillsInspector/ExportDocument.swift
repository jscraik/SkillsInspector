import SwiftUI
import UniformTypeIdentifiers
import SkillsCore

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json, .html, .xml] }
    
    let findings: [Finding]
    let format: ExportFormat
    
    init(findings: [Finding], format: ExportFormat) {
        self.findings = findings
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not used for export-only document
        self.findings = []
        self.format = .json
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content = try ExportService.generate(findings: findings, format: format)
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

extension ExportFormat {
    var contentType: UTType {
        switch self {
        case .json:
            return .json
        case .csv:
            return .commaSeparatedText
        case .html:
            return .html
        case .markdown:
            return .plainText
        case .junit:
            return .xml
        }
    }
    
    var icon: String {
        switch self {
        case .json:
            return "curlybraces"
        case .csv:
            return "tablecells"
        case .html:
            return "globe"
        case .markdown:
            return "doc.text"
        case .junit:
            return "testtube.2"
        }
    }
}
