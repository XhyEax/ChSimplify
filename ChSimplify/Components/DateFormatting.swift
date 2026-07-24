//
//  DateFormatting.swift
//  ChSimplify
//
//  统一的中文日期时间样式。
//

import Foundation

extension Date {
    /// 中文样式的日期时间，如「2026年6月15日 14:30」。
    var chineseDateTime: String {
        formatted(.dateTime
            .year().month().day().hour().minute()
            .locale(Locale(identifier: "zh_Hans")))
    }
}
