//
//  StickerLibraryView.swift
//  meta-stickers
//

import SwiftUI
import SwiftData

enum StickerFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
}

enum StickerSort: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case prompt = "Prompt"
}

struct StickerLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sticker.createdAt, order: .reverse) private var allStickers: [Sticker]

    @State private var selectedFilter: StickerFilter = .all
    @State private var selectedSort: StickerSort = .newest
    @State private var searchText: String = ""
    @State private var selectedSticker: Sticker?
    @State private var showDeleteConfirmation = false
    @State private var stickerToDelete: Sticker?

    private var filteredStickers: [Sticker] {
        var stickers = allStickers

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            stickers = stickers.filter { $0.isFavorite }
        }

        // Apply search
        if !searchText.isEmpty {
            stickers = stickers.filter { sticker in
                sticker.prompt.localizedCaseInsensitiveContains(searchText) ||
                sticker.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Apply sort
        switch selectedSort {
        case .newest:
            stickers.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            stickers.sort { $0.createdAt < $1.createdAt }
        case .prompt:
            stickers.sort { $0.prompt < $1.prompt }
        }

        return stickers
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter and sort bar
                FilterSortBar(
                    selectedFilter: $selectedFilter,
                    selectedSort: $selectedSort
                )

                if filteredStickers.isEmpty {
                    EmptyLibraryView(filter: selectedFilter, searchText: searchText)
                } else {
                    // Sticker count
                    HStack {
                        Text("\(filteredStickers.count) sticker\(filteredStickers.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Sticker grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredStickers) { sticker in
                                LibraryStickerCell(sticker: sticker)
                                    .onTapGesture {
                                        selectedSticker = sticker
                                    }
                                    .contextMenu {
                                        Button {
                                            sticker.isFavorite.toggle()
                                        } label: {
                                            Label(
                                                sticker.isFavorite ? "Unfavorite" : "Favorite",
                                                systemImage: sticker.isFavorite ? "heart.slash" : "heart"
                                            )
                                        }

                                        Button(role: .destructive) {
                                            stickerToDelete = sticker
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search stickers...")
            .sheet(item: $selectedSticker) { sticker in
                StickerDetailView(sticker: sticker) {
                    deleteSticker(sticker)
                }
            }
            .confirmationDialog("Delete Sticker", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let sticker = stickerToDelete {
                        deleteSticker(sticker)
                    }
                }
                Button("Cancel", role: .cancel) {
                    stickerToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this sticker?")
            }
        }
    }

    private func deleteSticker(_ sticker: Sticker) {
        modelContext.delete(sticker)
        stickerToDelete = nil
        selectedSticker = nil
    }
}

// MARK: - Filter Sort Bar
struct FilterSortBar: View {
    @Binding var selectedFilter: StickerFilter
    @Binding var selectedSort: StickerSort

    var body: some View {
        HStack(spacing: 16) {
            // Filter picker
            Menu {
                ForEach(StickerFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack {
                            Text(filter.rawValue)
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filterIcon)
                    Text(selectedFilter.rawValue)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }

            // Sort picker
            Menu {
                ForEach(StickerSort.allCases, id: \.self) { sort in
                    Button {
                        selectedSort = sort
                    } label: {
                        HStack {
                            Text(sort.rawValue)
                            if selectedSort == sort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(selectedSort.rawValue)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var filterIcon: String {
        switch selectedFilter {
        case .all: return "square.grid.2x2"
        case .favorites: return "heart.fill"
        }
    }
}

// MARK: - Library Sticker Cell
struct LibraryStickerCell: View {
    let sticker: Sticker

    var body: some View {
        ZStack {
            // Checkerboard background
            CheckerboardBackground()
                .cornerRadius(12)

            // Thumbnail image
            if let image = sticker.thumbnailImage ?? sticker.fullImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }

            // Favorite indicator
            if sticker.isFavorite {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Empty Library View
struct EmptyLibraryView: View {
    let filter: StickerFilter
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var iconName: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        }
        switch filter {
        case .all:
            return "photo.on.rectangle.angled"
        case .favorites:
            return "heart.slash"
        }
    }

    private var title: String {
        if !searchText.isEmpty {
            return "No Results"
        }
        switch filter {
        case .all:
            return "No Stickers Yet"
        case .favorites:
            return "No Favorites"
        }
    }

    private var subtitle: String {
        if !searchText.isEmpty {
            return "Try a different search term"
        }
        switch filter {
        case .all:
            return "Start streaming and enable SAM3 to generate stickers automatically"
        case .favorites:
            return "Tap the heart icon on a sticker to add it to your favorites"
        }
    }
}
