//
//  ContentView.swift
//  QuickScan
//
//  Created by AI Agent on 2026-03-29.
//

import SwiftUI
import VisionKit

struct ContentView: View {
    @State private var isScannerPresented = false
    @State private var scannedDocuments: [ScannedDocument] = []
    
    var body: some View {
        NavigationView {
            VStack {
                if scannedDocuments.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("扫描文档")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("点击下方按钮开始扫描")
                            .foregroundColor(.secondary)
                        
                        Button(action: { isScannerPresented = true }) {
                            Label("开始扫描", systemImage: "camera.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                } else {
                    List(scannedDocuments) { doc in
                        VStack(alignment: .leading) {
                            Text(doc.name)
                                .font(.headline)
                            Text(doc.date.formatted())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { isScannerPresented = true }) {
                        Label("继续扫描", systemImage: "camera.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("快速扫描")
            .sheet(isPresented: $isScannerPresented) {
                DocumentScannerView(scannedDocuments: $scannedDocuments)
            }
        }
    }
}

struct ScannedDocument: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let imagePath: String
}

struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var scannedDocuments: [ScannedDocument]
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // 保存扫描结果
            let doc = ScannedDocument(
                name: "扫描文档 \(parent.scannedDocuments.count + 1)",
                date: Date(),
                imagePath: "temp"
            )
            parent.scannedDocuments.append(doc)
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}
