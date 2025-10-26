//
//  TaskAnalysisRecorderView.swift
//  BCBATracker
//
//  Task Analysis recording interface for breaking down complex skills
//

import SwiftUI
import CoreData

struct TaskAnalysisRecorderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TaskAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndSessionAlert = false
    @State private var showingSaveSheet = false
    @State private var showingTaskSetup = false
    @State private var showingTrialRecording = false
    @State private var sessionLocation = Constants.Defaults.defaultSessionLocation
    @State private var sessionNotes = ""

    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self._viewModel = StateObject(wrappedValue: TaskAnalysisViewModel(student: student, program: program))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.paddingLarge) {
                // Header with student info
                headerSection

                // Stats summary
                if viewModel.isSessionActive {
                    statsSection
                }

                // Task steps display
                if !viewModel.sessionData.steps.isEmpty {
                    stepsSection
                }

                Spacer()

                // Session controls
                sessionControls
            }
            .padding(Constants.UI.paddingLarge)
            .navigationTitle("Task Analysis")
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
                    } else {
                        Button {
                            showingTaskSetup = true
                        } label: {
                            Image(systemName: "gearshape")
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
            .sheet(isPresented: $showingTaskSetup) {
                TaskSetupSheet(viewModel: viewModel, isPresented: $showingTaskSetup)
            }
            .sheet(isPresented: $showingTrialRecording) {
                TrialRecordingSheet(viewModel: viewModel, isPresented: $showingTrialRecording)
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveSessionSheet
            }
            .onAppear {
                if !viewModel.isSessionActive && !viewModel.isTaskConfigured {
                    showingTaskSetup = true
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

            if !viewModel.sessionData.taskName.isEmpty {
                Text("Task: \(viewModel.sessionData.taskName)")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Constants.Colors.success.opacity(0.2))
                    .cornerRadius(8)

                Text(viewModel.sessionData.chainingType.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Button {
                    showingTaskSetup = true
                } label: {
                    Text("Setup Task")
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
                title: "Completed",
                value: "\(viewModel.sessionData.completedTrials)",
                color: Constants.Colors.success
            )
            StatCard(
                title: "Rate",
                value: viewModel.sessionData.formattedCompletionRate,
                color: Constants.Colors.accent
            )
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.paddingSmall) {
            Text("Task Steps (\(viewModel.sessionData.totalSteps))")
                .font(.headline)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: Constants.UI.paddingSmall) {
                    ForEach(viewModel.sessionData.steps.filter { $0.isActive }) { step in
                        StepRow(
                            step: step,
                            masteryPercentage: viewModel.stepMasteryPercentage(for: step.stepNumber)
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private var sessionControls: some View {
        VStack(spacing: Constants.UI.paddingMedium) {
            if !viewModel.isSessionActive {
                Button {
                    if viewModel.isTaskConfigured {
                        viewModel.startSession(
                            taskName: viewModel.sessionData.taskName,
                            chainingType: viewModel.sessionData.chainingType,
                            steps: viewModel.sessionData.steps
                        )
                    } else {
                        showingTaskSetup = true
                    }
                } label: {
                    Text("Start Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.UI.preferredTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.success)
                .disabled(!viewModel.isTaskConfigured)
                .accessibilityLabel("Start task analysis session")
            } else {
                Button {
                    showingTrialRecording = true
                } label: {
                    Label("Record Trial #\(viewModel.currentTrialNumber + 1)", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.UI.preferredTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.primary)
                .accessibilityLabel("Record new trial")

                if viewModel.sessionData.totalTrials > 0 {
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
                        Text("Task:")
                        Spacer()
                        Text(viewModel.sessionData.taskName)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Chaining Type:")
                        Spacer()
                        Text(viewModel.sessionData.chainingType.rawValue)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Total Steps:")
                        Spacer()
                        Text("\(viewModel.sessionData.totalSteps)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Total Trials:")
                        Spacer()
                        Text("\(viewModel.sessionData.totalTrials)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Completion Rate:")
                        Spacer()
                        Text(viewModel.sessionData.formattedCompletionRate)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Independence Rate:")
                        Spacer()
                        Text(viewModel.sessionData.formattedIndependenceRate)
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

struct StepRow: View {
    let step: TaskAnalysisData.TaskStep
    let masteryPercentage: Double

    var body: some View {
        HStack {
            Text("\(step.stepNumber).")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            Text(step.description)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            if masteryPercentage > 0 {
                Text(String(format: "%.0f%%", masteryPercentage))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(masteryColor(for: masteryPercentage))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(Constants.UI.cornerRadiusSmall)
    }

    private func masteryColor(for percentage: Double) -> Color {
        if percentage >= 80 {
            return Constants.Colors.success
        } else if percentage >= 50 {
            return Constants.Colors.warning
        } else {
            return Constants.Colors.error
        }
    }
}

struct TaskSetupSheet: View {
    @ObservedObject var viewModel: TaskAnalysisViewModel
    @Binding var isPresented: Bool

    @State private var taskName: String
    @State private var chainingType: TaskAnalysisData.ChainingType
    @State private var steps: [TaskAnalysisData.TaskStep]
    @State private var newStepText = ""

    init(viewModel: TaskAnalysisViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._taskName = State(initialValue: viewModel.sessionData.taskName)
        self._chainingType = State(initialValue: viewModel.sessionData.chainingType)
        self._steps = State(initialValue: viewModel.sessionData.steps)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task Name", text: $taskName)
                        .accessibilityLabel("Task name")
                } header: {
                    Text("What skill are you teaching?")
                } footer: {
                    Text("Example: \"Hand washing\", \"Making a sandwich\"")
                }

                Section {
                    Picker("Chaining Method", selection: $chainingType) {
                        ForEach(TaskAnalysisData.ChainingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(chainingType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Chaining Type")
                }

                Section {
                    ForEach(steps) { step in
                        HStack {
                            Text("\(step.stepNumber).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(step.description)
                        }
                    }
                    .onDelete { indexSet in
                        steps.remove(atOffsets: indexSet)
                        // Renumber steps
                        for (index, _) in steps.enumerated() {
                            steps[index].stepNumber = index + 1
                        }
                    }
                    .onMove { from, to in
                        steps.move(fromOffsets: from, toOffset: to)
                        // Renumber steps
                        for (index, _) in steps.enumerated() {
                            steps[index].stepNumber = index + 1
                        }
                    }

                    HStack {
                        TextField("Add step", text: $newStepText)
                        Button {
                            addStep()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .disabled(newStepText.isEmpty)
                    }
                } header: {
                    Text("Task Steps (\(steps.count))")
                } footer: {
                    Text("Add all steps in the order they should be performed. You can reorder steps by drag and drop.")
                }
            }
            .navigationTitle("Task Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.updateTaskName(taskName)
                        viewModel.updateChainingType(chainingType)
                        viewModel.sessionData.steps = steps
                        isPresented = false
                    }
                    .disabled(taskName.isEmpty || steps.isEmpty)
                }
            }
        }
    }

    private func addStep() {
        let stepNumber = steps.count + 1
        let step = TaskAnalysisData.TaskStep(
            stepNumber: stepNumber,
            description: newStepText
        )
        steps.append(step)
        newStepText = ""
    }
}

struct TrialRecordingSheet: View {
    @ObservedObject var viewModel: TaskAnalysisViewModel
    @Binding var isPresented: Bool

    @State private var stepResults: [TaskAnalysisData.TaskTrial.StepResult] = []
    @State private var promptLevel: TaskAnalysisData.TaskTrial.PromptLevel = .independent
    @State private var trialNotes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(viewModel.sessionData.steps.filter { $0.isActive }) { step in
                        if let index = stepResults.firstIndex(where: { $0.stepNumber == step.stepNumber }) {
                            HStack {
                                Text("\(step.stepNumber). \(step.description)")
                                    .font(.subheadline)

                                Spacer()

                                Button {
                                    stepResults[index].completed.toggle()
                                } label: {
                                    Image(systemName: stepResults[index].completed ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(stepResults[index].completed ? Constants.Colors.success : .gray)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Mark Completed Steps")
                }

                Section {
                    Picker("Prompt Level", selection: $promptLevel) {
                        ForEach(TaskAnalysisData.TaskTrial.PromptLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Prompt Level Used")
                }

                Section {
                    TextField("Trial notes (optional)", text: $trialNotes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Record Trial #\(viewModel.currentTrialNumber + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.addTrial(
                            stepResults: stepResults,
                            promptLevel: promptLevel,
                            notes: trialNotes.isEmpty ? nil : trialNotes
                        )
                        isPresented = false
                    }
                }
            }
            .onAppear {
                initializeStepResults()
            }
        }
    }

    private func initializeStepResults() {
        stepResults = viewModel.sessionData.steps
            .filter { $0.isActive }
            .map { step in
                TaskAnalysisData.TaskTrial.StepResult(
                    stepNumber: step.stepNumber,
                    completed: false,
                    promptUsed: false
                )
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

    return TaskAnalysisRecorderView(student: student)
}
