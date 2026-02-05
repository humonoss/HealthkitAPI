//
//  SyncStatusView.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject var firebaseManager: FirebaseRESTManager
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        List {
            // Hero Status Section
            Section {
                VStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundColor(statusColor)
                    
                    Text(firebaseManager.syncStatus.status.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let error = firebaseManager.syncStatus.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // Statistics Section
            Section {
                HStack {
                    Label("Pending", systemImage: "tray.and.arrow.up")
                    Spacer()
                    Text("\(firebaseManager.syncStatus.pendingItems)")
                        .fontWeight(.bold)
                }
                
                HStack {
                    Label("Last Sync", systemImage: "clock")
                    Spacer()
                    if let lastSync = firebaseManager.syncStatus.lastSyncTime {
                        Text(timeString(from: lastSync))
                            .fontWeight(.bold)
                    } else {
                        Text("--:--")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("STATISTICS")
            }

            // Sync Button Section
            Section {
                Button(action: {
                    Task { await firebaseManager.manualSync() }
                }) {
                    HStack {
                        Spacer()
                        if firebaseManager.syncStatus.status == .active {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text("Syncing...")
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                        }
                        Spacer()
                    }
                }
                .fontWeight(.bold)
                .listRowBackground(firebaseManager.isConnected ? Color.green.opacity(0.8) : Color.gray.opacity(0.3))
                .foregroundColor(firebaseManager.isConnected ? .black : .white)
                .disabled(!firebaseManager.isConnected || firebaseManager.syncStatus.status == .active)
            }

            // Active Streams Section
            if !firebaseManager.syncStatus.dataTypesSynced.isEmpty {
                Section {
                    ForEach(Array(firebaseManager.syncStatus.dataTypesSynced).sorted(), id: \.self) { type in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(type)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("ACTIVE STREAMS")
                }
            }
            
            // Footer Info
            Section {
                HStack {
                    Text("HealthKit")
                    Spacer()
                    Text(healthKitManager.authorizationStatus.displayName)
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }
            } header: {
                Text("SYSTEM")
            }
        }
        .navigationTitle("Sync")
    }
    
    // Status Logic
    private var statusColor: Color {
        switch firebaseManager.syncStatus.status {
        case .active: return .green
        case .paused: return .yellow
        case .error: return .red
        case .offline: return .gray
        }
    }
    
    private var statusIcon: String {
        switch firebaseManager.syncStatus.status {
        case .active: return "arrow.triangle.2.circlepath.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .offline: return "wifi.slash"
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SyncStatusView()
        .environmentObject(FirebaseRESTManager.shared)
        .environmentObject(HealthKitManager.shared)
}
