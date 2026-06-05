//
//  ChSimplifyApp.swift
//  ChSimplify
//
//  Created by xhy on 2026/6/5.
//

import SwiftUI
import SwiftData

@main
struct ChSimplifyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Record.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
