//
//  ContentView.swift
//  QuickScan
//
//  Created by AI Agent on 2026-03-29.
//

import PDFKit
import SwiftUI
import UIKit
import VisionKit

struct ContentView: View {
    @StateObject private var store = DocumentStore()
    @State private var isScannerPresented = false
    @State private var selectedDocument: ScannedDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("QuickScan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentScanner()
                    } label: {
                        Label("Scan", systemImage: "doc.viewfinder")
                    }
                }
            }
        }
        .sheet(isPresented: $isScannerPresented) {
            DocumentScannerView { result in
                switch result {
                case .success(let scan):
                    do {
                        try store.add(scan: scan)
                    } catch {
                        errorMessage = "Unable to save this scan. \(error.localizedDescription)"
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document, store: store) { message in
                errorMessage = message
            }
        }
        .alert("QuickScan", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 68))
                .foregroundStyle(.tint)

            Text("Scan paper documents")
                .font(.title2.weight(.semibold))

            Text("Capture receipts, letters, and notes into a clean PDF you can export immediately.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Start Scan") {
                presentScanner()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var documentList: some View {
        List {
            Section {
                ForEach(store.documents) { document in
                    Button {
                        selectedDocument = document
                    } label: {
                        DocumentRow(document: document)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            do {
                                try store.delete(document)
                            } catch {
                                errorMessage = "Unable to delete this scan. \(error.localizedDescription)"
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("All scans stay on this device unless you choose to export them.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    errorMessage = nil
                }
            }
        )
    }

    private func presentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            errorMessage = "Document scanning is not supported on this device."
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "The camera is currently unavailable. Check Screen Time or camera restrictions and try again."
            return
        }

        isScannerPresented = true
    }
}

private struct DocumentRow: View {
    let document: ScannedDocument

    var body: some View {
        HStack(spacing: 14) {
            DocumentThumbnail(imageURL: document.pageURLs.first)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(document.pages.count) page\(document.pages.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct DocumentThumbnail: View {
    let imageURL: URL?

    var body: some View {
        Group {
            if let imageURL, let uiImage = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                    Image(systemName: "doc")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 64, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        }
    }
}

private struct DocumentDetailView: View {
    let document: ScannedDocument
    @ObservedObject var store: DocumentStore
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if document.pageURLs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No pages found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    TabView {
                        ForEach(Array(document.pageURLs.enumerated()), id: \.offset) { index, pageURL in
                            ZoomablePageView(pageURL: pageURL)
                                .padding()
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button(role: .destructive) {
                        do {
                            try store.delete(document)
                            dismiss()
                        } catch {
                            onError("Unable to delete this scan. \(error.localizedDescription)")
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .task {
            do {
                exportURL = try store.exportPDF(for: document)
            } catch {
                onError("Unable to prepare PDF export. \(error.localizedDescription)")
            }
        }
    }
}

private struct ZoomablePageView: View {
    let pageURL: URL

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let uiImage = UIImage(contentsOfFile: pageURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Page unavailable")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [ScannedDocument] = []

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    func add(scan: VNDocumentCameraScan) throws {
        let documentID = UUID()
        let createdAt = Date()
        let title = "Scan \(documents.count + 1)"

        try ensureDirectories()

        var pages: [ScannedPage] = []
        for index in 0 ..< scan.pageCount {
            let image = scan.imageOfPage(at: index)
            let fileName = "\(documentID.uuidString)-\(index + 1).jpg"
            let fileURL = try pagesDirectoryURL().appendingPathComponent(fileName)

            guard let imageData = image.jpegData(compressionQuality: 0.88) else {
                throw DocumentStoreError.imageEncodingFailed
            }

            try imageData.write(to: fileURL, options: .atomic)
            pages.append(ScannedPage(fileName: fileName))
        }

        let document = ScannedDocument(
            id: documentID,
            title: title,
            createdAt: createdAt,
            pages: pages
        )

        documents.insert(document, at: 0)
        try persist()
    }

    func delete(_ document: ScannedDocument) throws {
        for page in document.pages {
            let pageURL = try pagesDirectoryURL().appendingPathComponent(page.fileName)
            if fileManager.fileExists(atPath: pageURL.path) {
                try fileManager.removeItem(at: pageURL)
            }
        }

        documents.removeAll { $0.id == document.id }
        try persist()
    }

    func exportPDF(for document: ScannedDocument) throws -> URL {
        try ensureDirectories()
        let exportURL = try exportsDirectoryURL().appendingPathComponent("\(document.id.uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))

        try renderer.writePDF(to: exportURL) { context in
            for pageURL in document.pageURLs {
                guard let image = UIImage(contentsOfFile: pageURL.path) else { continue }
                let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
                let drawRect = aspectFitRect(for: image.size, in: pageBounds.insetBy(dx: 24, dy: 24))

                context.beginPage()
                UIColor.white.setFill()
                context.cgContext.fill(pageBounds)
                image.draw(in: drawRect)
            }
        }

        return exportURL
    }

    private func load() {
        do {
            let data = try Data(contentsOf: metadataURL())
            documents = try decoder.decode([ScannedDocument].self, from: data)
        } catch {
            documents = []
        }
    }

    private func persist() throws {
        let data = try encoder.encode(documents)
        try ensureDirectories()
        try data.write(to: metadataURL(), options: .atomic)
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: baseDirectoryURL(), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: pagesDirectoryURL(), withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: exportsDirectoryURL(), withIntermediateDirectories: true, attributes: nil)
    }

    private func baseDirectoryURL() throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DocumentStoreError.storageUnavailable
        }

        return baseURL.appendingPathComponent("QuickScan", isDirectory: true)
    }

    private func pagesDirectoryURL() throws -> URL {
        try baseDirectoryURL().appendingPathComponent("Pages", isDirectory: true)
    }

    private func exportsDirectoryURL() throws -> URL {
        try baseDirectoryURL().appendingPathComponent("Exports", isDirectory: true)
    }

    private func metadataURL() throws -> URL {
        try baseDirectoryURL().appendingPathComponent("documents.json")
    }

    private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: bounds.midX - scaledSize.width / 2,
            y: bounds.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}

private struct ScannedDocument: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let pages: [ScannedPage]

    var pageURLs: [URL] {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("QuickScan", isDirectory: true)
            .appendingPathComponent("Pages", isDirectory: true)

        return pages.compactMap { page in
            baseURL?.appendingPathComponent(page.fileName)
        }
    }
}

private struct ScannedPage: Codable {
    let fileName: String
}

private enum DocumentStoreError: LocalizedError {
    case storageUnavailable
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "Local storage is unavailable."
        case .imageEncodingFailed:
            return "A scanned page could not be converted into an image file."
        }
    }
}

private struct DocumentScannerView: UIViewControllerRepresentable {
    let onFinish: (Result<VNDocumentCameraScan, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: (Result<VNDocumentCameraScan, Error>) -> Void

        init(onFinish: @escaping (Result<VNDocumentCameraScan, Error>) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish(.success(scan))
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(.failure(error))
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}
