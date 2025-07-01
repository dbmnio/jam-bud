//
//  JamSession3App.swift
//  JamSession3
//
//  Created by David Matthew on 7/1/25.
//

import SwiftUI

@main
struct JamSession3App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
