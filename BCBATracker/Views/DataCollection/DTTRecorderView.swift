//
//  DTTRecorderView.swift
//  BCBATracker
//
//  DTT (Discrete Trial Training) recording interface
//

import SwiftUI
import CoreData

struct DTTRecorderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: DTTViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndSessionAlert = false
    @State private var showingSaveSheet = false
    @State private var showingTargetSetup = false
    @State private var sessionLocation = Constants.Defaults.defaultSessionLocation
    @State private var sessionNotes = ""
    @State private var selectedResponse: DTTData.DTTTrial.TrialResponse = .correct
    @State private var selectedPromptLevel: DTTData.DTTTrial.PromptLevel = .independent

    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self._viewModel = StateObject(wrappedValue: DTTViewModel(student: student, program: program))
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

                // Trial recording interface
                if viewModel.isSessionActive {
                    trialRecordingSection
                }

                Spacer()

                // Session controls
                sessionControls
            }
            .padding(Constants.UI.paddingLarge)
            .navigationTitle("DTT Session")
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSessionActive {
                        Button {
                            showingEndSessionAlert = true
                        } label: {
                            Text("End")
                                .fontWeight(.semibold)
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
                    viewModel.endSession()
                    showingSaveSheet = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved data. Would you like to save or discard this session?")
            }
            .sheet(isPresented: $showingTargetSetup) {
                TargetSetupSheet(viewModel: viewModel, isPresented: $showingTargetSetup)
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveSessionSheet
            }
            .onAppear {
                if !viewModel.isSessionActive && !viewModel.hasTarget {
                    showingTargetSetup = true
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

            if !viewModel.sessionData.target.isEmpty {
                Text("Target: \(viewModel.sessionData.target)")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.skillAcquisition)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Constants.Colors.skillAcquisition.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Button {
                    showingTargetSetup = true
                } label: {
                    Text("Set Target Skill")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.warning)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Constants.Colors.warning.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statsSection: some View {
        HStack(spacing: Constants.UI.paddingMedium) {
            StatCard(
                title: "Trials",
                value: "\(viewModel.sessionData.totalTrials)",
                color: Constants.Colors.primary
            )
            StatCard(
                title: "Correct",
                value: "\(viewModel.sessionData.correctResponses)",
                color: Constants.Colors.success
            )
            StatCard(
                title: "Accuracy",
                value: viewModel.sessionData.formattedAccuracy,
                color: Constants.Colors.accent
            )
            StatCard(
                title: "Independent",
                value: viewModel.sessionData.formattedIndependence,
                color: Constants.Colors.skillAcquisition
            )
        }
    }

    private var trialRecordingSection: some View {
        VStack(spacing: Constants.UI.paddingLarge) {
            // Response type selection
            VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
                Text("Response")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack(spacing: Constants.UI.paddingSmall) {
                    ForEach(DTTData.DTTTrial.TrialResponse.allCases, id: \.self) { response in
                        ResponseButton(
                            response: response,
                            isSelected: selectedResponse == response
                        ) {
                            selectedResponse = response
                            HapticManager.lightImpact()
                        }
                    }
                }
            }

            // Prompt level selection
            VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
                Text("Prompt Level")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Constants.UI.paddingSmall) {
                    ForEach(DTTData.DTTTrial.PromptLevel.allCases, id: \.self) { level in
                        PromptLevelButton(
                            promptLevel: level,
                            isSelected: selectedPromptLevel == level
                        ) {
                            selectedPromptLevel = level
                            HapticManager.lightImpact()
                        }
                    }
                }
            }

            // Add trial button
            Button {
                viewModel.addTrial(response: selectedResponse, promptLevel: selectedPromptLevel)
            } label: {
                Label("Record Trial #\(viewModel.currentTrialNumber + 1)", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.UI.preferredTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Constants.Colors.primary)
            .accessibilityLabel("Record trial with \(selectedResponse.displayName) response and \(selectedPromptLevel.displayName) prompt")
        }
    }

    private var sessionControls: some View {
        VStack(spacing: Constants.UI.paddingMedium) {
            if !viewModel.isSessionActive {
                Button {
                    if viewModel.hasTarget {
                        viewModel.startSession(target: viewModel.sessionData.target)
                    } else {
                        showingTargetSetup = true
                    }
                } label: {
                    Text("Start Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.UI.preferredTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.success)
                .accessibilityLabel("Start DTT session")
            } else if viewModel.sessionData.totalTrials > 0 {
                Button {
                    viewModel.deleteLastTrial()
                } label: {
                    Text("Delete Last Trial")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Delete last trial")
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
                        Text("Target Skill:")
                        Spacer()
                        Text(viewModel.sessionData.target)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Total Trials:")
                        Spacer()
                        Text("\(viewModel.sessionData.totalTrials)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Correct Responses:")
                        Spacer()
                        Text("\(viewModel.sessionData.correctResponses)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Accuracy:")
                        Spacer()
                        Text(viewModel.sessionData.formattedAccuracy)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Independence:")
                        Spacer()
                        Text(viewModel.sessionData.formattedIndependence)
                            .fontWeight(.bold)
                    }
                }

                Section("Response Distribution") {
                    ForEach(DTTData.DTTTrial.TrialResponse.allCases, id: \.self) { response in
                        if let count = viewModel.sessionData.responseDistribution[response], count > 0 {
                            HStack {
                                Text(response.displayName)
                                Spacer()
                                Text("\(count)")
                                    .fontWeight(.bold)
                            }
                        }
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

struct ResponseButton: View {
    let response: DTTData.DTTTrial.TrialResponse
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(response.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
                Text(response.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isSelected ? Color(response.color) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(Constants.UI.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                    .stroke(isSelected ? Color(response.color) : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(response.displayName) response")
    }
}

struct PromptLevelButton: View {
    let promptLevel: DTTData.DTTTrial.PromptLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(promptLevel.rawValue)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(promptLevel.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSelected ? Constants.Colors.skillAcquisition : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(Constants.UI.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                    .stroke(isSelected ? Constants.Colors.skillAcquisition : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(promptLevel.displayName) prompt level")
    }
}

struct TargetSetupSheet: View {
    @ObservedObject var viewModel: DTTViewModel
    @Binding var isPresented: Bool

    @State private var targetSkill: String

    init(viewModel: DTTViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._targetSkill = State(initialValue: viewModel.sessionData.target)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Target Skill", text: $targetSkill, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Target skill being taught")
                } header: {
                    Text("What skill are you teaching?")
                } footer: {
                    Text("Examples: \"Identifies colors\", \"Matches shapes\", \"Imitates actions\"")
                }

                Section {
                    Text("Discrete Trial Training (DTT) is a structured teaching method for skill acquisition. Each trial consists of a clear instruction, student response, and immediate feedback.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("DTT Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.updateTarget(targetSkill)
                        if !viewModel.isSessionActive {
                            viewModel.startSession(target: targetSkill)
                        }
                        isPresented = false
                    }
                    .disabled(targetSkill.isEmpty)
                }
            }
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

    return DTTRecorderView(student: student)
}
