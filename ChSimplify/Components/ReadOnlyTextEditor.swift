//
//  ReadOnlyTextEditor.swift
//  ChSimplify
//
//  只读、可选中的文本视图（包装 UITextView），整个 App 复用，
//  以获得可靠的长按选中 / 部分选择体验。用法：ReadOnlyTextEditor(text: x)
//

import SwiftUI
import UIKit

struct ReadOnlyTextEditor: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false                       // 随内容自适应高度
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0         // 与 Text 左对齐
        tv.font = .preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        // 垂直方向撑开高度，水平方向接受容器宽度（否则会被撑成单行不换行）。
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        tv.text = text
    }

    /// 按 SwiftUI 提议的宽度强制换行并返回多行高度，避免被撑成横向长条。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0, width != .infinity else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }
}
