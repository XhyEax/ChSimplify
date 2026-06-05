//
//  ChineseConverter.swift
//  ChSimplify
//
//  繁体 → 简体转换，复用 Foundation 内置的 ICU transliterator。
//

import Foundation

enum ChineseConverter {
    /// 将文本中的繁体字转换为简体字。逐字映射，失败时原样返回。
    static func toSimplified(_ text: String) -> String {
        text.applyingTransform(StringTransform(rawValue: "Traditional-Simplified"),
                               reverse: false) ?? text
    }

    /// 将文本中的简体字转换为繁体字。逐字映射，失败时原样返回。
    static func toTraditional(_ text: String) -> String {
        text.applyingTransform(StringTransform(rawValue: "Simplified-Traditional"),
                               reverse: false) ?? text
    }
}
