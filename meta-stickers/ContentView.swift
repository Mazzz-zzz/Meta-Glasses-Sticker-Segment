//
//  ContentView.swift
//  meta-stickers
//
//  Created by Almaz Khalilov on 13/12/2025.
//

import SwiftUI
import SwiftData

/// Legacy ContentView - Not used in the main app flow.
/// The app uses MainAppView -> TabContainerView as the entry point.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stickers: [Sticker]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(stickers) { sticker in
                    NavigationLink {
                        Text("Sticker: \(sticker.prompt)")
                    } label: {
                        Text(sticker.prompt)
                    }
                }
            }
            .navigationTitle("Stickers")
        } detail: {
            Text("Select a sticker")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Sticker.self, inMemory: true)
}
