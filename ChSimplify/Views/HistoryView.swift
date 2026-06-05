//
//  HistoryView.swift
//  ChSimplify
//
//  「历史记录」Tab：展示过往识别结果，点击图片进入全屏预览页，行其余区域看详情，可删除。
//

import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Record.timestamp, order: .reverse) private var records: [Record]

    @State private var preview: PreviewPayload?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("暂无记录",
                                           systemImage: "clock",
                                           description: Text("识别过的图片会出现在这里"))
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
            .fullScreenCover(item: $preview) { payload in
                TextPreviewView(image: payload.image, preRecognizedLines: payload.lines)
            }
        }
    }

    private func row(_ record: Record) -> some View {
        let uiImage = record.imageData.flatMap { UIImage(data: $0) }
        return HStack(spacing: 12) {
            // 点击图片进入全屏预览页（绿框选字 + 查看简繁体）。
            Button {
                if let uiImage {
                    preview = PreviewPayload(image: uiImage)
                }
            } label: {
                thumbnail(uiImage)
            }
            .buttonStyle(.plain)

            // 点击文字区域进入文字详情页。
            NavigationLink {
                RecordDetailView(record: record)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.convertedText)
                        .lineLimit(2)
                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
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
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: Record.self, inMemory: true)
}
