//
//  LegacySwiftDataMigrator.swift
//  ChSimplify
//
//  One-time reader for the SwiftData store used by the iOS 17 version.
//

import Foundation

#if canImport(SwiftData)
import SwiftData

@available(iOS 17.0, *)
@Model
private final class Record {
    var timestamp: Date
    var originalText: String
    var convertedText: String
    @Attribute(.externalStorage) var imageData: Data?

    init(timestamp: Date,
         originalText: String,
         convertedText: String,
         imageData: Data?) {
        self.timestamp = timestamp
        self.originalText = originalText
        self.convertedText = convertedText
        self.imageData = imageData
    }
}

enum LegacySwiftDataMigrator {
    /// `nil` means no legacy store exists; an empty array means migration succeeded with no rows.
    @available(iOS 17.0, *)
    static func loadRecords() throws -> [HistoryRecord]? {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let storeURL = applicationSupport.appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return nil
        }

        let schema = Schema([Record.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: false
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Record>(
            sortBy: [SortDescriptor(\Record.timestamp, order: .reverse)]
        )

        return try context.fetch(descriptor).map {
            HistoryRecord(
                timestamp: $0.timestamp,
                originalText: $0.originalText,
                convertedText: $0.convertedText,
                imageData: $0.imageData
            )
        }
    }
}
#endif
