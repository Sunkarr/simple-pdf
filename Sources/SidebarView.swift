import SwiftUI
import PDFKit
import AppKit

struct OutlineItem: Identifiable {
    let id = UUID()
    let label: String
    let destination: PDFDestination?
    let children: [OutlineItem]?
}

struct SidebarView: View {
    let document: PDFDocument?
    let pdfView: CustomPDFView
    @Binding var currentPage: Int
    let sidebarWidth: CGFloat
    
    @State private var selectedTab = 0 // 0 = Pages, 1 = Outline
    @State private var outlineSearchQuery = ""
    @State private var outlineItems: [OutlineItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Label("Pages", systemImage: "square.grid.2x2").tag(0)
                Label("Outline", systemImage: "list.bullet").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(10)
            
            Divider()
            
            // Tab Content
            Group {
                if selectedTab == 0 {
                    // Pages Tab (Custom SwiftUI Thumbnail Grid)
                    if let doc = document {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(0..<doc.pageCount, id: \.self) { index in
                                    if let page = doc.page(at: index) {
                                        let bounds = page.bounds(for: .mediaBox)
                                        let pageW = bounds.width > 0 ? bounds.width : 1.0
                                        let pageH = bounds.height > 0 ? bounds.height : 1.0
                                        let aspectRatio = pageW / pageH
                                        
                                        // Target a width proportional to the sidebar width, minus margins, bounded reasonably
                                        let thumbnailWidth = max(60, min(300, sidebarWidth - 40))
                                        let thumbnailHeight = thumbnailWidth / aspectRatio
                                        
                                        VStack(spacing: 6) {
                                            PageThumbnailView(page: page, width: thumbnailWidth, height: thumbnailHeight)
                                                .id(page)
                                                .background(Color.white)
                                                .cornerRadius(4)
                                                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(currentPage == index + 1 ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: currentPage == index + 1 ? 2.5 : 1)
                                                )
                                            
                                            Text("\(index + 1)")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(currentPage == index + 1 ? .accentColor : .secondary)
                                                .fontWeight(currentPage == index + 1 ? .bold : .regular)
                                        }
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            currentPage = index + 1
                                            if let targetPage = doc.page(at: index) {
                                                pdfView.go(to: targetPage)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                    } else {
                        placeholderView(message: "No Document Loaded")
                    }
                } else {
                    // Outline (Table of Contents) Tab
                    VStack(spacing: 0) {
                        // Outline Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search Outline...", text: $outlineSearchQuery)
                                .textFieldStyle(.plain)
                            if !outlineSearchQuery.isEmpty {
                                Button(action: { outlineSearchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .padding([.horizontal, .top], 10)
                        .padding(.bottom, 6)
                        
                        Divider()
                        
                        if outlineItems.isEmpty {
                            placeholderView(message: "No Table of Contents")
                        } else {
                            let filtered = filterOutline(outlineItems, query: outlineSearchQuery)
                            if filtered.isEmpty {
                                placeholderView(message: "No Matches Found")
                            } else {
                                List {
                                    OutlineGroup(filtered, children: \.children) { item in
                                        Button(action: {
                                            if let dest = item.destination {
                                                pdfView.go(to: dest)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "bookmark")
                                                    .foregroundColor(.accentColor)
                                                    .font(.caption)
                                                Text(item.label)
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .help(item.label)
                                    }
                                }
                                .listStyle(.sidebar)
                            }
                        }
                    }
                }
            }
        }
        .padding(.trailing, 6)
        .onChange(of: document) { _, newDoc in
            loadOutline(from: newDoc)
        }
        .onAppear {
            loadOutline(from: document)
        }
    }
    
    private func placeholderView(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadOutline(from doc: PDFDocument?) {
        guard let doc = doc else {
            outlineItems = []
            return
        }
        outlineItems = buildOutline(from: doc.outlineRoot)
    }
    
    private func buildOutline(from outline: PDFOutline?) -> [OutlineItem] {
        guard let outline = outline else { return [] }
        var items: [OutlineItem] = []
        
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i) {
                let label = child.label ?? "Untitled Page"
                let destination = child.destination
                let children = buildOutline(from: child)
                items.append(OutlineItem(
                    label: label,
                    destination: destination,
                    children: children.isEmpty ? nil : children
                ))
            }
        }
        return items
    }
    
    private func filterOutline(_ items: [OutlineItem], query: String) -> [OutlineItem] {
        if query.isEmpty { return items }
        
        return items.compactMap { item in
            let filteredChildren = filterOutline(item.children ?? [], query: query)
            let matchesQuery = item.label.localizedCaseInsensitiveContains(query)
            
            if matchesQuery || !filteredChildren.isEmpty {
                return OutlineItem(
                    label: item.label,
                    destination: item.destination,
                    children: filteredChildren.isEmpty ? nil : filteredChildren
                )
            }
            return nil
        }
    }
}

/// Cache to store generated page thumbnails to avoid regenerations during scroll/selection updates
class ThumbnailCache {
    static let shared = NSCache<AnyObject, NSImage>()
}

struct PageThumbnailView: View {
    let page: PDFPage
    let width: CGFloat
    let height: CGFloat
    
    @State private var thumbnail: NSImage? = nil
    
    var body: some View {
        Group {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.white
            }
        }
        .frame(width: width, height: height)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let cached = ThumbnailCache.shared.object(forKey: page) {
            self.thumbnail = cached
            return
        }
        
        // Generate a fixed high-resolution thumbnail (240pt, 480px at 2x)
        // so it looks crisp at any sidebar width and doesn't need regeneration on drag.
        let bounds = page.bounds(for: .mediaBox)
        let pageW = bounds.width > 0 ? bounds.width : 1.0
        let pageH = bounds.height > 0 ? bounds.height : 1.0
        let aspectRatio = pageW / pageH
        
        let targetWidth: CGFloat = 240
        let targetHeight = targetWidth / aspectRatio
        let targetSize = NSSize(width: targetWidth * 2.0, height: targetHeight * 2.0)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let img = page.thumbnail(of: targetSize, for: .mediaBox)
            ThumbnailCache.shared.setObject(img, forKey: page)
            DispatchQueue.main.async {
                self.thumbnail = img
            }
        }
    }
}
