//
//  ABCData.swift
//  BCBATracker
//
//  Data model for ABC (Antecedent-Behavior-Consequence) recording
//

import Foundation

/// Represents an ABC recording session data
struct ABCData: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var observations: [ABCObservation]
    var notes: String?

    /// Individual ABC observation
    struct ABCObservation: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        var antecedent: String
        var behavior: String
        var consequence: String
        var setting: String?
        var duration: TimeInterval?
        var intensity: Intensity?

        /// Behavior intensity level
        enum Intensity: String, Codable, CaseIterable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case severe = "Severe"

            var color: String {
                switch self {
                case .low: return "green"
                case .medium: return "yellow"
                case .high: return "orange"
                case .severe: return "red"
                }
            }
        }

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            antecedent: String = "",
            behavior: String = "",
            consequence: String = "",
            setting: String? = nil,
            duration: TimeInterval? = nil,
            intensity: Intensity? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.antecedent = antecedent
            self.behavior = behavior
            self.consequence = consequence
            self.setting = setting
            self.duration = duration
            self.intensity = intensity
        }

        var formattedDuration: String? {
            guard let duration = duration else { return nil }
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
        observations: [ABCObservation] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.observations = observations
        self.notes = notes
    }

    /// Total session duration in seconds
    var sessionDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Number of observations
    var count: Int {
        observations.count
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

    /// Most common antecedent patterns
    var commonAntecedents: [String: Int] {
        var counts: [String: Int] = [:]
        for observation in observations where !observation.antecedent.isEmpty {
            counts[observation.antecedent, default: 0] += 1
        }
        return counts
    }

    /// Most common consequence patterns
    var commonConsequences: [String: Int] {
        var counts: [String: Int] = [:]
        for observation in observations where !observation.consequence.isEmpty {
            counts[observation.consequence, default: 0] += 1
        }
        return counts
    }

    /// Intensity distribution
    var intensityDistribution: [ABCObservation.Intensity: Int] {
        var distribution: [ABCObservation.Intensity: Int] = [:]
        for observation in observations {
            if let intensity = observation.intensity {
                distribution[intensity, default: 0] += 1
            }
        }
        return distribution
    }
}
