//
//  FrequencyRecorderView.swift
//  BCBATracker
//
//  Frequency recording interface for behavior data collection
//

import SwiftUI
import CoreData

struct FrequencyRecorderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: FrequencyViewModel
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
        self._viewModel = StateObject(wrappedValue: FrequencyViewModel(student: student, program: program))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.paddingLarge) {
                // Header with student info
                headerSection

                Spacer()

                // Main counter display
                counterDisplay

                // Rate display
                rateDisplay

                Spacer()

                // Recording controls
                recordingControls

                // Session controls
                sessionControls
            }
            .padding(Constants.UI.paddingLarge)
            .navigationTitle("Frequency Recording")
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

            // Session timer
            if viewModel.isSessionActive {
                Text(viewModel.sessionData.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording session for \(student.firstName ?? "") \(student.lastInitial ?? "")")
    }

    private var counterDisplay: some View {
        VStack(spacing: Constants.UI.paddingSmall) {
            Text("Count")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("\(viewModel.sessionData.count)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(Constants.Colors.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Behavior count: \(viewModel.sessionData.count)")
    }

    private var rateDisplay: some View {
        VStack(spacing: Constants.UI.paddingSmall) {
            Text("Rate")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(viewModel.sessionData.formattedRate)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rate: \(viewModel.sessionData.formattedRate)")
    }

    private var recordingControls: some View {
        HStack(spacing: Constants.UI.paddingLarge) {
            // Undo button
            Button {
                viewModel.undoLastBehavior()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title2)
                    .frame(width: Constants.UI.preferredTouchTarget, height: Constants.UI.preferredTouchTarget)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.sessionData.count == 0)
            .accessibilityLabel("Undo last behavior")
            .accessibilityHint("Removes the most recent behavior from the count")

            // Main record button
            Button {
                viewModel.recordBehavior()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                    Text("Record")
                        .font(.headline)
                }
                .frame(width: 120, height: 120)
                .background(Constants.Colors.primary.gradient)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 4)
            }
            .disabled(!viewModel.isSessionActive)
            .accessibilityLabel("Record behavior")
            .accessibilityHint("Tap to record a behavior occurrence")

            // Spacer for symmetry
            Color.clear
                .frame(width: Constants.UI.preferredTouchTarget, height: Constants.UI.preferredTouchTarget)
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
                .accessibilityLabel("End session")
                .accessibilityHint("Stop recording and save the session")
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

                Section {
                    VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
                        HStack {
                            Text("Behaviors Recorded:")
                            Spacer()
                            Text("\(viewModel.sessionData.count)")
                                .fontWeight(.bold)
                        }

                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text(viewModel.sessionData.formattedDuration)
                                .fontWeight(.bold)
                        }

                        HStack {
                            Text("Rate:")
                            Spacer()
                            Text(viewModel.sessionData.formattedRate)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.subheadline)
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

    return FrequencyRecorderView(student: student)
}
