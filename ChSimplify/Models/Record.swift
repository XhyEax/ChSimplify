//
//  Record.swift
//  ChSimplify
//
//  历史记录数据模型：保存一次识别 + 繁→简转换的结果。
//

import Foundation

struct HistoryRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    /// OCR 识别出的原文（可能包含繁体字）
    let originalText: String
    /// 转换后的简体结果
    let convertedText: String
    /// 编辑后的原图数据
    let imageData: Data?

    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         originalText: String,
         convertedText: String,
         imageData: Data? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.convertedText = convertedText
        self.imageData = imageData
    }

    /// 归档中的稳定唯一 ID：记录创建时间（Unix 微秒）。
    var creationID: String {
        String(Int64((timestamp.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}
