//
//  IntervalData.swift
//  BCBATracker
//
//  Data model for interval recording sessions
//

import Foundation

/// Represents an interval recording session data
struct IntervalData: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var intervalDuration: TimeInterval  // Duration of each interval in seconds
    var intervalType: IntervalType
    var intervals: [IntervalObservation]
    var notes: String?

    /// Type of interval recording
    enum IntervalType: String, Codable, CaseIterable {
        case partial = "Partial Interval"
        case whole = "Whole Interval"
        case momentary = "Momentary Time Sampling"

        var description: String {
            switch self {
            case .partial:
                return "Mark if behavior occurs at any point during interval"
            case .whole:
                return "Mark only if behavior occurs throughout entire interval"
            case .momentary:
                return "Mark only if behavior is occurring at end of interval"
            }
        }
    }

    /// Individual interval observation
    struct IntervalObservation: Codable, Identifiable {
        let id: UUID
        let intervalNumber: Int
        let startTime: Date
        var endTime: Date?
        var behaviorOccurred: Bool
        var notes: String?

        init(
            id: UUID = UUID(),
            intervalNumber: Int,
            startTime: Date,
            endTime: Date? = nil,
            behaviorOccurred: Bool = false,
            notes: String? = nil
        ) {
            self.id = id
            self.intervalNumber = intervalNumber
            self.startTime = startTime
            self.endTime = endTime
            self.behaviorOccurred = behaviorOccurred
            self.notes = notes
        }
    }

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        intervalDuration: TimeInterval = 10,  // Default 10 seconds
        intervalType: IntervalType = .partial,
        intervals: [IntervalObservation] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.intervalDuration = intervalDuration
        self.intervalType = intervalType
        self.intervals = intervals
        self.notes = notes
    }

    /// Total session duration in seconds
    var sessionDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Total number of intervals
    var totalIntervals: Int {
        intervals.count
    }

    /// Number of intervals where behavior occurred
    var intervalsWithBehavior: Int {
        intervals.filter { $0.behaviorOccurred }.count
    }

    /// Percentage of intervals with behavior
    var percentageOfIntervals: Double {
        guard totalIntervals > 0 else { return 0 }
        return (Double(intervalsWithBehavior) / Double(totalIntervals)) * 100
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

    /// Format interval duration
    var formattedIntervalDuration: String {
        let totalSeconds = Int(intervalDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Format percentage
    var formattedPercentage: String {
        String(format: "%.1f%%", percentageOfIntervals)
    }
}
