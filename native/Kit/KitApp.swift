//
//  KitApp.swift
//  Kit
//
//  Created by Adele Roberts on 09/08/2026.
//

import SwiftUI

@main
struct KitApp: App {
    init() {
        KitSessionReminder.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
