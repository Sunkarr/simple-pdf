import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

// Define the focused value key for global Cmd+F search routing
struct SearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct CloseActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct OpenTabActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct OpenWindowActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var searchAction: SearchActionKey.Value? {
        get { self[SearchActionKey.self] }
        set { self[SearchActionKey.self] = newValue }
    }
    
    var closeAction: CloseActionKey.Value? {
        get { self[CloseActionKey.self] }
        set { self[CloseActionKey.self] = newValue }
    }
    
    var openTabAction: OpenTabActionKey.Value? {
        get { self[OpenTabActionKey.self] }
        set { self[OpenTabActionKey.self] = newValue }
    }
    
    var openWindowAction: OpenWindowActionKey.Value? {
        get { self[OpenWindowActionKey.self] }
        set { self[OpenWindowActionKey.self] = newValue }
    }
}

// Commands definition for global search menu item
struct SearchCommands: Commands {
    @FocusedValue(\.searchAction) var searchAction
    
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find...") {
                searchAction?()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(searchAction == nil)
        }
    }
}

// Commands for File menu: Cmd+O (open as tab) and Cmd+N (open in new window)
struct FileOpenCommands: Commands {
    @FocusedValue(\.openTabAction) var openTabAction
    @FocusedValue(\.openWindowAction) var openWindowAction
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open in New Tab...") {
                openTabAction?()
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Button("Open in New Window...") {
                openWindowAction?()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}

// Commands definition for Close (Cmd+W) routing
struct CloseCommands: Commands {
    @FocusedValue(\.closeAction) var closeAction
    
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Close Document") {
                if let action = closeAction {
                    action()
                } else {
                    NSApp.keyWindow?.performClose(nil)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

// Save the paths of all open PDF documents to restore later
func saveOpenDocuments() {
    let urls = NSApplication.shared.windows.compactMap { window -> String? in
        guard let contentView = window.contentView else { return nil }
        return findPDFView(in: contentView)?.document?.documentURL?.path
    }
    UserDefaults.standard.set(urls, forKey: "OpenPDFPaths")
}

// Helper to recursively find CustomPDFView in view hierarchy
func findPDFView(in view: NSView) -> CustomPDFView? {
    if let pdfView = view as? CustomPDFView {
        return pdfView
    }
    for subview in view.subviews {
        if let found = findPDFView(in: subview) {
            return found
        }
    }
    return nil
}

// Restore previously open PDF documents (posts notifications handled by ContentView)
func restoreOpenDocuments() {
    guard let paths = UserDefaults.standard.stringArray(forKey: "OpenPDFPaths"), !paths.isEmpty else { return }
    for path in paths {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            NotificationCenter.default.post(name: Notification.Name("OpenPDFAsTab"), object: url)
        }
    }
}

@main
struct SimplePDFApp: App {
    @State private var initialURL: URL? = nil
    
    init() {
        let currentApp = NSRunningApplication.current
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.jonas.SimplePDF")
            .filter { $0 != currentApp }
        
        if !runningApps.isEmpty {
            // Activate the existing running instance
            runningApps.first?.activate(options: [])
            
            // Forward command line PDF arguments to the running instance
            if CommandLine.arguments.count > 1 {
                let possiblePath = CommandLine.arguments[1]
                if !possiblePath.hasPrefix("-") {
                    let url = URL(fileURLWithPath: possiblePath)
                    NSWorkspace.shared.open([url], withApplicationAt: runningApps.first!.bundleURL!, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                        exit(0)
                    }
                } else {
                    exit(0)
                }
            } else {
                exit(0)
            }
        }
        
        // Parse initial URL from argument if available
        if CommandLine.arguments.count > 1 {
            let possiblePath = CommandLine.arguments[1]
            if !possiblePath.hasPrefix("-") {
                let url = URL(fileURLWithPath: possiblePath)
                if FileManager.default.fileExists(atPath: url.path) {
                    self._initialURL = State(initialValue: url)
                }
            }
        }
    }
    
    var body: some Scene {
        // Main window (shows landing page by default, or initial URL)
        WindowGroup {
            ContentView(fileURL: initialURL)
                .frame(minWidth: 800, minHeight: 600)
        }
        
        // Window group for opening subsequent files as tabs
        WindowGroup(for: URL.self) { $url in
            ContentView(fileURL: url)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            SidebarCommands()
            FileOpenCommands()
            SearchCommands()
            CloseCommands()
        }
    }
}

// Map the native macOS tab bar plus (+) button action to a custom file picker
extension NSWindow {
    @objc open override func newWindowForTab(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType.pdf]
        
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: Notification.Name("OpenPDFAsTab"), object: url)
        }
    }
}
