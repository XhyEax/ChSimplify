//
//  RecordDetailView.swift
//  ChSimplify
//
//  历史记录详情：大图（可进预览页 / 保存至相册）+ 简体结果 + 识别原文 + 复制。
//

import SwiftUI
import UIKit
import Photos

struct RecordDetailView: View {
    let record: Record
    @State private var didCopy = false
    @State private var preview: PreviewPayload?
    @State private var saveAlert: SaveAlert?

    private var uiImage: UIImage? {
        record.imageData.flatMap { UIImage(data: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let uiImage {
                    // 点击大图进入全屏预览页（绿框选字 + 查看简繁体）。
                    Button {
                        preview = PreviewPayload(image: uiImage)
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveToAlbum(uiImage)
                    } label: {
                        Label("保存至相册", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("简体结果")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = record.convertedText
                            didCopy = true
                        } label: {
                            Label(didCopy ? "已复制" : "复制", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.subheadline)
                        }
                    }
                    Text(record.convertedText)
                        .textSelection(.enabled)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("识别原文")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(record.originalText)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle(record.timestamp.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $preview) { payload in
            TextPreviewView(image: payload.image, preRecognizedLines: payload.lines)
        }
        .alert(item: $saveAlert) { alert in
            Alert(title: Text(alert.message))
        }
    }

    private func saveToAlbum(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveAlert = SaveAlert(message: "没有相册权限，请在设置中允许")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    saveAlert = SaveAlert(message: success
                                          ? "已保存到相册"
                                          : "保存失败：\(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
}

struct SaveAlert: Identifiable {
    let id = UUID()
    let message: String
}
