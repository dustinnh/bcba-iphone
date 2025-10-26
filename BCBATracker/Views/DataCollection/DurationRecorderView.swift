//
//  DurationRecorderView.swift
//  BCBATracker
//
//  Duration recording interface for behavior data collection
//

import SwiftUI
import CoreData

struct DurationRecorderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: DurationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndSessionAlert = false
    @State private var showingSaveSheet = false
    @State private var sessionLocation = Constants.Defaults.defaultSessionLocation
    @State private var sessionNotes = ""

    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self._viewModel = StateObject(wrappedValue: DurationViewModel(student: student, program: program))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.paddingLarge) {
                // Header with student info
                headerSection

                // Stats summary
                statsSection

                Spacer()

                // Current timer display
                if viewModel.isTimerRunning {
                    currentTimerDisplay
                }

                // Recording controls
                recordingControls

                // Behavior list
                if !viewModel.sessionData.behaviors.isEmpty {
                    behaviorList
                }

                Spacer()

                // Session controls
                sessionControls
            }
            .padding(Constants.UI.paddingLarge)
            .navigationTitle("Duration Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if viewModel.hasUnsavedData {
                            showingEndSessionAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("End Session?", isPresented: $showingEndSessionAlert) {
                Button("Discard", role: .destructive) {
                    viewModel.discardSession()
                    dismiss()
                }
                Button("Save") {
                    showingSaveSheet = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved data. Would you like to save or discard this session?")
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveSessionSheet
            }
            .onAppear {
                if !viewModel.isSessionActive {
                    viewModel.startSession()
                }
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: Constants.UI.paddingSmall) {
            Text("\(student.firstName ?? "") \(student.lastInitial ?? "")")
                .font(.title2)
                .fontWeight(.bold)

            if let program = program {
                Text(program.name ?? "Unknown Program")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(viewModel.sessionData.formattedSessionDuration)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var statsSection: some View {
        HStack(spacing: Constants.UI.paddingMedium) {
            StatCard(title: "Total", value: viewModel.sessionData.formattedTotalDuration, color: Constants.Colors.primary)
            StatCard(title: "Count", value: "\(viewModel.sessionData.count)", color: Constants.Colors.accent)
            StatCard(title: "Avg", value: viewModel.sessionData.formattedAverageDuration, color: Constants.Colors.secondary)
            StatCard(title: "%", value: viewModel.sessionData.formattedPercentage, color: Constants.Colors.success)
        }
    }

    private var currentTimerDisplay: some View {
        VStack(spacing: Constants.UI.paddingSmall) {
            Text("Current Duration")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(viewModel.formattedCurrentDuration)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Constants.Colors.error)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding()
        .background(Constants.Colors.error.opacity(0.1))
        .cornerRadius(Constants.UI.cornerRadiusMedium)
        .accessibilityLabel("Current duration: \(viewModel.formattedCurrentDuration)")
    }

    private var recordingControls: some View {
        Button {
            if viewModel.isTimerRunning {
                viewModel.stopBehavior()
            } else {
                viewModel.startBehavior()
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: viewModel.isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                Text(viewModel.isTimerRunning ? "Stop" : "Start")
                    .font(.headline)
            }
            .frame(width: 120, height: 120)
            .background(viewModel.isTimerRunning ? Constants.Colors.error.gradient : Constants.Colors.accent.gradient)
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(radius: 4)
        }
        .disabled(!viewModel.isSessionActive)
        .accessibilityLabel(viewModel.isTimerRunning ? "Stop timing behavior" : "Start timing behavior")
    }

    private var behaviorList: some View {
        VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
            Text("Behavior Occurrences")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: Constants.UI.paddingSmall) {
                    ForEach(Array(viewModel.sessionData.behaviors.enumerated()), id: \.element.id) { index, behavior in
                        BehaviorRow(behavior: behavior, index: index + 1, onDelete: {
                            viewModel.deleteBehavior(at: index)
                        })
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private var sessionControls: some View {
        VStack(spacing: Constants.UI.paddingMedium) {
            if viewModel.isSessionActive {
                Button {
                    showingEndSessionAlert = true
                } label: {
                    Text("End Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.UI.preferredTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.success)
                .accessibilityLabel("End session and save")
            }
        }
    }

    private var saveSessionSheet: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    TextField("Location", text: $sessionLocation)
                        .accessibilityLabel("Session location")

                    TextField("Notes (optional)", text: $sessionNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Session notes")
                }

                Section("Summary") {
                    HStack {
                        Text("Total Duration:")
                        Spacer()
                        Text(viewModel.sessionData.formattedTotalDuration)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Occurrences:")
                        Spacer()
                        Text("\(viewModel.sessionData.count)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Average Duration:")
                        Spacer()
                        Text(viewModel.sessionData.formattedAverageDuration)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Percentage:")
                        Spacer()
                        Text(viewModel.sessionData.formattedPercentage)
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Save Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingSaveSheet = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveSession()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveSession() async {
        let location = sessionLocation.isEmpty ? Constants.Defaults.defaultSessionLocation : sessionLocation
        do {
            try await viewModel.saveSession(location: location, notes: sessionNotes.isEmpty ? nil : sessionNotes)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct BehaviorRow: View {
    let behavior: DurationData.BehaviorDuration
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("#\(index)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(behavior.formattedDuration)
                    .font(.headline)
                    .monospacedDigit()

                if behavior.isActive {
                    Text("In Progress")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.error)
                } else {
                    Text(behavior.startTime.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !behavior.isActive {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete behavior occurrence")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    let context = DataManager.shared.viewContext
    let student = Student(context: context)
    student.id = UUID()
    student.firstName = "John"
    student.lastInitial = "D"
    student.grade = 3
    student.isActive = true
    student.createdAt = Date()
    student.updatedAt = Date()

    return DurationRecorderView(student: student)
}
