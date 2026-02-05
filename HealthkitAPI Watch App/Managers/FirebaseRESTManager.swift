//
//  FirebaseRESTManager.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import Foundation
import Combine
import FirebaseAuth

/// Firebase manager using REST API instead of WebSockets to bypass NECP policy issues
@MainActor
class FirebaseRESTManager: ObservableObject {
    static let shared = FirebaseRESTManager()

    @Published var syncStatus: SyncStatus = SyncStatus()
    @Published var isConnected: Bool = false

    private let databaseURL = "https://YOUR_DATABASE_URL.firebaseio.com"
    private var userId: String?

    // Throttling for real-time updates
    private var lastHeartRateSync: Date?
    private let heartRateSyncInterval: TimeInterval = 1.0 // 1 second

    private init() {
        // Test connection on init
        Task {
            await testConnection()
        }
    }

    // MARK: - Connection Test

    private func testConnection() async {
        do {
            let url = URL(string: "\(databaseURL)/.json")!
            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                isConnected = true
                syncStatus.status = .active
                print("🟢 Firebase REST API connected")
            }
        } catch {
            isConnected = false
            syncStatus.markOffline()
            print("🔴 Firebase REST API connection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Authentication

    func authenticateAnonymously() async throws {
        do {
            let result = try await Auth.auth().signInAnonymously()
            userId = result.user.uid
            print("✅ Authenticated anonymously: \(userId ?? "unknown")")

            // Test connection after auth
            await testConnection()
        } catch {
            print("❌ Authentication error: \(error.localizedDescription)")
            throw error
        }
    }

    private func ensureUserId() -> String? {
        if userId == nil {
            userId = Auth.auth().currentUser?.uid
        }
        return userId
    }

    // MARK: - Real-time Sync

    func syncRealtimeMetric(type: String, value: Double, unit: String) async {
        guard let userId = ensureUserId() else {
            print("⚠️ Cannot sync: no user ID")
            return
        }

        // Throttle heart rate updates to 1/second
        if type == "heartRate" {
            if let lastSync = lastHeartRateSync,
               Date().timeIntervalSince(lastSync) < heartRateSyncInterval {
                return // Skip this update
            }
            lastHeartRateSync = Date()
        }

        let timestamp = Date().timeIntervalSince1970 * 1000 // milliseconds
        let path = "users/\(userId)/healthData/realtime/\(type)"

        let data: [String: Any] = [
            "value": value,
            "unit": unit,
            "timestamp": timestamp
        ]

        print("📤 REST: Syncing \(type): \(value) \(unit)")

        do {
            try await postData(path: path, data: data)
            syncStatus.markSynced(dataType: type)
            isConnected = true
            print("✅ REST: Synced \(type): \(value) \(unit)")
        } catch {
            print("❌ REST: Sync error for \(type): \(error.localizedDescription)")
            syncStatus.markError(error.localizedDescription)

            // Queue for retry
            print("📦 Queueing \(type) for retry")
            SyncQueueManager.shared.enqueue(path: path, data: data)
            syncStatus.addPendingItem()
        }
    }

    // MARK: - Aggregated Sync

    func syncAggregatedData(packet: HealthDataPacket) async {
        guard let userId = ensureUserId() else {
            print("⚠️ Cannot sync: no user ID")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: packet.timestamp)

        let path = "users/\(userId)/healthData/aggregated/daily/\(dateString)"

        var updates: [String: Any] = [:]

        if let stepCount = packet.stepCount {
            updates["steps/total"] = stepCount
            updates["steps/lastUpdated"] = packet.timestamp.timeIntervalSince1970 * 1000
        }

        if let distance = packet.distance {
            updates["distance/total"] = distance
            updates["distance/unit"] = "meters"
            updates["distance/lastUpdated"] = packet.timestamp.timeIntervalSince1970 * 1000
        }

        if let activeEnergy = packet.activeEnergy {
            updates["activeEnergy/total"] = activeEnergy
            updates["activeEnergy/unit"] = "kcal"
            updates["activeEnergy/lastUpdated"] = packet.timestamp.timeIntervalSince1970 * 1000
        }

        if let flightsClimbed = packet.flightsClimbed {
            updates["flightsClimbed/total"] = flightsClimbed
            updates["flightsClimbed/lastUpdated"] = packet.timestamp.timeIntervalSince1970 * 1000
        }

        guard !updates.isEmpty else {
            return
        }

        print("📤 REST: Syncing aggregated data")

        do {
            try await patchData(path: path, data: updates)
            syncStatus.markSynced(dataType: "aggregated")
            isConnected = true
            print("✅ REST: Synced aggregated data")
        } catch {
            print("❌ REST: Aggregated sync error: \(error.localizedDescription)")
            syncStatus.markError(error.localizedDescription)

            // Queue for retry
            print("📦 Queueing aggregated data for retry")
            SyncQueueManager.shared.enqueue(path: path, data: updates)
            syncStatus.addPendingItem()
        }
    }

    // MARK: - HTTP Methods

    private func postData(path: String, data: [String: Any]) async throws {
        let url = URL(string: "\(databaseURL)/\(path).json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseRESTError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FirebaseRESTError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func patchData(path: String, data: [String: Any]) async throws {
        let url = URL(string: "\(databaseURL)/\(path).json")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseRESTError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FirebaseRESTError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Queue Processing

    func processQueue() async {
        let items = SyncQueueManager.shared.queuedItems

        guard !items.isEmpty else {
            return
        }

        print("🔄 REST: Processing \(items.count) queued items")

        for item in items {
            do {
                try await patchData(path: item.path, data: item.data)
                SyncQueueManager.shared.dequeue(item: item)
                syncStatus.removePendingItem()
                print("✅ REST: Processed queued item: \(item.path)")
            } catch {
                print("❌ REST: Failed to process queued item: \(error.localizedDescription)")
                SyncQueueManager.shared.incrementRetry(item: item)

                // Wait before next retry
                let delay = SyncQueueManager.shared.getRetryDelay(for: item)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: - Manual Sync

    func manualSync() async {
        print("🔄 REST: Manual sync triggered")
        await processQueue()
    }
}

// MARK: - Errors

enum FirebaseRESTError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
