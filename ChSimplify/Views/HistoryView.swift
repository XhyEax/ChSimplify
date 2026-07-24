//
//  HistoryView.swift
//  ChSimplify
//
//  「历史记录」Tab：展示过往识别结果，点击整行进入详情页，可删除。
//

import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var recordStore: RecordStore

    private var records: [Record] {
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
                if !records.isEmpty {
                    EditButton()
                }
            }
        }
    }

    private func row(_ record: Record) -> some View {
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
}

#Preview {
    HistoryView()
        .environmentObject(RecordStore(inMemory: true))
}
