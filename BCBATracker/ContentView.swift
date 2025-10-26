//
//  ContentView.swift
//  BCBATracker
//
//  Main content view with tab navigation
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var securityManager: SecurityManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Students Tab
            StudentsView()
                .tabItem {
                    Label("Students", systemImage: Constants.Icons.students)
                }
                .tag(0)

            // Sessions Tab
            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: Constants.Icons.sessions)
                }
                .tag(1)

            // Settings Tab
            AppSettingsView()
                .tabItem {
                    Label("Settings", systemImage: Constants.Icons.settings)
                }
                .tag(2)
        }
        .tint(Constants.Colors.primary)
    }
}

// MARK: - Students View (Placeholder)

struct StudentsView: View {
    @EnvironmentObject var dataManager: DataManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Student.firstName, ascending: true)],
        predicate: NSPredicate(format: "isActive == %@", NSNumber(value: true))
    ) var students: FetchedResults<Student>

    @State private var showingAddStudent = false

    var body: some View {
        NavigationStack {
            Group {
                if students.isEmpty {
                    // Empty state
                    VStack(spacing: Constants.UI.paddingLarge) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Students Yet")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add your first student to start collecting behavioral data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: { showingAddStudent = true }) {
                            Label("Add Student", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, Constants.UI.paddingXLarge)
                        .padding(.top)
                    }
                } else {
                    // Student list
                    List {
                        ForEach(students) { student in
                            NavigationLink {
                                StudentDetailView(student: student)
                            } label: {
                                StudentRow(student: student)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Students")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddStudent = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddStudent) {
                AddStudentView()
            }
        }
    }
}

struct StudentRow: View {
    let student: Student

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(student.displayName)
                    .font(.headline)

                Text("Grade \(student.grade)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let programCount = student.programs?.count, programCount > 0 {
                Text("\(programCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Constants.Colors.primary)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Student View (Placeholder)

struct AddStudentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var firstName = ""
    @State private var lastInitial = ""
    @State private var grade: Int16 = 1
    @State private var teacherId = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Student Information") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)

                    TextField("Last Initial", text: $lastInitial)
                        .textContentType(.familyName)
                        .onChange(of: lastInitial) { _, newValue in
                            if newValue.count > 1 {
                                lastInitial = String(newValue.prefix(1))
                            }
                            lastInitial = lastInitial.uppercased()
                        }

                    Picker("Grade", selection: $grade) {
                        ForEach(1..<13, id: \.self) { gradeLevel in
                            Text("Grade \(gradeLevel)").tag(Int16(gradeLevel))
                        }
                    }
                }

                Section("Additional Information") {
                    TextField("Teacher ID (Optional)", text: $teacherId)
                        .textContentType(.username)
                }

                Section {
                    Button("Add Student") {
                        addStudent()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !firstName.isEmpty && !lastInitial.isEmpty
    }

    private func addStudent() {
        _ = dataManager.createStudent(
            firstName: firstName,
            lastInitial: lastInitial,
            grade: grade,
            teacherId: teacherId.isEmpty ? nil : teacherId
        )

        HapticManager.success()
        dismiss()
    }
}

// MARK: - Student Detail View

struct StudentDetailView: View {
    let student: Student
    @State private var showingDataCollection = false
    @State private var selectedDataType: DataCollectionType?

    enum DataCollectionType {
        case frequency
        case duration
        case abc
        case interval
        case dtt
        case taskAnalysis

        var title: String {
            switch self {
            case .frequency: return "Frequency"
            case .duration: return "Duration"
            case .abc: return "ABC Data"
            case .interval: return "Interval"
            case .dtt: return "DTT Session"
            case .taskAnalysis: return "Task Analysis"
            }
        }

        var icon: String {
            switch self {
            case .frequency: return Constants.Icons.frequency
            case .duration: return Constants.Icons.duration
            case .abc: return Constants.Icons.abc
            case .interval: return Constants.Icons.interval
            case .dtt: return Constants.Icons.dtt
            case .taskAnalysis: return Constants.Icons.taskAnalysis
            }
        }

        var description: String {
            switch self {
            case .frequency: return "Count occurrences of behavior"
            case .duration: return "Measure how long behavior lasts"
            case .abc: return "Record antecedent, behavior, consequence"
            case .interval: return "Record behavior in time intervals"
            case .dtt: return "Discrete trial teaching session"
            case .taskAnalysis: return "Break down complex skills into steps"
            }
        }

        var color: Color {
            switch self {
            case .frequency: return Constants.Colors.primary
            case .duration: return Constants.Colors.accent
            case .abc: return Constants.Colors.warning
            case .interval: return Constants.Colors.secondary
            case .dtt: return Constants.Colors.skillAcquisition
            case .taskAnalysis: return Constants.Colors.success
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.UI.paddingLarge) {
                // Student header
                VStack(spacing: Constants.UI.paddingSmall) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Constants.Colors.primary)

                    Text(student.displayName)
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Grade \(student.grade)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, Constants.UI.paddingLarge)

                // Data collection methods
                VStack(alignment: .leading, spacing: Constants.UI.paddingMedium) {
                    Text("Start Data Collection")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: Constants.UI.paddingMedium),
                        GridItem(.flexible(), spacing: Constants.UI.paddingMedium)
                    ], spacing: Constants.UI.paddingMedium) {
                        DataCollectionButton(type: .frequency) {
                            selectedDataType = .frequency
                            showingDataCollection = true
                        }

                        DataCollectionButton(type: .duration) {
                            selectedDataType = .duration
                            showingDataCollection = true
                        }

                        DataCollectionButton(type: .abc) {
                            selectedDataType = .abc
                            showingDataCollection = true
                        }

                        DataCollectionButton(type: .interval) {
                            selectedDataType = .interval
                            showingDataCollection = true
                        }

                        DataCollectionButton(type: .dtt) {
                            selectedDataType = .dtt
                            showingDataCollection = true
                        }

                        DataCollectionButton(type: .taskAnalysis) {
                            selectedDataType = .taskAnalysis
                            showingDataCollection = true
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .navigationTitle("Student Details")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingDataCollection) {
            if let dataType = selectedDataType {
                switch dataType {
                case .frequency:
                    FrequencyRecorderView(student: student)
                case .duration:
                    DurationRecorderView(student: student)
                case .abc:
                    ABCRecorderView(student: student)
                case .interval:
                    IntervalRecorderView(student: student)
                case .dtt:
                    DTTRecorderView(student: student)
                case .taskAnalysis:
                    TaskAnalysisRecorderView(student: student)
                }
            }
        }
    }
}

struct DataCollectionButton: View {
    let type: StudentDetailView.DataCollectionType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Constants.UI.paddingSmall) {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(type.color)

                Text(type.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(type.color.opacity(0.1))
            .cornerRadius(Constants.UI.cornerRadiusMedium)
        }
        .accessibilityLabel("\(type.title): \(type.description)")
    }
}

// MARK: - Sessions View (Placeholder)

struct SessionsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
    ) var sessions: FetchedResults<Session>

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    // Empty state
                    VStack(spacing: Constants.UI.paddingLarge) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Sessions Yet")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Create a student and start your first data collection session")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(sessions) { session in
                            SessionRow(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Sessions")
        }
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            Image(systemName: session.sessionType.icon)
                .font(.title3)
                .foregroundColor(Constants.Colors.primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionType.displayName)
                    .font(.headline)

                if let studentName = session.student?.displayName {
                    Text(studentName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(session.startTime.shortDate + " at " + session.startTime.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if session.isActive {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(8)
            } else {
                Text(session.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings View
// Note: Using AppSettingsView from Views/SettingsView.swift

// MARK: - Preview

#Preview("Content View") {
    ContentView()
        .environment(\.managedObjectContext, DataManager.shared.viewContext)
        .environmentObject(DataManager.shared)
        .environmentObject(SecurityManager.shared)
}

#Preview("Students View - Empty") {
    NavigationStack {
        StudentsView()
    }
    .environment(\.managedObjectContext, DataManager.shared.viewContext)
    .environmentObject(DataManager.shared)
}

#Preview("Settings View") {
    NavigationStack {
        AppSettingsView()
    }
    .environmentObject(DataManager.shared)
    .environmentObject(SecurityManager.shared)
    .environmentObject(GoogleDriveManager.shared)
    .environmentObject(ExportManager.shared)
}
