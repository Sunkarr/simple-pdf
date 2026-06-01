import SwiftUI
import PDFKit
import Combine

// Proxy delegate that intercepts middle-click close on the last tab
// and redirects to landing page instead of closing the window.
class WindowCloseProxy: NSObject, NSWindowDelegate {
    weak var originalDelegate: NSWindowDelegate?
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let tabCount = sender.tabGroup?.windows.count ?? 1
        if tabCount <= 1 {
            // Last tab — post notification to return to landing page
            NotificationCenter.default.post(name: Notification.Name("ReturnToLandingPage"), object: sender)
            return false
        }
        return originalDelegate?.windowShouldClose?(sender) ?? true
    }
    
    // Forward all other delegate methods to the original SwiftUI delegate
    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(NSWindowDelegate.windowShouldClose(_:)) {
            return true
        }
        return originalDelegate?.responds(to: aSelector) ?? super.responds(to: aSelector)
    }
    
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if aSelector == #selector(NSWindowDelegate.windowShouldClose(_:)) {
            return nil // Handle ourselves
        }
        return originalDelegate
    }
}

class CustomPDFView: PDFView {
    private var scrollMonitor: Any?
    private var closeProxy: WindowCloseProxy?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = self.window {
            // Install the close proxy to intercept last-tab close
            if closeProxy == nil {
                let proxy = WindowCloseProxy()
                proxy.originalDelegate = window.delegate
                window.delegate = proxy
                closeProxy = proxy
            }
            // Force window tabbing mode to preferred so new documents open as tabs
            window.tabbingMode = .preferred
            
            // Merge this window into any existing window's tab group to ensure tabs are used
            if !TabBarButtonTarget.isSorting {
                let otherWindows = NSApplication.shared.windows.filter {
                    $0 != window &&
                    $0.isVisible &&
                    !$0.className.contains("NSColorPanel") &&
                    !$0.className.contains("NSFontPanel") &&
                    $0.canBecomeKey
                }
                if let hostWindow = otherWindows.first {
                    let lastTab = hostWindow.tabGroup?.windows.last ?? hostWindow
                    lastTab.makeKey()
                    lastTab.addTabbedWindow(window, ordered: .above)
                    // Select this new tab so it becomes active
                    window.makeKey()
                }
            }
            

            // Show the Apple tab bar by default if it is currently hidden
            if let tabGroup = window.tabGroup, !tabGroup.isTabBarVisible {
                window.toggleTabBar(nil)
            }
            
            // Save open documents state on new window creation
            DispatchQueue.main.async {
                saveOpenDocuments()
            }
            
            // Observe window closing to update the saved session state
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    saveOpenDocuments()
                    
                    // Ensure the remaining windows keep their tab bars visible (e.g. if only one tab is left)
                    for w in NSApplication.shared.windows {
                        if w.isVisible && w.canBecomeKey && !w.className.contains("Panel") {
                            if let tabGroup = w.tabGroup, !tabGroup.isTabBarVisible {
                                w.toggleTabBar(nil)
                            }
                        }
                    }
                }
            }
            
            if scrollMonitor == nil {
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    guard let self = self, self.window == event.window else { return event }
                    
                    if event.modifierFlags.contains(.command) {
                        let mouseLoc = event.locationInWindow
                        let localPoint = self.convert(mouseLoc, from: nil)
                        if self.bounds.contains(localPoint) {
                            self.handleScrollZoom(with: event)
                            return nil // Consume event
                        }
                    }
                    return event
                }
            }
        } else {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
        }
    }
    
    private func handleScrollZoom(with event: NSEvent) {
        let dy = event.scrollingDeltaY
        if dy != 0 {
            self.autoScales = false
            let factor = 1.0 + (dy > 0 ? 0.05 : -0.05)
            self.scaleFactor = min(max(self.scaleFactor * CGFloat(factor), 0.1), 5.0)
        }
    }
    
    deinit {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct PDFViewRepresentable: NSViewRepresentable {
    let document: PDFDocument?
    let pdfView: CustomPDFView
    
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var scaleFactor: Double
    @Binding var autoScales: Bool
    @Binding var displayMode: PDFDisplayMode
    
    func makeNSView(context: Context) -> CustomPDFView {
        pdfView.document = document
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        pdfView.displaysPageBreaks = true
        
        context.coordinator.updateCurrentPage()
        context.coordinator.updateScaleFactor()
        
        return pdfView
    }
    
    func updateNSView(_ nsView: CustomPDFView, context: Context) {
        // Update Document
        if nsView.document != document {
            nsView.document = document
        }
        
        // Sync totalPages if it differs
        if let doc = document {
            if totalPages != doc.pageCount {
                DispatchQueue.main.async {
                    self.totalPages = doc.pageCount
                }
            }
        }
        
        // Update Auto Scales first (order matters to resolve scale sync races)
        if nsView.autoScales != autoScales {
            nsView.autoScales = autoScales
            if autoScales {
                // If autoScales is turned on, sync the scale factor back to state
                DispatchQueue.main.async {
                    self.scaleFactor = Double(nsView.scaleFactor)
                }
            }
        }
        
        // Then Update Scale
        if !autoScales && abs(Double(nsView.scaleFactor) - scaleFactor) > 0.01 {
            nsView.scaleFactor = CGFloat(scaleFactor)
        }
        
        // Update Display Mode
        if nsView.displayMode != displayMode {
            nsView.displayMode = displayMode
        }
        
        // Jump to page if programmatically changed
        if let doc = nsView.document,
           currentPage >= 1 && currentPage <= doc.pageCount {
            if let currentPageObj = nsView.currentPage {
                let currentIndex = doc.index(for: currentPageObj) + 1
                if currentIndex != currentPage {
                    if let targetPage = doc.page(at: currentPage - 1) {
                        nsView.go(to: targetPage)
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFViewRepresentable
        private var cancellables = Set<AnyCancellable>()
        
        init(_ parent: PDFViewRepresentable) {
            self.parent = parent
            super.init()
            
            // Observe page changes
            NotificationCenter.default.publisher(for: .PDFViewPageChanged)
                .sink { [weak self] notification in
                    guard let self = self,
                          let notificationView = notification.object as? CustomPDFView,
                          notificationView == self.parent.pdfView else { return }
                    self.updateCurrentPage()
                }
                .store(in: &cancellables)
            
            // Observe scale changes
            NotificationCenter.default.publisher(for: .PDFViewScaleChanged)
                .sink { [weak self] notification in
                    guard let self = self,
                          let notificationView = notification.object as? CustomPDFView,
                          notificationView == self.parent.pdfView else { return }
                    self.updateScaleFactor()
                }
                .store(in: &cancellables)
        }
        
        func updateCurrentPage() {
            guard let document = parent.pdfView.document,
                  let currentPageObj = parent.pdfView.currentPage else { return }
            let index = document.index(for: currentPageObj) + 1
            if parent.currentPage != index {
                DispatchQueue.main.async {
                    self.parent.currentPage = index
                }
            }
        }
        
        func updateScaleFactor() {
            let scale = Double(parent.pdfView.scaleFactor)
            if abs(parent.scaleFactor - scale) > 0.01 {
                DispatchQueue.main.async {
                    self.parent.scaleFactor = scale
                    if !self.parent.pdfView.autoScales && self.parent.autoScales {
                        self.parent.autoScales = false
                    }
                }
            }
        }
    }
}

struct PDFThumbnailViewRepresentable: NSViewRepresentable {
    let pdfView: PDFView
    @Binding var selectionCount: Int
    
    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbnailView = PDFThumbnailView()
        thumbnailView.pdfView = pdfView
        thumbnailView.thumbnailSize = NSSize(width: 80, height: 110)
        return thumbnailView
    }
    
    func updateNSView(_ nsView: PDFThumbnailView, context: Context) {
        nsView.pdfView = pdfView
    }
}
