//
//  ABCRecorderView.swift
//  BCBATracker
//
//  ABC (Antecedent-Behavior-Consequence) recording interface
//

import SwiftUI
import CoreData

struct ABCRecorderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ABCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndSessionAlert = false
    @State private var showingSaveSheet = false
    @State private var showingAddObservation = false
    @State private var sessionLocation = Constants.Defaults.defaultSessionLocation
    @State private var sessionNotes = ""

    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self._viewModel = StateObject(wrappedValue: ABCViewModel(student: student, program: program))
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

                // Observations list
                if !viewModel.sessionData.observations.isEmpty {
                    observationsList
                }

                Spacer()

                // Add observation button
                addObservationButton

                // Session controls
                sessionControls
            }
            .padding(Constants.UI.paddingLarge)
            .navigationTitle("ABC Recording")
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
            .sheet(isPresented: $showingAddObservation) {
                AddObservationSheet(viewModel: viewModel, isPresented: $showingAddObservation)
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

            if viewModel.isSessionActive {
                Text(viewModel.sessionData.formattedSessionDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statsSection: some View {
        HStack(spacing: Constants.UI.paddingMedium) {
            StatCard(title: "Total", value: "\(viewModel.sessionData.count)", color: Constants.Colors.primary)
            StatCard(title: "Duration", value: viewModel.sessionData.formattedSessionDuration, color: Constants.Colors.accent)
        }
    }

    private var observationsList: some View {
        VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
            Text("Observations")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: Constants.UI.paddingSmall) {
                    ForEach(Array(viewModel.sessionData.observations.enumerated()), id: \.element.id) { index, observation in
                        ABCObservationRow(
                            observation: observation,
                            index: index + 1,
                            onDelete: {
                                viewModel.deleteObservation(at: index)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }

    private var addObservationButton: some View {
        Button {
            showingAddObservation = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                Text("Add Observation")
                    .font(.headline)
            }
            .frame(width: 160, height: 120)
            .background(Constants.Colors.warning.gradient)
            .foregroundColor(.white)
            .cornerRadius(Constants.UI.cornerRadiusMedium)
            .shadow(radius: 4)
        }
        .disabled(!viewModel.isSessionActive)
        .accessibilityLabel("Add ABC observation")
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
                        Text("Observations:")
                        Spacer()
                        Text("\(viewModel.sessionData.count)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text(viewModel.sessionData.formattedSessionDuration)
                            .fontWeight(.bold)
                            .monospacedDigit()
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

struct ABCObservationRow: View {
    let observation: ABCData.ABCObservation
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
            HStack {
                Text("#\(index)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Text(observation.timestamp.time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete observation")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("A:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                    Text(observation.antecedent)
                        .font(.subheadline)
                }

                HStack {
                    Text("B:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.error)
                    Text(observation.behavior)
                        .font(.subheadline)
                }

                HStack {
                    Text("C:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.accent)
                    Text(observation.consequence)
                        .font(.subheadline)
                }

                if let intensity = observation.intensity {
                    HStack {
                        Text("Intensity:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(intensity.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(intensityColor(for: intensity))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func intensityColor(for intensity: ABCData.ABCObservation.Intensity) -> Color {
        switch intensity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .severe: return .red
        }
    }
}

struct AddObservationSheet: View {
    @ObservedObject var viewModel: ABCViewModel
    @Binding var isPresented: Bool

    @State private var antecedent = ""
    @State private var behavior = ""
    @State private var consequence = ""
    @State private var setting = ""
    @State private var selectedIntensity: ABCData.ABCObservation.Intensity? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("ABC Components") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Antecedent")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.primary)
                        TextField("What happened before the behavior?", text: $antecedent, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Behavior")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.error)
                        TextField("What was the behavior?", text: $behavior, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consequence")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.accent)
                        TextField("What happened after the behavior?", text: $consequence, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                Section("Additional Details (Optional)") {
                    TextField("Setting/Context", text: $setting)

                    Picker("Intensity", selection: $selectedIntensity) {
                        Text("None").tag(nil as ABCData.ABCObservation.Intensity?)
                        ForEach(ABCData.ABCObservation.Intensity.allCases, id: \.self) { intensity in
                            Text(intensity.rawValue).tag(intensity as ABCData.ABCObservation.Intensity?)
                        }
                    }
                }
            }
            .navigationTitle("Add Observation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addObservation()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !antecedent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !behavior.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !consequence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addObservation() {
        viewModel.addObservation(
            antecedent: antecedent.trimmingCharacters(in: .whitespacesAndNewlines),
            behavior: behavior.trimmingCharacters(in: .whitespacesAndNewlines),
            consequence: consequence.trimmingCharacters(in: .whitespacesAndNewlines),
            setting: setting.isEmpty ? nil : setting,
            duration: nil,
            intensity: selectedIntensity
        )

        isPresented = false
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

    return ABCRecorderView(student: student)
}
