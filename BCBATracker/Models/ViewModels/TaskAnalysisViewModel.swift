//
//  TaskAnalysisViewModel.swift
//  BCBATracker
//
//  ViewModel for Task Analysis sessions
//

import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class TaskAnalysisViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessionData: TaskAnalysisData
    @Published var isSessionActive: Bool = false
    @Published var currentTrialNumber: Int = 0
    @Published var showingSaveConfirmation: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let dataManager = DataManager.shared

    // MARK: - Session Context
    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil, taskName: String = "") {
        self.student = student
        self.program = program
        self.sessionData = TaskAnalysisData(taskName: taskName)
    }

    // MARK: - Session Management

    /// Start a new task analysis session
    func startSession(taskName: String, chainingType: TaskAnalysisData.ChainingType, steps: [TaskAnalysisData.TaskStep]) {
        sessionData = TaskAnalysisData(
            startTime: Date(),
            taskName: taskName,
            chainingType: chainingType,
            steps: steps
        )
        isSessionActive = true
        currentTrialNumber = 0
        HapticManager.mediumImpact()
    }

    /// End the current session
    func endSession() {
        sessionData.endTime = Date()
        isSessionActive = false
        showingSaveConfirmation = true
        HapticManager.mediumImpact()
    }

    // MARK: - Step Management

    /// Add a new step to the task
    func addStep(description: String) {
        let stepNumber = sessionData.steps.count + 1
        let step = TaskAnalysisData.TaskStep(
            stepNumber: stepNumber,
            description: description
        )
        sessionData.steps.append(step)
        HapticManager.lightImpact()
    }

    /// Update step description
    func updateStep(stepId: UUID, description: String) {
        if let index = sessionData.steps.firstIndex(where: { $0.id == stepId }) {
            sessionData.steps[index].description = description
        }
    }

    /// Delete a step
    func deleteStep(stepId: UUID) {
        sessionData.steps.removeAll(where: { $0.id == stepId })

        // Renumber remaining steps
        for (index, _) in sessionData.steps.enumerated() {
            sessionData.steps[index].stepNumber = index + 1
        }

        HapticManager.softImpact()
    }

    /// Move step up
    func moveStepUp(stepId: UUID) {
        guard let index = sessionData.steps.firstIndex(where: { $0.id == stepId }),
              index > 0 else { return }

        sessionData.steps.swapAt(index, index - 1)

        // Renumber steps
        sessionData.steps[index].stepNumber = index + 1
        sessionData.steps[index - 1].stepNumber = index

        HapticManager.lightImpact()
    }

    /// Move step down
    func moveStepDown(stepId: UUID) {
        guard let index = sessionData.steps.firstIndex(where: { $0.id == stepId }),
              index < sessionData.steps.count - 1 else { return }

        sessionData.steps.swapAt(index, index + 1)

        // Renumber steps
        sessionData.steps[index].stepNumber = index + 1
        sessionData.steps[index + 1].stepNumber = index + 2

        HapticManager.lightImpact()
    }

    // MARK: - Trial Management

    /// Add a new trial with step results
    func addTrial(
        stepResults: [TaskAnalysisData.TaskTrial.StepResult],
        promptLevel: TaskAnalysisData.TaskTrial.PromptLevel,
        notes: String? = nil
    ) {
        guard isSessionActive else { return }

        currentTrialNumber += 1

        let trial = TaskAnalysisData.TaskTrial(
            trialNumber: currentTrialNumber,
            timestamp: Date(),
            stepResults: stepResults,
            promptLevel: promptLevel,
            notes: notes
        )

        sessionData.trials.append(trial)

        // Check if all steps completed
        let allStepsCompleted = stepResults.allSatisfy { $0.completed }
        if allStepsCompleted {
            HapticManager.success()
        } else {
            HapticManager.lightImpact()
        }
    }

    /// Delete the last trial
    func deleteLastTrial() {
        guard !sessionData.trials.isEmpty else { return }

        sessionData.trials.removeLast()
        currentTrialNumber = sessionData.trials.count

        HapticManager.softImpact()
    }

    /// Update task name
    func updateTaskName(_ name: String) {
        sessionData.taskName = name
    }

    /// Update chaining type
    func updateChainingType(_ type: TaskAnalysisData.ChainingType) {
        sessionData.chainingType = type
    }

    // MARK: - Data Persistence

    /// Save session to Core Data
    func saveSession(location: String, notes: String? = nil) async throws {
        guard !sessionData.taskName.isEmpty else {
            throw TaskAnalysisError.noTaskNameSpecified
        }

        guard !sessionData.steps.isEmpty else {
            throw TaskAnalysisError.noStepsAdded
        }

        guard sessionData.totalTrials > 0 else {
            throw TaskAnalysisError.noDataToSave
        }

        let context = dataManager.viewContext

        // Create Session entity
        let session = Session(context: context)
        session.id = UUID()
        session.startTime = sessionData.startTime
        session.endTime = sessionData.endTime ?? Date()
        session.type = "taskAnalysis"
        session.location = location
        session.notes = notes ?? sessionData.notes
        session.student = student
        session.program = program

        // Encode task analysis data as JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        session.data = try encoder.encode(sessionData)

        // Save context
        dataManager.save()

        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name(Constants.Notifications.sessionEnded),
            object: nil,
            userInfo: ["sessionId": session.id]
        )

        HapticManager.success()
    }

    /// Discard current session without saving
    func discardSession() {
        sessionData = TaskAnalysisData(
            taskName: sessionData.taskName,
            chainingType: sessionData.chainingType,
            steps: sessionData.steps
        )
        isSessionActive = false
        currentTrialNumber = 0
        HapticManager.rigidImpact()
    }

    // MARK: - Validation

    /// Check if session has unsaved data
    var hasUnsavedData: Bool {
        isSessionActive && sessionData.totalTrials > 0
    }

    /// Check if task is configured
    var isTaskConfigured: Bool {
        !sessionData.taskName.isEmpty && !sessionData.steps.isEmpty
    }

    /// Get mastery percentage for a specific step
    func stepMasteryPercentage(for stepNumber: Int) -> Double {
        sessionData.stepMastery[stepNumber] ?? 0
    }
}

// MARK: - Errors

enum TaskAnalysisError: LocalizedError {
    case noDataToSave
    case noTaskNameSpecified
    case noStepsAdded

    var errorDescription: String? {
        switch self {
        case .noDataToSave:
            return "No trials recorded. Complete at least one trial before saving."
        case .noTaskNameSpecified:
            return "Please specify a task name before starting the session."
        case .noStepsAdded:
            return "Please add at least one step to the task before starting."
        }
    }
}
