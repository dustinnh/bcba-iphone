//
//  IntervalRecorderView.swift
//  BCBATracker
//
//  Interval recording interface for behavior data collection
//

import SwiftUI
import CoreData

struct IntervalRecorderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: IntervalViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndSessionAlert = false
    @State private var showingSaveSheet = false
    @State private var showingSettings = false
    @State private var sessionLocation = Constants.Defaults.defaultSessionLocation
    @State private var sessionNotes = ""

    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self._viewModel = StateObject(wrappedValue: IntervalViewModel(student: student, program: program))
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

                // Current interval display
                if viewModel.isIntervalRunning {
                    currentIntervalDisplay
                }

                // Recording controls
                if viewModel.isIntervalRunning {
                    recordingControls
                }

                Spacer()

                // Session controls
                sessionControls
            }
            .padding(Constants.UI.paddingLarge)
            .navigationTitle("Interval Recording")
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
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .disabled(viewModel.isSessionActive)
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
            .sheet(isPresented: $showingSettings) {
                IntervalSettingsSheet(viewModel: viewModel, isPresented: $showingSettings)
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

            Text(viewModel.sessionData.intervalType.rawValue)
                .font(.caption)
                .foregroundColor(Constants.Colors.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Constants.Colors.secondary.opacity(0.2))
                .cornerRadius(8)
        }
        .accessibilityElement(children: .combine)
    }

    private var statsSection: some View {
        HStack(spacing: Constants.UI.paddingMedium) {
            StatCard(
                title: "Intervals",
                value: "\(viewModel.sessionData.totalIntervals)",
                color: Constants.Colors.primary
            )
            StatCard(
                title: "With Behavior",
                value: "\(viewModel.sessionData.intervalsWithBehavior)",
                color: Constants.Colors.accent
            )
            StatCard(
                title: "%",
                value: viewModel.sessionData.formattedPercentage,
                color: Constants.Colors.success
            )
        }
    }

    private var currentIntervalDisplay: some View {
        VStack(spacing: Constants.UI.paddingMedium) {
            Text("Interval #\(viewModel.currentIntervalNumber)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: viewModel.intervalProgress)
                    .stroke(
                        Constants.Colors.primary.gradient,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.intervalProgress)

                VStack(spacing: 4) {
                    Text(viewModel.formattedTimeRemaining)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Constants.Colors.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Interval Duration: \(viewModel.sessionData.formattedIntervalDuration)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Interval \(viewModel.currentIntervalNumber), \(viewModel.formattedTimeRemaining) remaining")
    }

    private var recordingControls: some View {
        HStack(spacing: Constants.UI.paddingLarge) {
            // No button
            Button {
                viewModel.markBehaviorNotOccurred()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                    Text("No")
                        .font(.headline)
                }
                .frame(width: 120, height: 120)
                .background(Color.red.gradient)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 4)
            }
            .accessibilityLabel("Mark behavior as not occurred")

            // Yes button
            Button {
                viewModel.markBehaviorOccurred()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                    Text("Yes")
                        .font(.headline)
                }
                .frame(width: 120, height: 120)
                .background(Color.green.gradient)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 4)
            }
            .accessibilityLabel("Mark behavior as occurred")
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

                if viewModel.sessionData.totalIntervals > 0 {
                    Button {
                        viewModel.deleteLastInterval()
                    } label: {
                        Text("Delete Last Interval")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Delete last interval")
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
                        Text("Total Intervals:")
                        Spacer()
                        Text("\(viewModel.sessionData.totalIntervals)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Intervals with Behavior:")
                        Spacer()
                        Text("\(viewModel.sessionData.intervalsWithBehavior)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Percentage:")
                        Spacer()
                        Text(viewModel.sessionData.formattedPercentage)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Type:")
                        Spacer()
                        Text(viewModel.sessionData.intervalType.rawValue)
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

struct IntervalSettingsSheet: View {
    @ObservedObject var viewModel: IntervalViewModel
    @Binding var isPresented: Bool

    @State private var intervalDuration: Double
    @State private var intervalType: IntervalData.IntervalType

    init(viewModel: IntervalViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._intervalDuration = State(initialValue: viewModel.sessionData.intervalDuration)
        self._intervalType = State(initialValue: viewModel.sessionData.intervalType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Interval Duration") {
                    Stepper(value: $intervalDuration, in: 5...300, step: 5) {
                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text("\(Int(intervalDuration))s")
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Interval Type") {
                    Picker("Type", selection: $intervalType) {
                        ForEach(IntervalData.IntervalType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(intervalType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Interval Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.sessionData.intervalDuration = intervalDuration
                        viewModel.sessionData.intervalType = intervalType
                        isPresented = false
                    }
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

    return IntervalRecorderView(student: student)
}
