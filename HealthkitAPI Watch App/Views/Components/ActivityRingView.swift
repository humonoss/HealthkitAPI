//
//  ActivityRingView.swift
//  HealthkitAPI Watch App
//
//  Created by Gemini on 2026-02-04.
//

import SwiftUI

struct ActivityRingView: View {
    var progress: Double
    var color: Color
    var thickness: CGFloat = 12
    
    // Apple Watch "Platter" dark gray approx
    var backgroundColor: Color = Color.white.opacity(0.15)
    
    var body: some View {
        ZStack {
            // Background Ring
            Circle()
                .stroke(color.opacity(0.2), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            
            // Progress Ring
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.8)]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                // Add a subtle shadow to the tip for depth (simulated)
                .shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 0)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ActivityRingView(progress: 0.75, color: .green)
            .frame(width: 80, height: 80)
    }
}