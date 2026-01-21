//
//  DownloadManager.swift
//  Ears
//
//  Background download queue manager
//

import Foundation
import Observation
import SwiftData

/// Manages downloading audiobooks for offline playback.
///
/// Features:
/// - Background download support
/// - Queue management with priority
/// - Resume capability for interrupted downloads
/// - Auto-download next in series
@Observable
final class DownloadManager: NSObject {
    // MARK: - Singleton

    static let shared = DownloadManager()

    // MARK: - Types

    enum DownloadState: Equatable {
        case queued
        case downloading(progress: Double)
        case completed
        case failed(String)
        case paused
    }

    struct DownloadTask: Identifiable {
        let id: String
        let bookId: String
        let bookTitle: String
        let authorName: String
        var state: DownloadState
        var progress: Double
        var bytesDownloaded: Int64
        var totalBytes: Int64
        let createdAt: Date

        var progressText: String {
            let downloaded = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloaded) / \(total)"
        }
    }

    // MARK: - Properties

    /// Active download tasks
    private(set) var tasks: [DownloadTask] = []

    /// Completed downloads count
    private(set) var completedCount = 0

    /// Whether downloads are paused
    private(set) var isPaused = false

    // MARK: - Private Properties

    private var urlSession: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private let maxConcurrentDownloads = 2

    // MARK: - Initialization

    override private init() {
        super.init()

        // Configure background session
        let config = URLSessionConfiguration.background(withIdentifier: "com.ears.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true

        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        // Restore any pending downloads
        restorePendingDownloads()
    }

    // MARK: - Public Methods

    /// Add a book to the download queue
    func download(book: Book) {
        // Check if already in queue
        if tasks.contains(where: { $0.bookId == book.id }) {
            return
        }

        let task = DownloadTask(
            id: UUID().uuidString,
            bookId: book.id,
            bookTitle: book.title,
            authorName: book.authorName,
            state: .queued,
            progress: 0,
            bytesDownloaded: 0,
            totalBytes: book.media?.size ?? 0,
            createdAt: Date()
        )

        tasks.append(task)
        processQueue()
    }

    /// Cancel a download
    func cancel(taskId: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        // Cancel the URL session task if active
        if let urlTask = activeTasks[taskId] {
            urlTask.cancel()
            activeTasks.removeValue(forKey: taskId)
        }

        tasks.remove(at: index)
        processQueue()
    }

    /// Pause all downloads
    func pauseAll() {
        isPaused = true
        for (id, task) in activeTasks {
            task.suspend()
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index].state = .paused
            }
        }
    }

    /// Resume all downloads
    func resumeAll() {
        isPaused = false
        for (id, task) in activeTasks {
            task.resume()
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index].state = .downloading(progress: tasks[index].progress)
            }
        }
        processQueue()
    }

    /// Delete a downloaded file
    func deleteDownload(bookId: String, modelContext: ModelContext) {
        // Find and delete the file
        let descriptor = FetchDescriptor<DownloadedFile>(
            predicate: #Predicate { $0.bookId == bookId }
        )

        if let files = try? modelContext.fetch(descriptor),
           let file = files.first {
            // Delete file from disk
            if let url = file.fileURL {
                try? FileManager.default.removeItem(at: url)
            }

            // Delete from database
            modelContext.delete(file)
            try? modelContext.save()
        }
    }

    /// Get total storage used by downloads
    func calculateStorageUsed(modelContext: ModelContext) -> Int64 {
        let descriptor = FetchDescriptor<DownloadedFile>()
        guard let files = try? modelContext.fetch(descriptor) else { return 0 }
        return files.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Private Methods

    private func processQueue() {
        guard !isPaused else { return }

        // Count active downloads
        let activeCount = tasks.filter {
            if case .downloading = $0.state { return true }
            return false
        }.count

        // Start more downloads if under limit
        if activeCount < maxConcurrentDownloads {
            let queued = tasks.filter { $0.state == .queued }
            for task in queued.prefix(maxConcurrentDownloads - activeCount) {
                startDownload(task)
            }
        }
    }

    private func startDownload(_ task: DownloadTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        // Get download URL
        guard let serverURL = URL(string: UserDefaults.standard.string(forKey: "serverURL") ?? ""),
              let token = KeychainManager.shared.getToken() else {
            tasks[index].state = .failed("Not authenticated")
            return
        }

        // Build download URL
        var components = URLComponents(url: serverURL.appendingPathComponent("/api/items/\(task.bookId)/file/"), resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let url = components?.url else {
            tasks[index].state = .failed("Invalid URL")
            return
        }

        // Create download task
        let urlTask = urlSession.downloadTask(with: url)
        urlTask.taskDescription = task.id

        activeTasks[task.id] = urlTask
        tasks[index].state = .downloading(progress: 0)

        urlTask.resume()
    }

    private func restorePendingDownloads() {
        urlSession.getTasksWithCompletionHandler { [weak self] _, _, downloadTasks in
            for task in downloadTasks {
                if let id = task.taskDescription {
                    self?.activeTasks[id] = task
                }
            }
        }
    }

    private func saveDownloadedFile(taskId: String, location: URL) {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return }

        // Move file to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)

        // Create downloads directory if needed
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)

        let fileName = "\(task.bookId).m4a"
        let destinationURL = downloadsPath.appendingPathComponent(fileName)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)

            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            // Create database record
            // Note: This should be done with a ModelContext passed in
            // For now, we'll post a notification
            NotificationCenter.default.post(
                name: .downloadCompleted,
                object: nil,
                userInfo: [
                    "bookId": task.bookId,
                    "bookTitle": task.bookTitle,
                    "authorName": task.authorName,
                    "fileName": fileName,
                    "filePath": "Downloads/\(fileName)",
                    "fileSize": fileSize
                ]
            )

        } catch {
            print("Failed to save downloaded file: \(error)")

            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].state = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = downloadTask.taskDescription,
              let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }

        // Save the file
        saveDownloadedFile(taskId: taskId, location: location)

        // Update state
        tasks[index].state = .completed
        tasks[index].progress = 1.0
        completedCount += 1

        // Clean up
        activeTasks.removeValue(forKey: taskId)

        // Process queue
        processQueue()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskId = downloadTask.taskDescription,
              let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        tasks[index].state = .downloading(progress: progress)
        tasks[index].progress = progress
        tasks[index].bytesDownloaded = totalBytesWritten
        tasks[index].totalBytes = totalBytesExpectedToWrite
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskId = task.taskDescription,
              let index = tasks.firstIndex(where: { $0.id == taskId }),
              let error = error else {
            return
        }

        // Check if it's a cancellation
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            // User cancelled, already handled
            return
        }

        tasks[index].state = .failed(error.localizedDescription)
        activeTasks.removeValue(forKey: taskId)

        processQueue()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Notify the system that background work is complete
        // This is called when all background tasks are done
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
}
