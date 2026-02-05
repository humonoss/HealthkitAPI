//
//  HealthMetricsView.swift
//  HealthkitAPI Watch App
//
//  Created by JASKIRAT SINGH on 2026-02-02.
//

import SwiftUI

struct HealthMetricsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var firebaseManager: FirebaseRESTManager

    // 2-column grid with standardized spacing
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Summary")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Subtle Status Indicator
                        HStack(spacing: 6) {
                            if healthKitManager.isCollecting {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                            }
                            if firebaseManager.isConnected {
                                Image(systemName: "icloud.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                    // Activity Rings Section
                    HStack(spacing: 12) {
                        // Steps Ring Group
                        VStack(spacing: 8) {
                            ZStack {
                                ActivityRingView(
                                    progress: Double(healthKitManager.currentData.stepCount ?? 0) / 10000.0,
                                    color: .green
                                )
                                .frame(width: 55, height: 55)
                                
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(spacing: 0) {
                                Text("\(healthKitManager.currentData.stepCount ?? 0)")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                Text("STEPS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(16)

                        // Energy Ring Group
                        VStack(spacing: 8) {
                            ZStack {
                                ActivityRingView(
                                    progress: (healthKitManager.currentData.activeEnergy ?? 0) / 600.0,
                                    color: .pink
                                )
                                .frame(width: 55, height: 55)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.pink)
                            }
                            
                            VStack(spacing: 0) {
                                Text(String(format: "%.0f", healthKitManager.currentData.activeEnergy ?? 0))
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                Text("KCAL")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(16)
                    }

                    // Vitals Grid
                    LazyVGrid(columns: columns, spacing: 8) {
                        // Heart Rate
                        NavigationLink(destination: DetailChartView(
                            title: "Heart Rate",
                            value: healthKitManager.currentData.heartRate.map { String(format: "%.0f", $0) } ?? "--",
                            unit: "BPM",
                            color: .red,
                            data: healthKitManager.heartRateHistory
                        )) {
                            MetricCard(title: "Heart", icon: "heart.fill", color: .red) {
                                HStack(alignment: .lastTextBaseline, spacing: 1) {
                                    Text(healthKitManager.currentData.heartRate.map { String(format: "%.0f", $0) } ?? "--")
                                        .font(.system(.title2, design: .rounded).weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("BPM")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // HRV
                        NavigationLink(destination: DetailChartView(
                            title: "HRV",
                            value: healthKitManager.currentData.hrv.map { String(format: "%.0f", $0) } ?? "--",
                            unit: "MS",
                            color: .purple,
                            data: [] // Placeholder
                        )) {
                            MetricCard(title: "HRV", icon: "waveform.path.ecg", color: .purple) {
                                HStack(alignment: .lastTextBaseline, spacing: 1) {
                                    Text(healthKitManager.currentData.hrv.map { String(format: "%.0f", $0) } ?? "--")
                                        .font(.system(.title2, design: .rounded).weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("MS")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // Oxygen
                        NavigationLink(destination: DetailChartView(
                            title: "Blood Oxygen",
                            value: healthKitManager.currentData.bloodOxygen.map { String(format: "%.0f", $0) } ?? "--",
                            unit: "%",
                            color: .blue,
                            data: [] // Placeholder
                        )) {
                            MetricCard(title: "Blood O₂", icon: "lungs.fill", color: .blue) {
                                HStack(alignment: .lastTextBaseline, spacing: 1) {
                                    Text(healthKitManager.currentData.bloodOxygen.map { String(format: "%.0f", $0) } ?? "--")
                                        .font(.system(.title2, design: .rounded).weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("%")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Resp Rate
                        NavigationLink(destination: DetailChartView(
                            title: "Respiratory Rate",
                            value: healthKitManager.currentData.respiratoryRate.map { String(format: "%.0f", $0) } ?? "--",
                            unit: "RPM",
                            color: .cyan,
                            data: [] // Placeholder
                        )) {
                            MetricCard(title: "Resp", icon: "wind", color: .cyan) {
                                 HStack(alignment: .lastTextBaseline, spacing: 1) {
                                    Text(healthKitManager.currentData.respiratoryRate.map { String(format: "%.0f", $0) } ?? "--")
                                        .font(.system(.title2, design: .rounded).weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("RPM")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Other Metrics (List style within ScrollView)
                    VStack(spacing: 8) {
                        if let distance = healthKitManager.currentData.distance {
                            HStack {
                                Image(systemName: "figure.walk.motion")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text("Walking Distance")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                Spacer()
                                Text(String(format: "%.2f km", distance / 1000))
                                    .font(.system(.callout, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                        }
                        
                        if let flights = healthKitManager.currentData.flightsClimbed {
                            HStack {
                                Image(systemName: "figure.stairs")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                                Text("Flights Climbed")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                Spacer()
                                Text("\(flights)")
                                    .font(.system(.callout, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .onAppear {
                Task {
                    await healthKitManager.fetchHeartRateHistory()
                }
            }
        }
    }
}

#Preview {
    HealthMetricsView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(FirebaseRESTManager.shared)
}