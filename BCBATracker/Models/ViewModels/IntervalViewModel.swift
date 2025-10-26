//
//  IntervalViewModel.swift
//  BCBATracker
//
//  ViewModel for interval recording sessions
//

import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class IntervalViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessionData: IntervalData
    @Published var isSessionActive: Bool = false
    @Published var currentIntervalNumber: Int = 0
    @Published var isIntervalRunning: Bool = false
    @Published var currentIntervalElapsed: TimeInterval = 0
    @Published var showingSaveConfirmation: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let dataManager = DataManager.shared
    private var timer: Timer?
    private var intervalStartTime: Date?

    // MARK: - Session Context
    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil, intervalDuration: TimeInterval = 10, intervalType: IntervalData.IntervalType = .partial) {
        self.student = student
        self.program = program
        self.sessionData = IntervalData(intervalDuration: intervalDuration, intervalType: intervalType)
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Session Management

    /// Start a new interval recording session
    func startSession() {
        sessionData = IntervalData(
            startTime: Date(),
            intervalDuration: sessionData.intervalDuration,
            intervalType: sessionData.intervalType
        )
        isSessionActive = true
        currentIntervalNumber = 0
        startNextInterval()
        HapticManager.mediumImpact()
    }

    /// End the current session
    func endSession() {
        stopTimer()
        sessionData.endTime = Date()
        isSessionActive = false
        isIntervalRunning = false
        showingSaveConfirmation = true
        HapticManager.mediumImpact()
    }

    // MARK: - Interval Management

    /// Start the next interval
    private func startNextInterval() {
        guard isSessionActive else { return }

        currentIntervalNumber += 1
        intervalStartTime = Date()
        currentIntervalElapsed = 0
        isIntervalRunning = true

        let interval = IntervalData.IntervalObservation(
            intervalNumber: currentIntervalNumber,
            startTime: Date()
        )
        sessionData.intervals.append(interval)

        startTimer()
        HapticManager.lightImpact()
    }

    /// Mark behavior as occurred in current interval
    func markBehaviorOccurred() {
        guard isIntervalRunning else { return }
        guard !sessionData.intervals.isEmpty else { return }

        let lastIndex = sessionData.intervals.count - 1
        sessionData.intervals[lastIndex].behaviorOccurred = true
        HapticManager.mediumImpact()
    }

    /// Mark behavior as not occurred in current interval
    func markBehaviorNotOccurred() {
        guard isIntervalRunning else { return }
        guard !sessionData.intervals.isEmpty else { return }

        let lastIndex = sessionData.intervals.count - 1
        sessionData.intervals[lastIndex].behaviorOccurred = false
        HapticManager.lightImpact()
    }

    /// Complete current interval and start next
    func completeInterval() {
        guard isIntervalRunning else { return }
        guard !sessionData.intervals.isEmpty else { return }

        let lastIndex = sessionData.intervals.count - 1
        sessionData.intervals[lastIndex].endTime = Date()

        stopTimer()
        isIntervalRunning = false

        // Auto-start next interval after brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isSessionActive {
                self.startNextInterval()
            }
        }
    }

    /// Delete the last interval
    func deleteLastInterval() {
        guard !sessionData.intervals.isEmpty else { return }

        if isIntervalRunning && sessionData.intervals.count == 1 {
            // Can't delete the currently running interval if it's the only one
            return
        }

        if isIntervalRunning {
            // Delete the previous interval
            sessionData.intervals.remove(at: sessionData.intervals.count - 2)
            currentIntervalNumber -= 1
        } else {
            sessionData.intervals.removeLast()
            currentIntervalNumber -= 1
        }

        HapticManager.softImpact()
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let startTime = self.intervalStartTime {
                    self.currentIntervalElapsed = Date().timeIntervalSince(startTime)

                    // Auto-complete interval when duration reached
                    if self.currentIntervalElapsed >= self.sessionData.intervalDuration {
                        self.completeInterval()
                    }
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
        guard sessionData.totalIntervals > 0 else {
            throw IntervalError.noDataToSave
        }

        let context = dataManager.viewContext

        // Create Session entity
        let session = Session(context: context)
        session.id = UUID()
        session.startTime = sessionData.startTime
        session.endTime = sessionData.endTime ?? Date()
        session.type = "interval"
        session.location = location
        session.notes = notes ?? sessionData.notes
        session.student = student
        session.program = program

        // Encode interval data as JSON
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
        sessionData = IntervalData(
            intervalDuration: sessionData.intervalDuration,
            intervalType: sessionData.intervalType
        )
        isSessionActive = false
        isIntervalRunning = false
        currentIntervalNumber = 0
        currentIntervalElapsed = 0
        HapticManager.rigidImpact()
    }

    // MARK: - Validation

    /// Check if session has unsaved data
    var hasUnsavedData: Bool {
        isSessionActive && sessionData.totalIntervals > 0
    }

    /// Format current interval elapsed time
    var formattedCurrentElapsed: String {
        let totalSeconds = Int(currentIntervalElapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format time remaining in current interval
    var formattedTimeRemaining: String {
        let remaining = max(0, sessionData.intervalDuration - currentIntervalElapsed)
        let totalSeconds = Int(remaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Progress of current interval (0.0 to 1.0)
    var intervalProgress: Double {
        guard sessionData.intervalDuration > 0 else { return 0 }
        return min(1.0, currentIntervalElapsed / sessionData.intervalDuration)
    }
}

// MARK: - Errors

enum IntervalError: LocalizedError {
    case noDataToSave

    var errorDescription: String? {
        switch self {
        case .noDataToSave:
            return "No intervals recorded. Complete at least one interval before saving."
        }
    }
}
