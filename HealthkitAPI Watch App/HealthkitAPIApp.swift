//
//  HealthkitAPIApp.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import SwiftUI
import FirebaseCore

@main
struct HealthkitAPI_Watch_AppApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var firebaseManager = FirebaseRESTManager.shared

    init() {
        FirebaseApp.configure()
        print("🚀 Firebase configured")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(firebaseManager)
                .task {
                    // Auto-start sync on app launch
                    await initializeApp()
                }
        }
    }

    private func initializeApp() async {
        // Authenticate with Firebase
        do {
            try await firebaseManager.authenticateAnonymously()
        } catch {
            print("❌ Firebase auth failed: \(error.localizedDescription)")
        }

        // Request HealthKit authorization if needed
        if healthKitManager.authorizationStatus == .notDetermined {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                print("❌ HealthKit auth failed: \(error.localizedDescription)")
            }
        }

        // Start collecting if authorized
        if healthKitManager.authorizationStatus == .authorized {
            healthKitManager.startCollecting()
        }
    }
}
