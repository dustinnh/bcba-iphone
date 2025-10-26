//
//  FrequencyData.swift
//  BCBATracker
//
//  Data model for frequency recording sessions
//

import Foundation

/// Represents a frequency recording session data
struct FrequencyData: Codable, Identifiable {
    let id: UUID
    var count: Int
    var startTime: Date
    var endTime: Date?
    var behaviors: [BehaviorEvent]
    var notes: String?

    /// Individual behavior event with timestamp
    struct BehaviorEvent: Codable, Identifiable {
        let id: UUID
        let timestamp: Date

        init(timestamp: Date = Date()) {
            self.id = UUID()
            self.timestamp = timestamp
        }
    }

    init(
        id: UUID = UUID(),
        count: Int = 0,
        startTime: Date = Date(),
        endTime: Date? = nil,
        behaviors: [BehaviorEvent] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.count = count
        self.startTime = startTime
        self.endTime = endTime
        self.behaviors = behaviors
        self.notes = notes
    }

    /// Calculate session duration in seconds
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Calculate behavior rate (behaviors per minute)
    var rate: Double {
        let minutes = duration / 60.0
        guard minutes > 0 else { return 0 }
        return Double(count) / minutes
    }

    /// Format rate for display
    var formattedRate: String {
        String(format: "%.1f/min", rate)
    }

    /// Format duration for display
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}
