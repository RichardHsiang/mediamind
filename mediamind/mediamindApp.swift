//
//  mediamindApp.swift
//  mediamind
//

import SwiftUI
import SwiftData

@main
struct mediamindApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Handle schema mismatch by attempting to delete the store and recreate it
            // This is useful during development when schema changes frequently
            print("Failed to load ModelContainer: \(error). Attempting to reset storage.")
            
            #if DEBUG
            try? FileManager.default.removeItem(at: modelConfiguration.url)
            #endif
            
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1200, height: 800)
    }
}
