//
//  SimpleZipArchive.swift
//  ChSimplify
//
//  Minimal ZIP STORE encoder/decoder. JPEG data is already compressed, so STORE
//  avoids a third-party dependency while producing a standard .zip archive.
//

import Foundation

enum SimpleZipArchive {
    struct Entry {
        let name: String
        let data: Data
    }

    enum ArchiveError: LocalizedError {
        case invalidArchive
        case unsupportedArchive
        case archiveTooLarge
        case duplicateEntry

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "压缩包已损坏"
            case .unsupportedArchive: return "压缩包格式不受支持"
            case .archiveTooLarge: return "压缩包内容过大"
            case .duplicateEntry: return "压缩包包含重复文件"
            }
        }
    }

    private struct CentralEntry {
        let nameData: Data
        let data: Data
        let crc: UInt32
        let offset: UInt32
    }

    static func encode(_ entries: [Entry]) throws -> Data {
        guard entries.count <= Int(UInt16.max) else { throw ArchiveError.archiveTooLarge }
        var archive = Data()
        var centralEntries: [CentralEntry] = []
        var names = Set<String>()

        for entry in entries {
            guard names.insert(entry.name).inserted else { throw ArchiveError.duplicateEntry }
            guard let nameData = entry.name.data(using: .utf8),
                  nameData.count <= Int(UInt16.max),
                  entry.data.count <= Int(UInt32.max),
                  archive.count <= Int(UInt32.max)
            else { throw ArchiveError.archiveTooLarge }

            let crc = crc32(entry.data)
            let offset = UInt32(archive.count)
            archive.appendLE(UInt32(0x04034b50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x0800))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(crc)
            archive.appendLE(UInt32(entry.data.count))
            archive.appendLE(UInt32(entry.data.count))
            archive.appendLE(UInt16(nameData.count))
            archive.appendLE(UInt16(0))
            archive.append(nameData)
            archive.append(entry.data)
            centralEntries.append(CentralEntry(
                nameData: nameData,
                data: entry.data,
                crc: crc,
                offset: offset
            ))
        }

        guard archive.count <= Int(UInt32.max) else { throw ArchiveError.archiveTooLarge }
        let centralOffset = UInt32(archive.count)
        for entry in centralEntries {
            archive.appendLE(UInt32(0x02014b50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x0800))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(entry.crc)
            archive.appendLE(UInt32(entry.data.count))
            archive.appendLE(UInt32(entry.data.count))
            archive.appendLE(UInt16(entry.nameData.count))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt32(0))
            archive.appendLE(entry.offset)
            archive.append(entry.nameData)
        }

        let centralSize = archive.count - Int(centralOffset)
        guard centralSize <= Int(UInt32.max) else { throw ArchiveError.archiveTooLarge }
        archive.appendLE(UInt32(0x06054b50))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(centralEntries.count))
        archive.appendLE(UInt16(centralEntries.count))
        archive.appendLE(UInt32(centralSize))
        archive.appendLE(centralOffset)
        archive.appendLE(UInt16(0))
        return archive
    }

    static func decode(_ archive: Data) throws -> [String: Data] {
        guard archive.count >= 22,
              let eocd = archive.lastIndex(of: UInt32(0x06054b50), searchLimit: 65_557)
        else { throw ArchiveError.invalidArchive }

        let entryCount = Int(try archive.uint16(at: eocd + 10))
        let centralSize = Int(try archive.uint32(at: eocd + 12))
        let centralOffset = Int(try archive.uint32(at: eocd + 16))
        guard entryCount <= 10_000,
              centralOffset >= 0,
              centralSize >= 0,
              centralOffset + centralSize <= archive.count
        else { throw ArchiveError.archiveTooLarge }

        var result: [String: Data] = [:]
        var cursor = centralOffset
        var totalUncompressed = 0

        for _ in 0..<entryCount {
            guard try archive.uint32(at: cursor) == 0x02014b50 else {
                throw ArchiveError.invalidArchive
            }
            let flags = try archive.uint16(at: cursor + 8)
            let method = try archive.uint16(at: cursor + 10)
            let expectedCRC = try archive.uint32(at: cursor + 16)
            let compressedSize = Int(try archive.uint32(at: cursor + 20))
            let uncompressedSize = Int(try archive.uint32(at: cursor + 24))
            let nameLength = Int(try archive.uint16(at: cursor + 28))
            let extraLength = Int(try archive.uint16(at: cursor + 30))
            let commentLength = Int(try archive.uint16(at: cursor + 32))
            let localOffset = Int(try archive.uint32(at: cursor + 42))
            guard flags & 0x0001 == 0, method == 0, compressedSize == uncompressedSize else {
                throw ArchiveError.unsupportedArchive
            }

            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= archive.count,
                  let name = String(data: archive.subdata(in: nameStart..<nameEnd), encoding: .utf8),
                  isSafePath(name),
                  result[name] == nil,
                  try archive.uint32(at: localOffset) == 0x04034b50
            else { throw ArchiveError.invalidArchive }

            let localNameLength = Int(try archive.uint16(at: localOffset + 26))
            let localExtraLength = Int(try archive.uint16(at: localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            let dataEnd = dataStart + compressedSize
            guard dataStart >= 0, dataEnd <= archive.count else {
                throw ArchiveError.invalidArchive
            }

            totalUncompressed += uncompressedSize
            guard totalUncompressed <= 1_000_000_000 else {
                throw ArchiveError.archiveTooLarge
            }
            let data = archive.subdata(in: dataStart..<dataEnd)
            guard crc32(data) == expectedCRC else { throw ArchiveError.invalidArchive }
            result[name] = data
            cursor = nameEnd + extraLength + commentLength
        }
        return result
    }

    private static func isSafePath(_ path: String) -> Bool {
        !path.isEmpty &&
        !path.hasPrefix("/") &&
        !path.contains("\\") &&
        !path.split(separator: "/").contains("..")
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb8_8320 : 0)
            }
        }
        return crc ^ 0xffff_ffff
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    func uint16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw SimpleZipArchive.ArchiveError.invalidArchive
        }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw SimpleZipArchive.ArchiveError.invalidArchive
        }
        return UInt32(self[offset]) |
            (UInt32(self[offset + 1]) << 8) |
            (UInt32(self[offset + 2]) << 16) |
            (UInt32(self[offset + 3]) << 24)
    }

    func lastIndex(of signature: UInt32, searchLimit: Int) -> Int? {
        guard count >= 4 else { return nil }
        let lowerBound = Swift.max(0, count - searchLimit)
        for index in stride(from: count - 4, through: lowerBound, by: -1) {
            if (try? uint32(at: index)) == signature { return index }
        }
        return nil
    }
}
