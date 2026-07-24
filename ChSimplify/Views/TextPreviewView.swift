//
//  TextPreviewView.swift
//  ChSimplify
//
//  全屏图片预览页：以图为底图标出每行文字，支持双指缩放 + 拖动，点击绿框选中，
//  右下角「查看文字」展示选中内容（未选中时取全文）的简体 / 繁体。
//

import SwiftUI
import UIKit

/// 进入预览页所需的数据。`lines` 为空时预览页会自行对图片重新 OCR（用于历史记录 / 拍照后立即进入）。
struct PreviewPayload: Identifiable {
    let id = UUID()
    let image: UIImage
    var lines: [RecognizedLine]?
}

struct TextPreviewView: View {
    let image: UIImage
    var preRecognizedLines: [RecognizedLine]?
    /// 预览页内部完成 OCR 后回调（拍照流程用于存历史 / 更新缓存）。
    var onRecognized: (([RecognizedLine]) -> Void)?
    /// 「拍下一张」回调（仅拍照流程提供）。
    var onCaptureNext: (() -> Void)?
    /// 「选下一张」回调（仅拍照流程提供）。
    var onPickNext: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [RecognizedLine] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var isRecognizing = false
    @State private var errorMessage: String?
    @State private var showText = false
    @State private var showBoxes = true
    @State private var toastMessage: String?

    // 缩放 / 拖动
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maxScale: CGFloat = 6

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 控件放在独立的顶部 / 底部栏，避免与图片上的绿框点击区重叠。
            VStack(spacing: 0) {
                topBar

                ZStack {
                    ImageTextOverlayView(image: image, lines: lines, selectedIDs: $selectedIDs, showBoxes: showBoxes)
                        .padding(.horizontal, 4)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(dragGesture.simultaneously(with: magnifyGesture))

                    if isRecognizing {
                        ProgressView("识别中…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(20)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.7), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                bottomBar
            }
        }
        .sheet(isPresented: $showText) {
            SelectedTextSheet(original: textToView)
                .presentationDetents([.medium, .large])
        }
        .toast($toastMessage)
        .task { await loadIfNeeded() }
    }

    /// 「查看文字」的内容：有选中取选中行，未选中则取全文。
    private var textToView: String {
        let chosen = selectedIDs.isEmpty
            ? lines
            : lines.filter { selectedIDs.contains($0.id) }
        return chosen.map(\.text).joined(separator: "\n")
    }

    // MARK: - 手势

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1; lastScale = 1
            offset = .zero; lastOffset = .zero
        }
    }

    // MARK: - 顶部 / 底部栏

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.18), in: Circle())
            }

            Spacer()

            // 保存当前（截取后的原始）图片到相册。
            Button {
                ImageSaver.save(image) { toastMessage = $0 }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.18), in: Circle())
            }

            if let onCaptureNext {
                Button {
                    onCaptureNext()
                } label: {
                    Image(systemName: "camera")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.18), in: Circle())
                }
            }

            if let onPickNext {
                Button {
                    onPickNext()
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.18), in: Circle())
                }
            }

            if scale > 1.01 {
                Button {
                    resetZoom()
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.18), in: Circle())
                }
            }

            if !lines.isEmpty {
                Text("已选 \(selectedIDs.count)/\(lines.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showBoxes.toggle()
            } label: {
                Image(systemName: showBoxes ? "eye.slash" : "eye")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel(showBoxes ? "隐藏绿框" : "显示绿框")
            .disabled(lines.isEmpty)
            .opacity(lines.isEmpty ? 0.5 : 1)

            Spacer()

            // 有选中时复制选中行，未选中时复制全文的简体结果。
            Button {
                let simplified = ChineseConverter.toSimplified(textToView)
                    .replacingOccurrences(of: "\n", with: "")
                UIPasteboard.general.string = simplified
                toastMessage = "已复制简体结果"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .disabled(lines.isEmpty)
            .opacity(lines.isEmpty ? 0.5 : 1)

            Spacer()

            Button {
                showText = true
            } label: {
                Image(systemName: "text.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.green, in: Circle())
            }
            .accessibilityLabel("查看文字")
            .disabled(lines.isEmpty)
            .opacity(lines.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadIfNeeded() async {
        if let preRecognizedLines {
            lines = preRecognizedLines
            return                      // 默认不选中任何文字
        }
        guard lines.isEmpty else { return }
        isRecognizing = true
        defer { isRecognizing = false }
        do {
            let recognized = try await TextRecognizer.recognize(image)
            lines = recognized          // 默认不选中任何文字
            onRecognized?(recognized)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 「查看文字」弹窗：展示选中内容的简体与繁体，各自可复制。
private struct SelectedTextSheet: View {
    let original: String
    @Environment(\.dismiss) private var dismiss
    @State private var noWrap = true        // 默认不换行

    private var simplified: String { ChineseConverter.toSimplified(original) }
    private var traditional: String { ChineseConverter.toTraditional(original) }

    /// 按「不换行」开关处理换行：开启时去掉所有换行拼成连续文本。
    private func display(_ text: String) -> String {
        noWrap ? text.replacingOccurrences(of: "\n", with: "") : text
    }

    var body: some View {
        NavigationStack {
            Group {
                if original.isEmpty {
                    EmptyStateView(title: "未识别到文字",
                                   systemImage: "character.cursor.ibeam",
                                   description: "图片中没有可显示的文字")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            section(title: "简体", text: simplified)
                            // 繁体与简体一致（无繁简差异）时，只显示简体。
                            if traditional != simplified {
                                Divider()
                                section(title: "繁体", text: traditional)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("文字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func section(title: String, text rawText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button {
                    noWrap.toggle()
                } label: {
                    Label("不换行", systemImage: noWrap ? "checkmark.square.fill" : "square")
                        .font(.subheadline)
                }
                Button {
                    UIPasteboard.general.string = display(rawText)
                } label: {
                    Label("复制", systemImage: "doc.on.doc").font(.subheadline)
                }
            }
            // 「不换行」去掉 \n，但仍按屏幕宽度软换行显示。
            ReadOnlyTextEditor(text: display(rawText))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
