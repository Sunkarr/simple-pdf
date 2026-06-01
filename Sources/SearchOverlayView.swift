import SwiftUI
import PDFKit

struct SearchOverlayView: View {
    let pdfView: CustomPDFView
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var selections: [PDFSelection] = []
    @State private var currentIndex = -1
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Search Icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            // Search Input Field
            TextField("Find in document...", text: $searchText)
                .textFieldStyle(.plain)
                .frame(width: 180)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    navigateNext()
                }
            
            // Status/Results Count
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !searchText.isEmpty {
                Text(selections.isEmpty ? "0 of 0" : "\(currentIndex + 1) of \(selections.count)")
                    .font(.caption)
                    .foregroundColor(selections.isEmpty ? .red : .secondary)
            }
            
            Divider().frame(height: 16)
            
            // Navigation Controls
            Group {
                Button(action: navigatePrevious) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(selections.isEmpty)
                .help("Previous Match (Shift + Enter)")
                
                Button(action: navigateNext) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(selections.isEmpty)
                .help("Next Match (Enter)")
            }
            
            Divider().frame(height: 16)
            
            // Close Button
            Button(action: closeSearch) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Search (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).cornerRadius(8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
        .onExitCommand {
            closeSearch()
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(for: newValue)
        }
        .onAppear {
            // Focus search field if possible, or reset
            resetSearch()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
    
    private func performSearch(for query: String) {
        guard let doc = pdfView.document, !query.isEmpty else {
            selections = []
            currentIndex = -1
            pdfView.highlightedSelections = nil
            pdfView.currentSelection = nil
            return
        }
        
        isSearching = true
        
        // Perform search synchronously on the main thread for thread safety with PDFKit rendering
        let foundSelections = doc.findString(query, withOptions: .caseInsensitive)
        self.selections = foundSelections
        self.isSearching = false
        
        if !foundSelections.isEmpty {
            self.currentIndex = 0
            self.highlightCurrentMatch()
        } else {
            self.currentIndex = -1
            self.pdfView.highlightedSelections = nil
            self.pdfView.currentSelection = nil
        }
    }
    
    private func highlightCurrentMatch() {
        guard !selections.isEmpty && currentIndex >= 0 && currentIndex < selections.count else { return }
        let current = selections[currentIndex]
        
        // Highlight all matches in yellow
        pdfView.highlightedSelections = selections
        
        // Active selection focused
        pdfView.currentSelection = current
        pdfView.go(to: current)
    }
    
    private func navigateNext() {
        guard !selections.isEmpty else { return }
        currentIndex = (currentIndex + 1) % selections.count
        highlightCurrentMatch()
    }
    
    private func navigatePrevious() {
        guard !selections.isEmpty else { return }
        currentIndex = (currentIndex - 1 + selections.count) % selections.count
        highlightCurrentMatch()
    }
    
    private func resetSearch() {
        searchText = ""
        selections = []
        currentIndex = -1
        pdfView.highlightedSelections = nil
        pdfView.currentSelection = nil
    }
    
    private func closeSearch() {
        resetSearch()
        isPresented = false
    }
}

// SwiftUI Visual Effect wrapper for native macOS glassmorphism
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
