//
//  DurationViewModel.swift
//  BCBATracker
//
//  ViewModel for duration recording sessions
//

import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class DurationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessionData: DurationData
    @Published var isSessionActive: Bool = false
    @Published var isTimerRunning: Bool = false
    @Published var currentDuration: TimeInterval = 0
    @Published var showingSaveConfirmation: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let dataManager = DataManager.shared
    private var timer: Timer?

    // MARK: - Session Context
    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self.sessionData = DurationData()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Session Management

    /// Start a new duration recording session
    func startSession() {
        sessionData = DurationData(startTime: Date())
        isSessionActive = true
        HapticManager.mediumImpact()
    }

    /// End the current session
    func endSession() {
        if isTimerRunning {
            stopBehavior()
        }
        sessionData.endTime = Date()
        isSessionActive = false
        showingSaveConfirmation = true
        HapticManager.mediumImpact()
    }

    // MARK: - Behavior Timing

    /// Start timing a behavior occurrence
    func startBehavior() {
        guard isSessionActive else { return }
        guard !isTimerRunning else { return }

        let behavior = DurationData.BehaviorDuration(startTime: Date())
        sessionData.behaviors.append(behavior)
        isTimerRunning = true
        currentDuration = 0

        startTimer()
        HapticManager.mediumImpact()
    }

    /// Stop timing the current behavior
    func stopBehavior() {
        guard isTimerRunning else { return }
        guard !sessionData.behaviors.isEmpty else { return }

        // Update the last behavior's end time
        var lastBehavior = sessionData.behaviors[sessionData.behaviors.count - 1]
        lastBehavior.endTime = Date()
        lastBehavior.isActive = false
        sessionData.behaviors[sessionData.behaviors.count - 1] = lastBehavior

        isTimerRunning = false
        currentDuration = 0
        stopTimer()

        HapticManager.lightImpact()
    }

    /// Delete a specific behavior occurrence
    func deleteBehavior(at index: Int) {
        guard index >= 0 && index < sessionData.behaviors.count else { return }

        // If deleting the active behavior, stop the timer
        if sessionData.behaviors[index].isActive {
            stopTimer()
            isTimerRunning = false
            currentDuration = 0
        }

        sessionData.behaviors.remove(at: index)
        HapticManager.softImpact()
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let lastBehavior = self.sessionData.behaviors.last, lastBehavior.isActive {
                    self.currentDuration = Date().timeIntervalSince(lastBehavior.startTime)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Data Persistence

    /// Save session to Core Data
    func saveSession(location: String, notes: String? = nil) async throws {
        guard sessionData.count > 0 else {
            throw DurationError.noDataToSave
        }

        let context = dataManager.viewContext

        // Create Session entity
        let session = Session(context: context)
        session.id = UUID()
        session.startTime = sessionData.startTime
        session.endTime = sessionData.endTime ?? Date()
        session.type = "duration"
        session.location = location
        session.notes = notes ?? sessionData.notes
        session.student = student
        session.program = program

        // Encode duration data as JSON
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
        stopTimer()
        sessionData = DurationData()
        isSessionActive = false
        isTimerRunning = false
        currentDuration = 0
        HapticManager.rigidImpact()
    }

    // MARK: - Validation

    /// Check if session has unsaved data
    var hasUnsavedData: Bool {
        isSessionActive && sessionData.count > 0
    }

    /// Format current timer duration
    var formattedCurrentDuration: String {
        let totalSeconds = Int(currentDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Errors

enum DurationError: LocalizedError {
    case noDataToSave

    var errorDescription: String? {
        switch self {
        case .noDataToSave:
            return "No behavior durations recorded. Record at least one behavior before saving."
        }
    }
}
