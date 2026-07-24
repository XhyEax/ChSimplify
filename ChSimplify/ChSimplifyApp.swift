//
//  ChSimplifyApp.swift
//  ChSimplify
//
//  Created by xhy on 2026/6/5.
//

import SwiftUI

@main
struct ChSimplifyApp: App {
    @StateObject private var recordStore = RecordStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordStore)
        }
    }
}
