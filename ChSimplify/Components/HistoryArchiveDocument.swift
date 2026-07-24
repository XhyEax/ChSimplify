//
//  HistoryArchiveDocument.swift
//  ChSimplify
//

import SwiftUI
import UniformTypeIdentifiers

struct HistoryArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    private let archiveData: Data

    init(records: [HistoryRecord]) throws {
        archiveData = try HistoryArchive.encode(records)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        archiveData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: archiveData)
    }
}

enum HistoryArchive {
    private struct Manifest: Codable {
        let version: Int
        let exportedAt: Date
        let records: [ArchivedRecord]
    }

    private struct ArchivedRecord: Codable {
        let id: String
        let timestamp: Date
        let originalText: String
        let convertedText: String
        let imagePath: String?
    }

    enum ArchiveError: LocalizedError {
        case missingManifest
        case unsupportedVersion
        case invalidRecord

        var errorDescription: String? {
            switch self {
            case .missingManifest: return "压缩包缺少历史记录清单"
            case .unsupportedVersion: return "压缩包版本不受支持"
            case .invalidRecord: return "压缩包包含无效记录"
            }
        }
    }

    static func encode(_ records: [HistoryRecord]) throws -> Data {
        var entries: [SimpleZipArchive.Entry] = []
        let archivedRecords = records.map { record in
            let imagePath = record.imageData == nil ? nil : "images/\(record.creationID).jpg"
            if let imageData = record.imageData, let imagePath {
                entries.append(.init(name: imagePath, data: imageData))
            }
            return ArchivedRecord(
                id: record.creationID,
                timestamp: record.timestamp,
                originalText: record.originalText,
                convertedText: record.convertedText,
                imagePath: imagePath
            )
        }

        let manifest = Manifest(version: 1, exportedAt: Date(), records: archivedRecords)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        entries.insert(.init(name: "manifest.json", data: try encoder.encode(manifest)), at: 0)
        return try SimpleZipArchive.encode(entries)
    }

    static func decode(_ data: Data) throws -> [HistoryRecord] {
        let entries = try SimpleZipArchive.decode(data)
        guard let manifestData = entries["manifest.json"] else {
            throw ArchiveError.missingManifest
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.version == 1 else { throw ArchiveError.unsupportedVersion }

        var ids = Set<String>()
        return try manifest.records.map { archived in
            guard archived.id == creationID(for: archived.timestamp),
                  ids.insert(archived.id).inserted
            else { throw ArchiveError.invalidRecord }
            let imageData = try archived.imagePath.map { path in
                guard let data = entries[path] else { throw ArchiveError.invalidRecord }
                return data
            }
            return HistoryRecord(
                timestamp: archived.timestamp,
                originalText: archived.originalText,
                convertedText: archived.convertedText,
                imageData: imageData
            )
        }
    }

    private static func creationID(for date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}
