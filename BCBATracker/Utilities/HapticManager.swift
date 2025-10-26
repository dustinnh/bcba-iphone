//
//  HapticManager.swift
//  BCBATracker
//
//  Haptic feedback management for user interactions
//  Provides tactile confirmation for data entry
//

import UIKit
import SwiftUI

/// Manager for haptic feedback throughout the app
/// Confirms user interactions without requiring visual attention
enum HapticManager {

    // MARK: - Check if Haptics are Enabled

    /// Check if haptics are enabled in user preferences
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.enableHaptics)
    }

    // MARK: - Impact Feedback

    /// Trigger impact haptic feedback
    /// - Parameter style: The style of impact (light, medium, heavy, soft, rigid)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Light impact - for secondary actions
    static func lightImpact() {
        impact(.light)
    }

    /// Medium impact - for primary actions (default)
    static func mediumImpact() {
        impact(.medium)
    }

    /// Heavy impact - for important actions
    static func heavyImpact() {
        impact(.heavy)
    }

    /// Soft impact - for gentle confirmations
    static func softImpact() {
        if #available(iOS 13.0, *) {
            impact(.soft)
        } else {
            impact(.light)
        }
    }

    /// Rigid impact - for firm confirmations
    static func rigidImpact() {
        if #available(iOS 13.0, *) {
            impact(.rigid)
        } else {
            impact(.heavy)
        }
    }

    // MARK: - Notification Feedback

    /// Trigger notification haptic feedback
    /// - Parameter type: The type of notification (success, warning, error)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Success notification - for successful operations
    static func success() {
        notification(.success)
    }

    /// Warning notification - for warnings
    static func warning() {
        notification(.warning)
    }

    /// Error notification - for errors
    static func error() {
        notification(.error)
    }

    // MARK: - Selection Feedback

    /// Trigger selection haptic feedback
    /// Used for picker selection, segmented control, etc.
    static func selection() {
        guard isEnabled else { return }

        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Context-Specific Haptics

    /// Haptic for recording a behavior occurrence
    static func behaviorRecorded() {
        mediumImpact()
    }

    /// Haptic for starting a session
    static func sessionStarted() {
        heavyImpact()
    }

    /// Haptic for ending a session
    static func sessionEnded() {
        rigidImpact()
    }

    /// Haptic for undoing an action
    static func undoAction() {
        lightImpact()
    }

    /// Haptic for saving data
    static func dataSaved() {
        success()
    }

    /// Haptic for deleting data
    static func dataDeleted() {
        warning()
    }

    /// Haptic for button press
    static func buttonPress() {
        lightImpact()
    }

    /// Haptic for toggle switch
    static func toggleSwitch() {
        selection()
    }

    /// Haptic for sync completion
    static func syncCompleted() {
        success()
    }

    /// Haptic for error
    static func errorOccurred() {
        error()
    }

    // MARK: - Enable/Disable

    /// Enable haptic feedback
    static func enable() {
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.enableHaptics)
    }

    /// Disable haptic feedback
    static func disable() {
        UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKeys.enableHaptics)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Add haptic feedback to a button press
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.impact(style)
            }
        )
    }

    /// Add success haptic feedback
    func successHaptic() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.success()
            }
        )
    }

    /// Add selection haptic feedback
    func selectionHaptic() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.selection()
            }
        )
    }
}
