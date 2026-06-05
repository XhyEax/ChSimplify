//
//  CaptureView.swift
//  ChSimplify
//
//  「拍照」Tab：取图 → 立即进入全屏预览页（在页内 OCR + 选字）；存入历史并缓存上次识别。
//

import SwiftUI
import SwiftData
import UIKit

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var preview: PreviewPayload?
    @State private var pendingImage: UIImage?

    // 上次识别缓存
    @State private var lastImage: UIImage?
    @State private var lastLines: [RecognizedLine] = []

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var lastOriginal: String {
        lastLines.map(\.text).joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sourceButtons

                    if let lastImage {
                        lastResultCard(lastImage)
                    } else {
                        ContentUnavailableView("拍照或选图识别繁体字",
                                               systemImage: "camera.viewfinder",
                                               description: Text("识别图片中的文字，并自动转换为简体"))
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("拍照")
            .fullScreenCover(isPresented: $showCamera, onDismiss: presentPending) {
                CameraView { handlePicked($0) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary, onDismiss: presentPending) {
                ImagePicker(sourceType: .photoLibrary) { handlePicked($0) }
                    .ignoresSafeArea()
            }
            .fullScreenCover(item: $preview) { payload in
                TextPreviewView(image: payload.image,
                                preRecognizedLines: payload.lines,
                                onRecognized: { lines in saveAndCache(payload.image, lines) })
            }
        }
    }

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("拍照", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!cameraAvailable)

            Button {
                showLibrary = true
            } label: {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    /// 上次识别缓存卡片：点击原图进预览页；简体 / 繁体文字可长按选中。
    private func lastResultCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("上次识别")
                .font(.subheadline).foregroundStyle(.secondary)

            // 仅图片可点击进入预览页（文字保留长按选中能力）。
            Button {
                preview = PreviewPayload(image: image, lines: lastLines)
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("简体").font(.caption).foregroundStyle(.secondary)
                Text(ChineseConverter.toSimplified(lastOriginal))
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("繁体").font(.caption).foregroundStyle(.secondary)
                Text(ChineseConverter.toTraditional(lastOriginal))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    /// 选好图后记录待处理图片；等取图界面关闭再进入预览页，避免界面切换冲突。
    private func handlePicked(_ picked: UIImage) {
        pendingImage = picked
    }

    private func presentPending() {
        guard let pendingImage else { return }
        self.pendingImage = nil
        preview = PreviewPayload(image: pendingImage)
    }

    /// 预览页 OCR 完成后回调：存入历史并更新「上次识别」缓存。
    private func saveAndCache(_ image: UIImage, _ lines: [RecognizedLine]) {
        let fullOriginal = lines.map(\.text).joined(separator: "\n")
        let fullSimplified = ChineseConverter.toSimplified(fullOriginal)
        let data = image.jpegData(compressionQuality: 0.8)
        modelContext.insert(Record(originalText: fullOriginal,
                                   convertedText: fullSimplified,
                                   imageData: data))
        lastImage = image
        lastLines = lines
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: Record.self, inMemory: true)
}
