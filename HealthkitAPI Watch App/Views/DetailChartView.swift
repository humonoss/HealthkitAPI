//
//  DetailChartView.swift
//  HealthkitAPI Watch App
//
//  Created by Gemini on 2026-02-04.
//

import SwiftUI
import Charts

struct DetailChartView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let data: [(date: Date, value: Double)]
    
    // Compute stats
    var minVal: Double? { data.map { $0.value }.min() }
    var maxVal: Double? { data.map { $0.value }.max() }
    var avgVal: Double? {
        guard !data.isEmpty else { return nil }
        return data.map { $0.value }.reduce(0, +) / Double(data.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(unit.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Chart
                if !data.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Chart {
                            ForEach(data, id: \.date) { item in
                                LineMark(
                                    x: .value("Time", item.date),
                                    y: .value("Value", item.value)
                                )
                                .foregroundStyle(color.gradient)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Time", item.date),
                                    y: .value("Value", item.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [color.opacity(0.3), color.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                            
                            // Optional: Add average rule mark
                            if let avg = avgVal {
                                RuleMark(y: .value("Average", avg))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                        }
                        .frame(height: 120)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) {
                                AxisValueLabel(format: .dateTime.hour())
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    Text("No chart data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                }
                
                // Stats Grid
                if let min = minVal, let max = maxVal, let avg = avgVal {
                    VStack(spacing: 12) {
                        Text("Highlights")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 8) {
                            StatBox(label: "Min", value: String(format: "%.0f", min), unit: unit)
                            StatBox(label: "Avg", value: String(format: "%.0f", avg), unit: unit)
                            StatBox(label: "Max", value: String(format: "%.0f", max), unit: unit)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
            
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(white: 0.15))
        .cornerRadius(8)
    }
}

#Preview {
    DetailChartView(
        title: "Heart Rate",
        value: "72",
        unit: "BPM",
        color: .red,
        data: [
            (Date().addingTimeInterval(-3600*3), 65),
            (Date().addingTimeInterval(-3600*2), 72),
            (Date().addingTimeInterval(-3600*1), 85),
            (Date(), 70)
        ]
    )
}
