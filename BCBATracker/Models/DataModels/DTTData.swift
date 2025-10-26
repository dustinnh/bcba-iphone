//
//  DTTData.swift
//  BCBATracker
//
//  Data model for DTT (Discrete Trial Training) sessions
//

import Foundation

/// Represents a DTT session data
struct DTTData: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var target: String  // The skill being taught
    var trials: [DTTTrial]
    var notes: String?

    /// Individual DTT trial
    struct DTTTrial: Codable, Identifiable {
        let id: UUID
        let trialNumber: Int
        let timestamp: Date
        var response: TrialResponse
        var promptLevel: PromptLevel
        var notes: String?

        /// Trial response types
        enum TrialResponse: String, Codable, CaseIterable {
            case correct = "+"
            case incorrect = "-"
            case noResponse = "NR"
            case approximation = "~"

            var displayName: String {
                switch self {
                case .correct: return "Correct"
                case .incorrect: return "Incorrect"
                case .noResponse: return "No Response"
                case .approximation: return "Approximation"
                }
            }

            var color: String {
                switch self {
                case .correct: return "green"
                case .incorrect: return "red"
                case .noResponse: return "gray"
                case .approximation: return "yellow"
                }
            }
        }

        /// Prompt levels
        enum PromptLevel: String, Codable, CaseIterable {
            case independent = "I"
            case verbal = "V"
            case gestural = "G"
            case model = "M"
            case partial = "PP"
            case full = "FP"

            var displayName: String {
                switch self {
                case .independent: return "Independent"
                case .verbal: return "Verbal"
                case .gestural: return "Gestural"
                case .model: return "Model"
                case .partial: return "Partial Physical"
                case .full: return "Full Physical"
                }
            }
        }

        init(
            id: UUID = UUID(),
            trialNumber: Int,
            timestamp: Date = Date(),
            response: TrialResponse = .noResponse,
            promptLevel: PromptLevel = .independent,
            notes: String? = nil
        ) {
            self.id = id
            self.trialNumber = trialNumber
            self.timestamp = timestamp
            self.response = response
            self.promptLevel = promptLevel
            self.notes = notes
        }
    }

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        target: String = "",
        trials: [DTTTrial] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.target = target
        self.trials = trials
        self.notes = notes
    }

    /// Total session duration in seconds
    var sessionDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Total number of trials
    var totalTrials: Int {
        trials.count
    }

    /// Number of correct responses
    var correctResponses: Int {
        trials.filter { $0.response == .correct }.count
    }

    /// Number of incorrect responses
    var incorrectResponses: Int {
        trials.filter { $0.response == .incorrect }.count
    }

    /// Number of no responses
    var noResponses: Int {
        trials.filter { $0.response == .noResponse }.count
    }

    /// Number of independent trials (no prompt)
    var independentTrials: Int {
        trials.filter { $0.promptLevel == .independent }.count
    }

    /// Accuracy percentage
    var accuracy: Double {
        guard totalTrials > 0 else { return 0 }
        return (Double(correctResponses) / Double(totalTrials)) * 100
    }

    /// Independence percentage (independent correct responses)
    var independence: Double {
        guard totalTrials > 0 else { return 0 }
        let independentCorrect = trials.filter {
            $0.response == .correct && $0.promptLevel == .independent
        }.count
        return (Double(independentCorrect) / Double(totalTrials)) * 100
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

    /// Format accuracy
    var formattedAccuracy: String {
        String(format: "%.1f%%", accuracy)
    }

    /// Format independence
    var formattedIndependence: String {
        String(format: "%.1f%%", independence)
    }

    /// Response distribution for data analysis
    var responseDistribution: [DTTTrial.TrialResponse: Int] {
        var distribution: [DTTTrial.TrialResponse: Int] = [:]
        for trial in trials {
            distribution[trial.response, default: 0] += 1
        }
        return distribution
    }

    /// Prompt distribution for data analysis
    var promptDistribution: [DTTTrial.PromptLevel: Int] {
        var distribution: [DTTTrial.PromptLevel: Int] = [:]
        for trial in trials {
            distribution[trial.promptLevel, default: 0] += 1
        }
        return distribution
    }
}
