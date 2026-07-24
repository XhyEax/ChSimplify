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
    @EnvironmentObject private var recordStore: RecordStore
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
    @State private var preview: PreviewPayload?
    @State private var toastMessage: String?
    @State private var noWrap = true        // 默认不换行
    @State private var showDeleteConfirm = false

    private var uiImage: UIImage? {
        record.imageData.flatMap { UIImage(data: $0) }
    }

    /// 按「不换行」开关处理换行：开启时去掉所有换行拼成连续文本。
    private func display(_ text: String) -> String {
        noWrap ? text.replacingOccurrences(of: "\n", with: "") : text
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
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text("简体结果")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            noWrap.toggle()
                        } label: {
                            Label("不换行", systemImage: noWrap ? "checkmark.square.fill" : "square")
                                .font(.subheadline)
                        }
                        Button {
                            UIPasteboard.general.string = display(record.convertedText)
                            didCopy = true
                        } label: {
                            Label(didCopy ? "已复制" : "复制", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.subheadline)
                        }
                    }
                    // 「不换行」去掉 \n，但仍按屏幕宽度软换行显示。
                    ReadOnlyTextEditor(text: display(record.convertedText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 转换后与原文一致（原文无繁体）时，只显示简体结果。
                if record.convertedText != record.originalText {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("识别原文")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ReadOnlyTextEditor(text: display(record.originalText))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(record.timestamp.chineseDateTime)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
            if let uiImage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveToAlbum(uiImage)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: Image(uiImage: uiImage),
                              preview: SharePreview("识别图片", image: Image(uiImage: uiImage))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .fullScreenCover(item: $preview) { payload in
            TextPreviewView(image: payload.image, preRecognizedLines: payload.lines)
        }
        .toast($toastMessage)
        .confirmationDialog("确定删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                recordStore.delete(record)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func saveToAlbum(_ image: UIImage) {
        ImageSaver.save(image) { toastMessage = $0 }
    }
}
