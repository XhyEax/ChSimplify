//
//  ContentView.swift
//  ChSimplify
//
//  根视图：两个 Tab —— 拍照、历史记录。
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("拍照", systemImage: "camera")
                }
            HistoryView()
                .tabItem {
                    Label("历史记录", systemImage: "clock")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordStore(inMemory: true))
}
