//
//  StickerDetailView.swift
//  meta-stickers
//

import SwiftUI
import SwiftData

struct StickerDetailView: View {
    @Bindable var sticker: Sticker
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Full-size sticker image
                    StickerImageView(sticker: sticker)

                    // Metadata section
                    MetadataSection(sticker: sticker)

                    // Tags section
                    TagsSection(sticker: sticker)

                    // Actions section
                    ActionsSection(
                        sticker: sticker,
                        showShareSheet: $showShareSheet,
                        showDeleteConfirmation: $showDeleteConfirmation
                    )

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sticker Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sticker.isFavorite.toggle()
                    } label: {
                        Image(systemName: sticker.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(sticker.isFavorite ? .red : .primary)
                    }
                }
            }
        }
        .confirmationDialog("Delete Sticker", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this sticker? This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = sticker.fullImage {
                ShareSheet(image: image)
            }
        }
    }
}

// MARK: - Sticker Image View
struct StickerImageView: View {
    let sticker: Sticker

    var body: some View {
        ZStack {
            // Checkerboard background
            CheckerboardBackground()
                .cornerRadius(16)

            if let image = sticker.fullImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Image not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxHeight: 300)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Metadata Section
struct MetadataSection: View {
    let sticker: Sticker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                MetadataRow(label: "Prompt", value: sticker.prompt)
                Divider()
                MetadataRow(label: "Created", value: sticker.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let score = sticker.score {
                    Divider()
                    MetadataRow(label: "Confidence", value: String(format: "%.1f%%", score * 100))
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Tags Section
struct TagsSection: View {
    @Bindable var sticker: Sticker
    @State private var newTag: String = ""
    @State private var isAddingTag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.headline)
                Spacer()
                Button {
                    isAddingTag = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            if sticker.tags.isEmpty && !isAddingTag {
                Text("No tags")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(sticker.tags, id: \.self) { tag in
                        TagChip(tag: tag) {
                            sticker.tags.removeAll { $0 == tag }
                        }
                    }

                    if isAddingTag {
                        HStack(spacing: 4) {
                            TextField("Tag", text: $newTag)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .onSubmit {
                                    addTag()
                                }

                            Button {
                                addTag()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }

                            Button {
                                isAddingTag = false
                                newTag = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !sticker.tags.contains(trimmed) {
            sticker.tags.append(trimmed)
        }
        newTag = ""
        isAddingTag = false
    }
}

struct TagChip: View {
    let tag: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.subheadline)
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Actions Section
struct ActionsSection: View {
    let sticker: Sticker
    @Binding var showShareSheet: Bool
    @Binding var showDeleteConfirmation: Bool

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Sticker")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Sticker")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
        }
    }
}
