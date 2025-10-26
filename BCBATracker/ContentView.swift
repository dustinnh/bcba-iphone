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
                            StudentRow(student: student)
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
