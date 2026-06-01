import SwiftUI
import PDFKit

struct InspectorView: View {
    let document: PDFDocument?
    let fileURL: URL?
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Document Inspector")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if let doc = document {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // File Section
                        GroupBox(label: Label("File Information", systemImage: "doc")) {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "Filename", value: filename(from: doc))
                                InfoRow(label: "Location", value: fileLocation(from: doc))
                                InfoRow(label: "File Size", value: fileSizeString(from: doc))
                                InfoRow(label: "PDF Version", value: pdfVersionString(from: doc))
                                InfoRow(label: "Page Count", value: "\(doc.pageCount)")
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Metadata Section
                        GroupBox(label: Label("Metadata / Attributes", systemImage: "info.circle")) {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "Title", value: attrString(doc, key: .titleAttribute))
                                InfoRow(label: "Author", value: attrString(doc, key: .authorAttribute))
                                InfoRow(label: "Subject", value: attrString(doc, key: .subjectAttribute))
                                InfoRow(label: "Creator", value: attrString(doc, key: .creatorAttribute))
                                InfoRow(label: "Producer", value: attrString(doc, key: .producerAttribute))
                                InfoRow(label: "Created", value: attrDateString(doc, key: .creationDateAttribute))
                                InfoRow(label: "Modified", value: attrDateString(doc, key: .modificationDateAttribute))
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Text("No Document Loaded")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .frame(width: 420, height: 480)
    }
    
    // Row Helper
    struct InfoRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack(alignment: .top) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                Spacer()
            }
        }
    }
    
    // Metadata Extractors
    private func filename(from doc: PDFDocument) -> String {
        return fileURL?.lastPathComponent ?? doc.documentURL?.lastPathComponent ?? "Untitled.pdf"
    }
    
    private func fileLocation(from doc: PDFDocument) -> String {
        return fileURL?.path ?? doc.documentURL?.path ?? "Unknown (unsaved)"
    }
    
    private func fileSizeString(from doc: PDFDocument) -> String {
        guard let url = fileURL ?? doc.documentURL else { return "Unknown" }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attrs[.size] as? UInt64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(size))
            }
        } catch {
            print("Failed to read file size: \(error)")
        }
        return "Unknown"
    }
    
    private func pdfVersionString(from doc: PDFDocument) -> String {
        return "\(doc.majorVersion).\(doc.minorVersion)"
    }
    
    private func attrString(_ doc: PDFDocument, key: PDFDocumentAttribute) -> String {
        guard let attrs = doc.documentAttributes,
              let val = attrs[key] as? String,
              !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "—"
        }
        return val
    }
    
    private func attrDateString(_ doc: PDFDocument, key: PDFDocumentAttribute) -> String {
        guard let attrs = doc.documentAttributes,
              let date = attrs[key] as? Date else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
