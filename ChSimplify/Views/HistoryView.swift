//
//  HistoryView.swift
//  ChSimplify
//
//  「历史记录」Tab：展示过往识别结果，点击整行进入详情页，可删除。
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var recordStore: RecordStore
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: HistoryArchiveDocument?
    @State private var exportCount = 0
    @State private var toastMessage: String?

    private var records: [HistoryRecord] {
        recordStore.records
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    EmptyStateView(title: "暂无记录",
                                   systemImage: "clock",
                                   description: "识别过的图片会出现在这里")
                } else {
                    List {
                        ForEach(records) { record in
                            row(record)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("导入历史记录")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        prepareExport()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("导出历史记录")
                    .disabled(records.isEmpty)
                }
                if !records.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false,
                onCompletion: importArchive
            )
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .zip,
                defaultFilename: exportFilename,
                onCompletion: exportCompleted
            )
            .toast($toastMessage)
        }
    }

    private func row(_ record: HistoryRecord) -> some View {
        let uiImage = record.imageData.flatMap { UIImage(data: $0) }
        // 点击整行（含缩略图）进入详情页。
        return NavigationLink {
            RecordDetailView(record: record)
        } label: {
            HStack(spacing: 12) {
                thumbnail(uiImage)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.convertedText)
                        .lineLimit(2)
                    Text(record.timestamp.chineseDateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ uiImage: UIImage?) -> some View {
        if let uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        recordStore.delete(at: offsets)
    }

    private func prepareExport() {
        do {
            exportDocument = try HistoryArchiveDocument(records: records)
            exportCount = records.count
            showExporter = true
        } catch {
            toastMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func exportCompleted(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            toastMessage = "已导出 \(exportCount) 条记录"
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                toastMessage = "导出失败：\(error.localizedDescription)"
            }
        }
        exportDocument = nil
    }

    private func importArchive(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let imported = try HistoryArchive.decode(data)
            let count = recordStore.importRecords(imported)
            toastMessage = count == 0
                ? "没有新的历史记录"
                : "已导入 \(count) 条记录"
        } catch {
            if (error as NSError).code != NSUserCancelledError {
                toastMessage = "导入失败：\(error.localizedDescription)"
            }
        }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "繁体转换历史-\(formatter.string(from: Date()))"
    }
}

#Preview {
    HistoryView()
        .environmentObject(RecordStore(inMemory: true))
}
