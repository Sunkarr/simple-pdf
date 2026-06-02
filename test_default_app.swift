import AppKit
import UniformTypeIdentifiers

if let url = NSWorkspace.shared.urlForApplication(toOpen: .pdf) {
    print("Found: \(url.path)")
}
