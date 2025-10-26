//
//  DurationData.swift
//  BCBATracker
//
//  Data model for duration recording sessions
//

import Foundation

/// Represents a duration recording session data
struct DurationData: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var behaviors: [BehaviorDuration]
    var notes: String?

    /// Individual behavior duration instance
    struct BehaviorDuration: Codable, Identifiable {
        let id: UUID
        let startTime: Date
        var endTime: Date?
        var isActive: Bool

        init(startTime: Date = Date()) {
            self.id = UUID()
            self.startTime = startTime
            self.endTime = nil
            self.isActive = true
        }

        /// Duration in seconds
        var duration: TimeInterval {
            let end = endTime ?? Date()
            return end.timeIntervalSince(startTime)
        }

        /// Format duration as MM:SS
        var formattedDuration: String {
            let totalSeconds = Int(duration)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        behaviors: [BehaviorDuration] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.behaviors = behaviors
        self.notes = notes
    }

    /// Total session duration in seconds
    var sessionDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Total duration of all behaviors in seconds
    var totalBehaviorDuration: TimeInterval {
        behaviors.reduce(0) { $0 + $1.duration }
    }

    /// Average duration per behavior occurrence
    var averageDuration: TimeInterval {
        guard !behaviors.isEmpty else { return 0 }
        return totalBehaviorDuration / Double(behaviors.count)
    }

    /// Percentage of session time spent in behavior
    var percentageOfSession: Double {
        guard sessionDuration > 0 else { return 0 }
        return (totalBehaviorDuration / sessionDuration) * 100
    }

    /// Number of behavior occurrences
    var count: Int {
        behaviors.count
    }

    /// Format total duration as HH:MM:SS
    var formattedTotalDuration: String {
        let totalSeconds = Int(totalBehaviorDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format average duration as MM:SS
    var formattedAverageDuration: String {
        let totalSeconds = Int(averageDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format session duration as HH:MM:SS
    var formattedSessionDuration: String {
        let totalSeconds = Int(sessionDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format percentage
    var formattedPercentage: String {
        String(format: "%.1f%%", percentageOfSession)
    }
}
