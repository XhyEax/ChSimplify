//
//  Record.swift
//  ChSimplify
//
//  历史记录数据模型：保存一次识别 + 繁→简转换的结果。
//

import Foundation
import SwiftData

@Model
final class Record {
    var timestamp: Date
    /// OCR 识别出的原文（可能包含繁体字）
    var originalText: String
    /// 转换后的简体结果
    var convertedText: String
    /// 原图，使用外部存储以免撑大数据库
    @Attribute(.externalStorage) var imageData: Data?

    init(timestamp: Date = Date(),
         originalText: String,
         convertedText: String,
         imageData: Data? = nil) {
        self.timestamp = timestamp
        self.originalText = originalText
        self.convertedText = convertedText
        self.imageData = imageData
    }
}
