//
//  SettingsView.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var firebaseManager: FirebaseRESTManager

    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            // HealthKit Section
            Section {
                Button(action: {
                    guard healthKitManager.authorizationStatus != .authorized else { return }
                    
                    Task {
                        isAuthenticating = true
                        do {
                            try await healthKitManager.requestAuthorization()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                        isAuthenticating = false
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        VStack(alignment: .leading) {
                            Text("HealthKit Access")
                                .font(.headline)
                            Text(healthKitManager.authorizationStatus == .authorized ? "Authorized" : "Tap to Request")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isAuthenticating {
                            ProgressView()
                        } else if healthKitManager.authorizationStatus == .authorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .disabled(healthKitManager.authorizationStatus == .authorized || isAuthenticating)
            } header: {
                Text("PERMISSIONS")
            }

            // Firebase Section
            Section {
                Button(action: {
                    Task {
                        do {
                            try await firebaseManager.authenticateAnonymously()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text("Sign In Anonymously")
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(firebaseManager.isConnected ? "Online" : "Offline")
                        .foregroundColor(firebaseManager.isConnected ? .green : .secondary)
                }
            } header: {
                Text("ACCOUNT")
            }

            // Data Collection Section
            Section {
                if healthKitManager.isCollecting {
                    Button(role: .destructive, action: {
                        healthKitManager.stopCollecting()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Collecting")
                        }
                    }
                } else {
                    Button(action: {
                        healthKitManager.startCollecting()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                            Text("Start Collecting")
                        }
                    }
                    .disabled(healthKitManager.authorizationStatus != .authorized)
                }
            } header: {
                Text("CONTROLS")
            }

            // Sync Queue Section
            Section {
                Button(role: .destructive, action: {
                    SyncQueueManager.shared.clearQueue()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Queue")
                    }
                }
            } header: {
                Text("DEBUG")
            } footer: {
                Text("\(firebaseManager.syncStatus.pendingItems) items pending upload")
            }
        }
        .navigationTitle("Settings")
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(FirebaseRESTManager.shared)
}