//
//  HealthKitManager.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    @Published var authorizationStatus: HealthDataStatus = .unavailable
    @Published var isCollecting: Bool = false
    @Published var currentData: HealthDataPacket = HealthDataPacket()
    @Published var lastSyncTime: Date?
    @Published var heartRateHistory: [(date: Date, value: Double)] = []

    // Active queries
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var observerQueries: [HKObserverQuery] = []
    private var collectionTimer: Timer?

    // Query anchors for continuous data streaming
    private var heartRateAnchor: HKQueryAnchor?

    private init() {
        checkAvailability()
    }

    // MARK: - Availability

    private func checkAvailability() {
        if HKHealthStore.isHealthDataAvailable() {
            authorizationStatus = .notDetermined
        } else {
            authorizationStatus = .unavailable
        }
    }

    // MARK: - Health Data Types

    /// All health data types we want to read
    private var healthDataTypesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        // Tier 1: Real-time metrics
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let respiratoryRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRate)
        }
        if let bloodOxygen = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(bloodOxygen)
        }

        // Tier 2: Interval metrics
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let standTime = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            types.insert(standTime)
        }
        if let flightsClimbed = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flightsClimbed)
        }

        // Tier 3: Workouts
        types.insert(HKObjectType.workoutType())

        // Tier 4: Sleep
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }

        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        print("🔐 Requesting HealthKit authorization...")
        print("📋 Requesting access to \(healthDataTypesToRead.count) data types")

        let typesToRead = healthDataTypesToRead

        do {
            print("⏳ Calling healthStore.requestAuthorization...")
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            print("✅ Authorization request completed")

            // Verify actual access via test query
            try await verifyAuthorization()
            print("✅ Authorization verified: \(authorizationStatus.displayName)")
        } catch {
            print("❌ Authorization error: \(error.localizedDescription)")
            authorizationStatus = .denied
            throw error
        }
    }

    private func verifyAuthorization() async throws {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("⚠️ Could not create heart rate type")
            return
        }

        let status = healthStore.authorizationStatus(for: heartRateType)
        print("🔍 Authorization status check for heart rate: \(status.rawValue)")

        // Important: On watchOS, authorizationStatus may return .sharingDenied even when
        // permissions are granted through iPhone Health app. We need to do an actual query test.
        print("🧪 Performing actual data query test to verify access...")

        do {
            // Try to read the most recent heart rate sample
            let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: Date(), options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }

            // If we got here without error, we have access
            print("✅ Query test successful - access granted (found \(samples.count) samples)")
            authorizationStatus = .authorized

        } catch {
            // Query failed - check if it's a permission error
            print("⚠️ Query test failed: \(error.localizedDescription)")

            // Fall back to authorization status check
            switch status {
            case .notDetermined:
                print("⚠️ Authorization status: Not Determined")
                authorizationStatus = .notDetermined
            case .sharingDenied:
                print("❌ Authorization status: Denied")
                authorizationStatus = .denied
            case .sharingAuthorized:
                print("✅ Authorization status: Authorized")
                authorizationStatus = .authorized
            @unknown default:
                print("⚠️ Authorization status: Unknown")
                authorizationStatus = .notDetermined
            }
        }
    }

    // MARK: - Data Collection

    func startCollecting() {
        guard authorizationStatus == .authorized else {
            print("⚠️ Cannot start collecting: not authorized")
            return
        }

        isCollecting = true

        // Start real-time heart rate monitoring
        startHeartRateQuery()

        // Start observer queries for HRV, SpO2, respiratory rate
        startObserverQueries()

        // Start periodic collection timer
        startCollectionTimer()

        print("✅ Started collecting health data")
    }

    func stopCollecting() {
        isCollecting = false

        // Stop heart rate query
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }

        // Stop observer queries
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()

        // Stop collection timer
        collectionTimer?.invalidate()
        collectionTimer = nil

        print("⏹️ Stopped collecting health data")
    }

    // MARK: - Heart Rate (Real-time)

    func fetchHeartRateHistory() async {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let now = Date()
        let fourHoursAgo = now.addingTimeInterval(-4 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: fourHoursAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
                if let error = error {
                    print("❌ Error fetching heart rate history: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let history = samples.map { sample in
                    (date: sample.endDate, value: sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
                }
                
                Task { @MainActor in
                    self?.heartRateHistory = history
                    print("📈 Fetched \(history.count) heart rate history points")
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }

    private func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: heartRateAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Heart rate query error: \(error.localizedDescription)")
                    return
                }

                self.heartRateAnchor = anchor

                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    return
                }

                // Get most recent sample
                if let latest = samples.last {
                    let value = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self.currentData.heartRate = value
                    print("❤️ Heart Rate: \(value) bpm")

                    // Sync to Firebase using REST API
                    await FirebaseRESTManager.shared.syncRealtimeMetric(type: "heartRate", value: value, unit: "bpm")
                }
            }
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Heart rate update error: \(error.localizedDescription)")
                    return
                }

                self.heartRateAnchor = anchor

                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    return
                }

                if let latest = samples.last {
                    let value = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self.currentData.heartRate = value
                    print("❤️ Heart Rate: \(value) bpm")

                    // Sync to Firebase using REST API
                    await FirebaseRESTManager.shared.syncRealtimeMetric(type: "heartRate", value: value, unit: "bpm")
                }
            }
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    // MARK: - Observer Queries (Background Delivery)

    private func startObserverQueries() {
        // HRV
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] query, completionHandler, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ HRV observer error: \(error.localizedDescription)")
                        completionHandler()
                        return
                    }

                    await self?.fetchLatestHRV()
                    completionHandler()
                }
            }
            healthStore.execute(query)
            observerQueries.append(query)

            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { success, error in
                if success {
                    print("✅ HRV background delivery enabled")
                } else if let error = error {
                    print("❌ HRV background delivery error: \(error.localizedDescription)")
                }
            }
        }

        // Blood Oxygen
        if let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            let query = HKObserverQuery(sampleType: spo2Type, predicate: nil) { [weak self] query, completionHandler, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ SpO2 observer error: \(error.localizedDescription)")
                        completionHandler()
                        return
                    }

                    await self?.fetchLatestBloodOxygen()
                    completionHandler()
                }
            }
            healthStore.execute(query)
            observerQueries.append(query)

            healthStore.enableBackgroundDelivery(for: spo2Type, frequency: .immediate) { success, error in
                if success {
                    print("✅ SpO2 background delivery enabled")
                } else if let error = error {
                    print("❌ SpO2 background delivery error: \(error.localizedDescription)")
                }
            }
        }

        // Respiratory Rate
        if let respType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            let query = HKObserverQuery(sampleType: respType, predicate: nil) { [weak self] query, completionHandler, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Respiratory rate observer error: \(error.localizedDescription)")
                        completionHandler()
                        return
                    }

                    await self?.fetchLatestRespiratoryRate()
                    completionHandler()
                }
            }
            healthStore.execute(query)
            observerQueries.append(query)

            healthStore.enableBackgroundDelivery(for: respType, frequency: .immediate) { success, error in
                if success {
                    print("✅ Respiratory rate background delivery enabled")
                } else if let error = error {
                    print("❌ Respiratory rate background delivery error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Periodic Collection Timer

    private func startCollectionTimer() {
        // Collect aggregated data every 8 seconds
        collectionTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.collectAggregatedData()
            }
        }
    }

    private func collectAggregatedData() async {
        // Fetch steps, distance, active energy, flights climbed
        await fetchLatestSteps()
        await fetchLatestDistance()
        await fetchLatestActiveEnergy()
        await fetchLatestFlightsClimbed()

        // Sync aggregated data to Firebase
        var packet = HealthDataPacket(timestamp: Date())
        packet.heartRate = currentData.heartRate
        packet.hrv = currentData.hrv
        packet.respiratoryRate = currentData.respiratoryRate
        packet.bloodOxygen = currentData.bloodOxygen
        packet.stepCount = currentData.stepCount
        packet.distance = currentData.distance
        packet.activeEnergy = currentData.activeEnergy
        packet.flightsClimbed = currentData.flightsClimbed

        await FirebaseRESTManager.shared.syncAggregatedData(packet: packet)
    }

    // MARK: - Fetch Latest Data

    private func fetchLatestHRV() async {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ HRV fetch error: \(error.localizedDescription)")
                    return
                }

                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    self.currentData.hrv = value
                    print("💓 HRV: \(value) ms")

                    // Sync to Firebase using REST API
                    await FirebaseRESTManager.shared.syncRealtimeMetric(type: "hrv", value: value, unit: "ms")
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestBloodOxygen() async {
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: spo2Type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ SpO2 fetch error: \(error.localizedDescription)")
                    return
                }

                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.percent()) * 100
                    self.currentData.bloodOxygen = value
                    print("🫁 Blood Oxygen: \(value)%")

                    // Sync to Firebase using REST API
                    await FirebaseRESTManager.shared.syncRealtimeMetric(type: "bloodOxygen", value: value, unit: "%")
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestRespiratoryRate() async {
        guard let respType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: respType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Respiratory rate fetch error: \(error.localizedDescription)")
                    return
                }

                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self.currentData.respiratoryRate = value
                    print("🌬️ Respiratory Rate: \(value) breaths/min")

                    // Sync to Firebase using REST API
                    await FirebaseRESTManager.shared.syncRealtimeMetric(type: "respiratoryRate", value: value, unit: "breaths/min")
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestSteps() async {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] query, statistics, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Steps fetch error: \(error.localizedDescription)")
                    return
                }

                if let sum = statistics?.sumQuantity() {
                    let value = Int(sum.doubleValue(for: HKUnit.count()))
                    self.currentData.stepCount = value
                    print("👣 Steps: \(value)")
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestDistance() async {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] query, statistics, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Distance fetch error: \(error.localizedDescription)")
                    return
                }

                if let sum = statistics?.sumQuantity() {
                    let value = sum.doubleValue(for: HKUnit.meter())
                    self.currentData.distance = value
                    print("🚶 Distance: \(value) meters")
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestActiveEnergy() async {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] query, statistics, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Active energy fetch error: \(error.localizedDescription)")
                    return
                }

                if let sum = statistics?.sumQuantity() {
                    let value = sum.doubleValue(for: HKUnit.kilocalorie())
                    self.currentData.activeEnergy = value
                    print("🔥 Active Energy: \(value) kcal")
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestFlightsClimbed() async {
        guard let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) else {
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: flightsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] query, statistics, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Flights climbed fetch error: \(error.localizedDescription)")
                    return
                }

                if let sum = statistics?.sumQuantity() {
                    let value = Int(sum.doubleValue(for: HKUnit.count()))
                    self.currentData.flightsClimbed = value
                    print("🪜 Flights Climbed: \(value)")
                }
            }
        }

        healthStore.execute(query)
    }
}
