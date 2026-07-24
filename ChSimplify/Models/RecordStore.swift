//
//  RecordStore.swift
//  ChSimplify
//
//  iOS 16 compatible local persistence for recognition history.
//

import Foundation
import Combine

@MainActor
final class RecordStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []

    private let storageURL: URL?
    private let migrationKey = "legacySwiftDataMigrationCompleted"

    init(inMemory: Bool = false) {
        if inMemory {
            storageURL = nil
        } else {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("ChSimplify", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            storageURL = directory.appendingPathComponent("records.json")
        }
        load()
        migrateLegacyStoreIfNeeded()
    }

    func add(_ record: HistoryRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(_ record: HistoryRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            records.remove(at: index)
        }
        save()
    }

    @discardableResult
    func importRecords(_ imported: [HistoryRecord]) -> Int {
        var existingIDs = Set(records.map(\.creationID))
        let newRecords = imported.filter { record in
            existingIDs.insert(record.creationID).inserted
        }
        guard !newRecords.isEmpty else { return 0 }
        records.append(contentsOf: newRecords)
        records.sort { $0.timestamp > $1.timestamp }
        save()
        return newRecords.count
    }

    private func load() {
        guard let storageURL,
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([HistoryRecord].self, from: data)
        else { return }
        records = decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private func save() {
        guard let storageURL,
              let data = try? JSONEncoder().encode(records)
        else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func migrateLegacyStoreIfNeeded() {
        guard storageURL != nil,
              !UserDefaults.standard.bool(forKey: migrationKey),
              #available(iOS 17.0, *)
        else { return }

        do {
            guard let migrated = try LegacySwiftDataMigrator.loadRecords() else {
                return
            }
            let existingKeys = Set(records.map(\.migrationKey))
            let newRecords = migrated.filter { !existingKeys.contains($0.migrationKey) }
            if !newRecords.isEmpty {
                records.append(contentsOf: newRecords)
                records.sort { $0.timestamp > $1.timestamp }
                save()
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            // Keep the flag unset so migration retries on the next launch.
            print("Legacy history migration failed: \(error)")
        }
    }
}

private extension HistoryRecord {
    var migrationKey: String {
        "\(timestamp.timeIntervalSinceReferenceDate)|\(originalText)|\(convertedText)"
    }
}
