//
//  ContentView.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = PhoneSessionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if sessionManager.isWorkoutActive {
                VStack(spacing: 12) {
                    Text("Current Metrics")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(Int(sessionManager.heartRate))")
                                .font(.system(size: 40, weight: .bold))
                            Text("BPM")
                                .font(.subheadline)
                        }
                        
                        VStack {
                            Text(String(format: "%.2f", sessionManager.distance))
                                .font(.system(size: 40, weight: .bold))
                            Text("Meters")
                                .font(.subheadline)
                        }
                    }
                    
                    if let lastUpdate = sessionManager.lastUpdateTime {
                        Text("Last update: \(lastUpdate, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 50))
                    Text("Start your workout on Apple Watch")
                        .font(.headline)
                    Text("Metrics will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}
