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
    @Published private(set) var records: [Record] = []

    private let storageURL: URL?

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
    }

    func add(_ record: Record) {
        records.insert(record, at: 0)
        save()
    }

    func delete(_ record: Record) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            records.remove(at: index)
        }
        save()
    }

    private func load() {
        guard let storageURL,
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Record].self, from: data)
        else { return }
        records = decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private func save() {
        guard let storageURL,
              let data = try? JSONEncoder().encode(records)
        else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
