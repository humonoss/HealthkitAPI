//
//  SyncQueueManager.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import Foundation
import Combine

@MainActor
class SyncQueueManager: ObservableObject {
    static let shared = SyncQueueManager()

    @Published var queuedItems: [QueuedSyncItem] = []
    private let maxQueueSize = 100
    private let maxRetries = 3

    private let queueKey = "syncQueue"

    private init() {
        loadQueue()
    }

    // MARK: - Queue Management

    func enqueue(path: String, data: [String: Any]) {
        // Check queue size limit
        if queuedItems.count >= maxQueueSize {
            // Remove oldest item
            queuedItems.removeFirst()
            print("⚠️ Sync queue full, removed oldest item")
        }

        let item = QueuedSyncItem(path: path, data: data)
        queuedItems.append(item)
        saveQueue()

        print("📥 Enqueued sync item: \(path)")
    }

    func dequeue(item: QueuedSyncItem) {
        queuedItems.removeAll { $0.id == item.id }
        saveQueue()

        print("📤 Dequeued sync item: \(item.path)")
    }

    func incrementRetry(item: QueuedSyncItem) {
        if let index = queuedItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = queuedItems[index]
            updatedItem.retryCount += 1

            if updatedItem.retryCount >= maxRetries {
                // Remove item after max retries
                queuedItems.remove(at: index)
                print("❌ Max retries reached for: \(item.path)")
            } else {
                queuedItems[index] = updatedItem
                print("🔄 Retry \(updatedItem.retryCount)/\(maxRetries) for: \(item.path)")
            }

            saveQueue()
        }
    }

    func clearQueue() {
        queuedItems.removeAll()
        saveQueue()
        print("🗑️ Cleared sync queue")
    }

    // MARK: - Persistence

    private func saveQueue() {
        // Save metadata (without data payloads due to UserDefaults limitations)
        let metadata = queuedItems.map { item -> [String: Any] in
            return [
                "id": item.id,
                "path": item.path,
                "timestamp": item.timestamp.timeIntervalSince1970,
                "retryCount": item.retryCount
            ]
        }

        UserDefaults.standard.set(metadata, forKey: queueKey)
    }

    private func loadQueue() {
        guard let metadata = UserDefaults.standard.array(forKey: queueKey) as? [[String: Any]] else {
            return
        }

        // Note: This is simplified - in production, you'd want to persist the actual data payloads
        // For now, we're just tracking metadata
        print("📂 Loaded \(metadata.count) queued items from storage")
    }

    // MARK: - Retry Logic

    func getRetryDelay(for item: QueuedSyncItem) -> TimeInterval {
        // Exponential backoff: 2^retryCount seconds
        let baseDelay: TimeInterval = 2.0
        return pow(baseDelay, Double(item.retryCount))
    }
}
