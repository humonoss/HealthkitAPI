//
//  FirebaseManager.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseDatabase
import FirebaseAuth

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    @Published var syncStatus: SyncStatus = SyncStatus()
    @Published var isConnected: Bool = false

    private var database: DatabaseReference!
    private var userId: String?
    private var connectionRef: DatabaseReference?

    // Throttling for real-time updates
    private var lastHeartRateSync: Date?
    private let heartRateSyncInterval: TimeInterval = 1.0 // 1 second

    private init() {
        setupDatabase()
        setupConnectionMonitoring()
    }

    // MARK: - Setup

    private func setupDatabase() {
        // IMPORTANT: Enable persistence BEFORE getting any database reference
        Database.database().isPersistenceEnabled = true

        // Now get the database reference
        database = Database.database().reference()

        print("✅ Firebase Database initialized")
    }

    private func setupConnectionMonitoring() {
        connectionRef = Database.database().reference(withPath: ".info/connected")

        connectionRef?.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }

                if let connected = snapshot.value as? Bool, connected {
                    self.isConnected = true
                    self.syncStatus.status = .active
                    print("🟢 Firebase connected")

                    // Process queued items when connection restored
                    await self.processQueue()
                } else {
                    self.isConnected = false
                    self.syncStatus.markOffline()
                    print("🔴 Firebase disconnected")
                }
            }
        }
    }

    // MARK: - Authentication

    func authenticateAnonymously() async throws {
        do {
            let result = try await Auth.auth().signInAnonymously()
            userId = result.user.uid
            print("✅ Authenticated anonymously: \(userId ?? "unknown")")
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

        // Check if Firebase is connected
        if !isConnected {
            print("📦 Offline: Queueing \(type) for later sync")
            SyncQueueManager.shared.enqueue(path: path, data: data)
            syncStatus.addPendingItem()
            syncStatus.markOffline()
            return
        }

        print("📤 Online: Syncing \(type): \(value) \(unit)")
        let ref = database.child(path).childByAutoId()

        do {
            try await ref.setValue(data)
            syncStatus.markSynced(dataType: type)
            print("✅ Synced \(type): \(value) \(unit)")
        } catch {
            print("❌ Sync error for \(type): \(error.localizedDescription)")
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
        let ref = database.child(path)

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
            print("⚠️ No aggregated data to sync")
            return
        }

        // Check if Firebase is connected
        if !isConnected {
            print("📦 Offline: Queueing aggregated data for later sync")
            SyncQueueManager.shared.enqueue(path: path, data: updates)
            syncStatus.addPendingItem()
            syncStatus.markOffline()
            return
        }

        print("📤 Online: Syncing aggregated data")
        print("📤 Data keys: \(updates.keys.joined(separator: ", "))")

        do {
            try await ref.updateChildValues(updates)
            syncStatus.markSynced(dataType: "aggregated")
            print("✅ Synced aggregated data: \(updates.keys.joined(separator: ", "))")
        } catch {
            print("❌ Aggregated sync error: \(error.localizedDescription)")
            syncStatus.markError(error.localizedDescription)

            // Queue for retry
            print("📦 Queueing aggregated data for retry")
            SyncQueueManager.shared.enqueue(path: path, data: updates)
            syncStatus.addPendingItem()
        }
    }

    // MARK: - Batch Sync

    func syncHealthDataPacket(packet: HealthDataPacket) async {
        // Sync real-time metrics
        if let heartRate = packet.heartRate {
            await syncRealtimeMetric(type: "heartRate", value: heartRate, unit: "bpm")
        }

        if let hrv = packet.hrv {
            await syncRealtimeMetric(type: "hrv", value: hrv, unit: "ms")
        }

        if let respiratoryRate = packet.respiratoryRate {
            await syncRealtimeMetric(type: "respiratoryRate", value: respiratoryRate, unit: "breaths/min")
        }

        if let bloodOxygen = packet.bloodOxygen {
            await syncRealtimeMetric(type: "bloodOxygen", value: bloodOxygen, unit: "%")
        }

        // Sync aggregated data
        await syncAggregatedData(packet: packet)

        // Update metadata
        await updateMetadata()
    }

    // MARK: - Metadata

    private func updateMetadata() async {
        guard let userId = ensureUserId() else {
            return
        }

        let path = "users/\(userId)/healthData/metadata"
        let ref = database.child(path)

        let metadata: [String: Any] = [
            "lastSync": Date().timeIntervalSince1970 * 1000,
            "syncStatus": syncStatus.status.rawValue,
            "pendingItems": syncStatus.pendingItems
        ]

        do {
            try await ref.updateChildValues(metadata)
        } catch {
            print("❌ Metadata update error: \(error.localizedDescription)")
        }
    }

    // MARK: - Queue Processing

    private func processQueue() async {
        let items = SyncQueueManager.shared.queuedItems

        guard !items.isEmpty else {
            return
        }

        print("🔄 Processing \(items.count) queued items")

        for item in items {
            let ref = database.child(item.path)

            do {
                try await ref.updateChildValues(item.data)
                SyncQueueManager.shared.dequeue(item: item)
                syncStatus.removePendingItem()
                print("✅ Processed queued item: \(item.path)")
            } catch {
                print("❌ Failed to process queued item: \(error.localizedDescription)")
                SyncQueueManager.shared.incrementRetry(item: item)

                // Wait before next retry (exponential backoff)
                let delay = SyncQueueManager.shared.getRetryDelay(for: item)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: - Manual Sync

    func manualSync() async {
        print("🔄 Manual sync triggered")
        await processQueue()
        await updateMetadata()
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Start the actual operation
            group.addTask {
                try await operation()
            }

            // Start the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            // Return the first result (either operation completes or timeout)
            let result = try await group.next()!

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }
}

// Timeout error
struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}
