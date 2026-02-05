//
//  HealthData.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import Foundation
import WatchKit

/// Represents a comprehensive health data packet
struct HealthDataPacket: Codable {
    // Real-time metrics (Tier 1)
    var heartRate: Double?
    var hrv: Double?
    var respiratoryRate: Double?
    var bloodOxygen: Double?

    // Interval metrics (Tier 2)
    var stepCount: Int?
    var distance: Double?
    var activeEnergy: Double?
    var standTime: Int?
    var flightsClimbed: Int?

    // Metadata
    var timestamp: Date
    var deviceInfo: DeviceInfo

    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.deviceInfo = DeviceInfo.current
    }

    /// Convert to Firebase-compatible dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "timestamp": timestamp.timeIntervalSince1970 * 1000, // milliseconds
            "deviceInfo": deviceInfo.toDictionary()
        ]

        if let heartRate = heartRate {
            dict["heartRate"] = ["value": heartRate, "unit": "bpm"]
        }
        if let hrv = hrv {
            dict["hrv"] = ["value": hrv, "unit": "ms"]
        }
        if let respiratoryRate = respiratoryRate {
            dict["respiratoryRate"] = ["value": respiratoryRate, "unit": "breaths/min"]
        }
        if let bloodOxygen = bloodOxygen {
            dict["bloodOxygen"] = ["value": bloodOxygen, "unit": "%"]
        }
        if let stepCount = stepCount {
            dict["stepCount"] = ["value": stepCount, "unit": "steps"]
        }
        if let distance = distance {
            dict["distance"] = ["value": distance, "unit": "meters"]
        }
        if let activeEnergy = activeEnergy {
            dict["activeEnergy"] = ["value": activeEnergy, "unit": "kcal"]
        }
        if let standTime = standTime {
            dict["standTime"] = ["value": standTime, "unit": "minutes"]
        }
        if let flightsClimbed = flightsClimbed {
            dict["flightsClimbed"] = ["value": flightsClimbed, "unit": "flights"]
        }

        return dict
    }
}

/// Device information for context
struct DeviceInfo: Codable {
    var watchModel: String
    var watchOSVersion: String
    var deviceName: String
    var batteryLevel: Float?

    static var current: DeviceInfo {
        let device = WKInterfaceDevice.current()

        return DeviceInfo(
            watchModel: device.model,
            watchOSVersion: device.systemVersion,
            deviceName: device.name,
            batteryLevel: nil // Battery monitoring requires additional setup
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "watchModel": watchModel,
            "watchOSVersion": watchOSVersion,
            "deviceName": deviceName
        ]

        if let batteryLevel = batteryLevel {
            dict["batteryLevel"] = batteryLevel
        }

        return dict
    }
}

/// Workout data structure
struct WorkoutData: Codable {
    var workoutId: String
    var type: String
    var startTime: Date
    var endTime: Date
    var avgHeartRate: Double?
    var totalDistance: Double?
    var totalEnergy: Double?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "workoutId": workoutId,
            "type": type,
            "startTime": startTime.timeIntervalSince1970 * 1000,
            "endTime": endTime.timeIntervalSince1970 * 1000
        ]

        var metrics: [String: Any] = [:]
        if let avgHeartRate = avgHeartRate {
            metrics["avgHeartRate"] = avgHeartRate
        }
        if let totalDistance = totalDistance {
            metrics["totalDistance"] = totalDistance
        }
        if let totalEnergy = totalEnergy {
            metrics["totalEnergy"] = totalEnergy
        }

        if !metrics.isEmpty {
            dict["metrics"] = metrics
        }

        return dict
    }
}
