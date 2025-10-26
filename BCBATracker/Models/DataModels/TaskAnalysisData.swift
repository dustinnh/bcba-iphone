//
//  TaskAnalysisData.swift
//  BCBATracker
//
//  Data model for Task Analysis sessions
//

import Foundation

/// Represents a task analysis session data
struct TaskAnalysisData: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var taskName: String  // Name of the skill being taught
    var chainingType: ChainingType
    var steps: [TaskStep]
    var trials: [TaskTrial]
    var notes: String?

    /// Type of chaining method
    enum ChainingType: String, Codable, CaseIterable {
        case forward = "Forward Chaining"
        case backward = "Backward Chaining"
        case totalTask = "Total Task"

        var description: String {
            switch self {
            case .forward:
                return "Teach steps in order, starting from the first step"
            case .backward:
                return "Teach steps in reverse order, starting from the last step"
            case .totalTask:
                return "Teach all steps together in each trial"
            }
        }
    }

    /// Individual task step
    struct TaskStep: Codable, Identifiable {
        let id: UUID
        var stepNumber: Int
        var description: String
        var isActive: Bool  // Whether this step is being taught

        init(
            id: UUID = UUID(),
            stepNumber: Int,
            description: String,
            isActive: Bool = true
        ) {
            self.id = id
            self.stepNumber = stepNumber
            self.description = description
            self.isActive = isActive
        }
    }

    /// Individual trial attempt
    struct TaskTrial: Codable, Identifiable {
        let id: UUID
        let trialNumber: Int
        let timestamp: Date
        var stepResults: [StepResult]
        var promptLevel: PromptLevel
        var notes: String?

        /// Result for each step in the trial
        struct StepResult: Codable, Identifiable {
            let id: UUID
            let stepNumber: Int
            var completed: Bool
            var promptUsed: Bool

            init(
                id: UUID = UUID(),
                stepNumber: Int,
                completed: Bool = false,
                promptUsed: Bool = false
            ) {
                self.id = id
                self.stepNumber = stepNumber
                self.completed = completed
                self.promptUsed = promptUsed
            }
        }

        /// Prompt level for the trial
        enum PromptLevel: String, Codable, CaseIterable {
            case independent = "Independent"
            case minimal = "Minimal"
            case moderate = "Moderate"
            case full = "Full"

            var abbreviation: String {
                switch self {
                case .independent: return "I"
                case .minimal: return "Min"
                case .moderate: return "Mod"
                case .full: return "F"
                }
            }
        }

        init(
            id: UUID = UUID(),
            trialNumber: Int,
            timestamp: Date = Date(),
            stepResults: [StepResult] = [],
            promptLevel: PromptLevel = .independent,
            notes: String? = nil
        ) {
            self.id = id
            self.trialNumber = trialNumber
            self.timestamp = timestamp
            self.stepResults = stepResults
            self.promptLevel = promptLevel
            self.notes = notes
        }
    }

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        taskName: String = "",
        chainingType: ChainingType = .forward,
        steps: [TaskStep] = [],
        trials: [TaskTrial] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.taskName = taskName
        self.chainingType = chainingType
        self.steps = steps
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

    /// Number of steps in the task
    var totalSteps: Int {
        steps.filter { $0.isActive }.count
    }

    /// Number of completed trials (all steps completed)
    var completedTrials: Int {
        trials.filter { trial in
            let activeSteps = steps.filter { $0.isActive }.count
            let completedSteps = trial.stepResults.filter { $0.completed }.count
            return completedSteps == activeSteps && activeSteps > 0
        }.count
    }

    /// Number of independent trials (no prompts used)
    var independentTrials: Int {
        trials.filter { trial in
            trial.promptLevel == .independent &&
            trial.stepResults.allSatisfy { !$0.promptUsed }
        }.count
    }

    /// Percentage of completed trials
    var completionRate: Double {
        guard totalTrials > 0 else { return 0 }
        return (Double(completedTrials) / Double(totalTrials)) * 100
    }

    /// Percentage of independent trials
    var independenceRate: Double {
        guard totalTrials > 0 else { return 0 }
        return (Double(independentTrials) / Double(totalTrials)) * 100
    }

    /// Step-by-step mastery data
    var stepMastery: [Int: Double] {
        var mastery: [Int: Double] = [:]

        for step in steps where step.isActive {
            let stepNumber = step.stepNumber
            let totalAttempts = trials.count
            guard totalAttempts > 0 else { continue }

            let completedCount = trials.filter { trial in
                trial.stepResults.first(where: { $0.stepNumber == stepNumber })?.completed ?? false
            }.count

            mastery[stepNumber] = (Double(completedCount) / Double(totalAttempts)) * 100
        }

        return mastery
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

    /// Format completion rate
    var formattedCompletionRate: String {
        String(format: "%.1f%%", completionRate)
    }

    /// Format independence rate
    var formattedIndependenceRate: String {
        String(format: "%.1f%%", independenceRate)
    }
}
