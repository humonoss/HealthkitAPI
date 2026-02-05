//
//  MetricCard.swift
//  HealthkitAPI Watch App
//
//  Created by Gemini on 2026-02-04.
//

import SwiftUI

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .bold))
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
            }
            
            content
        }
        .padding(10)
        // Standard "Platter" color for watchOS
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(16)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MetricCard(title: "Heart Rate", icon: "heart.fill", color: .red) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("72")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                Text("BPM")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 160)
    }
}