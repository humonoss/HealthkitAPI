//
//  SyncStatus.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import Foundation

/// Tracks the sync status of health data to Firebase
struct SyncStatus: Codable {
    var lastSyncTime: Date?
    var status: Status
    var pendingItems: Int
    var dataTypesSynced: Set<String>
    var errorMessage: String?

    init() {
        self.lastSyncTime = nil
        self.status = .offline
        self.pendingItems = 0
        self.dataTypesSynced = []
        self.errorMessage = nil
    }

    enum Status: String, Codable {
        case active = "active"
        case paused = "paused"
        case error = "error"
        case offline = "offline"

        var displayName: String {
            switch self {
            case .active: return "Syncing"
            case .paused: return "Paused"
            case .error: return "Error"
            case .offline: return "Offline"
            }
        }
    }

    mutating func markSynced(dataType: String) {
        dataTypesSynced.insert(dataType)
        lastSyncTime = Date()
        status = .active
        errorMessage = nil
    }

    mutating func markError(_ error: String) {
        status = .error
        errorMessage = error
    }

    mutating func markOffline() {
        status = .offline
    }

    mutating func addPendingItem() {
        pendingItems += 1
    }

    mutating func removePendingItem() {
        if pendingItems > 0 {
            pendingItems -= 1
        }
    }
}

/// Queued item for offline sync
struct QueuedSyncItem: Codable, Identifiable {
    var id: String
    var path: String
    var data: [String: Any]
    var timestamp: Date
    var retryCount: Int

    init(path: String, data: [String: Any]) {
        self.id = UUID().uuidString
        self.path = path
        self.data = data
        self.timestamp = Date()
        self.retryCount = 0
    }

    enum CodingKeys: String, CodingKey {
        case id, path, timestamp, retryCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        data = [:] // Will be stored separately
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(retryCount, forKey: .retryCount)
    }
}

/// Health data authorization status
enum HealthDataStatus {
    case unavailable
    case notDetermined
    case denied
    case authorized

    var displayName: String {
        switch self {
        case .unavailable: return "Not Available"
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        }
    }
}
