//
//  DownloadsView.swift
//  Ears
//
//  Manage downloaded audiobooks and storage
//

import SwiftUI
import SwiftData

/// View for managing downloaded audiobooks and storage.
///
/// Features:
/// - Active downloads with progress
/// - Downloaded books list
/// - Storage usage display
/// - Bulk delete options
struct DownloadsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadedFile.downloadedAt, order: .reverse) private var downloadedFiles: [DownloadedFile]

    @State private var showStorageInfo = false

    private var downloadManager = DownloadManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Active downloads
                if !downloadManager.tasks.isEmpty {
                    activeDownloadsSection
                }

                // Downloaded books
                if !downloadedFiles.isEmpty {
                    downloadedBooksSection
                }

                // Storage info
                storageSection
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !downloadManager.tasks.isEmpty {
                        Button {
                            if downloadManager.isPaused {
                                downloadManager.resumeAll()
                            } else {
                                downloadManager.pauseAll()
                            }
                        } label: {
                            Image(systemName: downloadManager.isPaused ? "play.fill" : "pause.fill")
                        }
                    }
                }
            }
            .overlay {
                if downloadedFiles.isEmpty && downloadManager.tasks.isEmpty {
                    emptyState
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Downloads",
            systemImage: "arrow.down.circle",
            description: Text("Downloaded audiobooks will appear here for offline listening")
        )
    }

    // MARK: - Active Downloads

    private var activeDownloadsSection: some View {
        Section("Downloading") {
            ForEach(downloadManager.tasks) { task in
                DownloadTaskRow(task: task) {
                    downloadManager.cancel(taskId: task.id)
                }
            }
        }
    }

    // MARK: - Downloaded Books

    private var downloadedBooksSection: some View {
        Section("Downloaded") {
            ForEach(downloadedFiles) { file in
                DownloadedBookRow(file: file)
            }
            .onDelete(perform: deleteDownloads)
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            Button {
                showStorageInfo = true
            } label: {
                HStack {
                    Label("Storage", systemImage: "internaldrive")

                    Spacer()

                    Text(formatBytes(totalStorageUsed))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        }
        .sheet(isPresented: $showStorageInfo) {
            StorageInfoView(totalUsed: totalStorageUsed, files: downloadedFiles)
        }
    }

    // MARK: - Computed Properties

    private var totalStorageUsed: Int64 {
        downloadedFiles.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Actions

    private func deleteDownloads(at offsets: IndexSet) {
        for index in offsets {
            let file = downloadedFiles[index]

            // Delete file from disk
            if let url = file.fileURL {
                try? FileManager.default.removeItem(at: url)
            }

            // Delete from database
            modelContext.delete(file)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Download Task Row

struct DownloadTaskRow: View {
    let task: DownloadManager.DownloadTask
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Book icon
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.bookTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(task.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Progress
                switch task.state {
                case .queued:
                    Text("Waiting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress)
                        Text(task.progressText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                case .paused:
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.orange)

                case .failed(let error):
                    Text("Failed: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)

                case .completed:
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Cancel button
            Button(role: .destructive) {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Downloaded Book Row

struct DownloadedBookRow: View {
    let file: DownloadedFile

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let coverData = file.coverData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.secondary)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.bookTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(file.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                    Text("•")
                    Text(formatDuration(file.duration))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Downloaded indicator
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Storage Info View

struct StorageInfoView: View {
    let totalUsed: Int64
    let files: [DownloadedFile]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                // Summary
                Section {
                    HStack {
                        Text("Total Downloads")
                        Spacer()
                        Text("\(files.count) books")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                }

                // Largest files
                if !files.isEmpty {
                    Section("Largest Downloads") {
                        ForEach(files.sorted { $0.fileSize > $1.fileSize }.prefix(5)) { file in
                            HStack {
                                Text(file.bookTitle)
                                    .lineLimit(1)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Actions
                Section {
                    Button("Delete All Downloads", role: .destructive) {
                        showDeleteAll = true
                    }
                }
            }
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete All Downloads?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    deleteAllDownloads()
                    dismiss()
                }
            } message: {
                Text("This will remove all downloaded audiobooks. You can re-download them later.")
            }
        }
    }

    private func deleteAllDownloads() {
        for file in files {
            if let url = file.fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(file)
        }
    }
}

// MARK: - Preview

#Preview {
    DownloadsView()
}
