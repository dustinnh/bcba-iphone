//
//  ExportManager.swift
//  BCBATracker
//
//  Service for exporting Core Data to JSON and importing JSON back to Core Data
//  Supports Google Drive backup/restore functionality
//

import Foundation
import CoreData
import OSLog
import Combine

/// Manager for data export and import operations
@MainActor
class ExportManager: ObservableObject {

    // MARK: - Singleton
    static let shared = ExportManager()

    // MARK: - Published Properties
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var exportProgress: Double = 0.0
    @Published var importProgress: Double = 0.0
    @Published var lastError: Error?

    // MARK: - Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bcba.tracker", category: "ExportManager")

    // MARK: - Private Properties
    private let dataManager = DataManager.shared

    // MARK: - Initialization
    private init() {}

    // MARK: - Export Operations

    /// Export all data to BackupData structure
    /// - Returns: Complete backup data ready for JSON serialization
    func exportAllData() async throws -> BackupData {
        isExporting = true
        exportProgress = 0.0
        defer {
            isExporting = false
            exportProgress = 0.0
        }

        logger.info("Starting data export")

        let context = dataManager.viewContext

        // Fetch all entities
        exportProgress = 0.1
        let students = try await fetchAllStudents(context: context)

        exportProgress = 0.3
        let programs = try await fetchAllPrograms(context: context)

        exportProgress = 0.5
        let sessions = try await fetchAllSessions(context: context)

        exportProgress = 0.7
        let behaviors = try await fetchAllBehaviors(context: context)

        exportProgress = 0.9

        // Create metadata
        let metadata = BackupMetadata(
            studentCount: students.count,
            sessionCount: sessions.count,
            behaviorCount: behaviors.count
        )

        // Create backup data
        let backupData = BackupData(
            metadata: metadata,
            students: students,
            programs: programs,
            sessions: sessions,
            behaviors: behaviors
        )

        exportProgress = 1.0
        logger.info("Data export completed: \(students.count) students, \(programs.count) programs, \(sessions.count) sessions, \(behaviors.count) behaviors")

        return backupData
    }

    /// Export data to JSON file
    /// - Returns: URL to the exported JSON file
    func exportToJSON() async throws -> URL {
        logger.info("Exporting data to JSON")

        let backupData = try await exportAllData()

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(backupData)

        // Create file URL
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = "\(Constants.GoogleDrive.backupFilePrefix)\(timestamp).\(Constants.GoogleDrive.backupFileExtension)"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Write to file
        try jsonData.write(to: fileURL, options: .atomic)

        logger.info("JSON export completed: \(fileURL.path)")

        return fileURL
    }

    // MARK: - Import Operations

    /// Import data from JSON file
    /// - Parameters:
    ///   - url: URL to the JSON backup file
    ///   - strategy: Conflict resolution strategy
    func importFromJSON(url: URL, strategy: ImportStrategy = .merge) async throws {
        isImporting = true
        importProgress = 0.0
        defer {
            isImporting = false
            importProgress = 0.0
        }

        logger.info("Starting data import from: \(url.path)")

        // Read JSON file
        let jsonData = try Data(contentsOf: url)

        importProgress = 0.1

        // Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        importProgress = 0.2

        // Validate schema version
        guard backupData.metadata.schemaVersion <= Constants.GoogleDrive.currentSchemaVersion else {
            throw ExportError.incompatibleSchema(
                backup: backupData.metadata.schemaVersion,
                current: Constants.GoogleDrive.currentSchemaVersion
            )
        }

        logger.info("Importing backup created on \(backupData.metadata.createdAt) from \(backupData.metadata.deviceName)")

        // Import data based on strategy
        switch strategy {
        case .merge:
            try await importWithMerge(backupData: backupData)
        case .replace:
            try await importWithReplace(backupData: backupData)
        case .skip:
            try await importSkippingExisting(backupData: backupData)
        }

        importProgress = 1.0
        logger.info("Data import completed successfully")
    }

    // MARK: - Private Fetch Methods

    private func fetchAllStudents(context: NSManagedObjectContext) async throws -> [StudentBackup] {
        let request = NSFetchRequest<Student>(entityName: "Student")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Student.createdAt, ascending: true)]

        let students = try context.fetch(request)

        return students.map { student in
            StudentBackup(
                id: student.id.uuidString,
                firstName: student.firstName,
                lastInitial: student.lastInitial,
                grade: student.grade,
                teacherId: student.teacherId,
                isActive: student.isActive,
                createdAt: student.createdAt,
                updatedAt: student.updatedAt
            )
        }
    }

    private func fetchAllPrograms(context: NSManagedObjectContext) async throws -> [ProgramBackup] {
        let request = NSFetchRequest<Program>(entityName: "Program")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Program.createdAt, ascending: true)]

        let programs = try context.fetch(request)

        return programs.map { program in
            ProgramBackup(
                id: program.id.uuidString,
                name: program.name,
                type: program.type,
                targetBehaviors: program.targetBehaviors,
                masteryCriteria: program.masteryCriteria,
                isActive: program.isActive,
                createdAt: program.createdAt,
                updatedAt: program.updatedAt,
                studentId: program.student?.id.uuidString ?? ""
            )
        }
    }

    private func fetchAllSessions(context: NSManagedObjectContext) async throws -> [SessionBackup] {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: true)]

        let sessions = try context.fetch(request)

        return sessions.map { session in
            SessionBackup(
                id: session.id.uuidString,
                type: session.type,
                startTime: session.startTime,
                endTime: session.endTime,
                location: session.location,
                notes: session.notes,
                data: session.data,
                studentId: session.student?.id.uuidString ?? "",
                programId: session.program?.id.uuidString
            )
        }
    }

    private func fetchAllBehaviors(context: NSManagedObjectContext) async throws -> [BehaviorBackup] {
        let request = NSFetchRequest<Behavior>(entityName: "Behavior")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Behavior.timestamp, ascending: true)]

        let behaviors = try context.fetch(request)

        return behaviors.map { behavior in
            BehaviorBackup(
                id: behavior.id.uuidString,
                timestamp: behavior.timestamp,
                type: behavior.type,
                frequency: behavior.frequency,
                duration: behavior.duration,
                antecedent: behavior.antecedent,
                consequence: behavior.consequence,
                interval: behavior.interval,
                promptLevel: behavior.promptLevel,
                sessionId: behavior.session?.id.uuidString ?? ""
            )
        }
    }

    // MARK: - Private Import Methods

    private func importWithMerge(backupData: BackupData) async throws {
        let context = dataManager.newBackgroundContext()

        try await context.perform {
            // Import students
            self.importProgress = 0.3
            try self.importStudents(backupData.students, context: context, skipExisting: true)

            // Import programs
            self.importProgress = 0.5
            try self.importPrograms(backupData.programs, context: context, skipExisting: true)

            // Import sessions
            self.importProgress = 0.7
            try self.importSessions(backupData.sessions, context: context, skipExisting: true)

            // Import behaviors
            self.importProgress = 0.9
            try self.importBehaviors(backupData.behaviors, context: context, skipExisting: true)

            // Save context
            try context.save()

            self.logger.info("Merge import completed")
        }
    }

    private func importWithReplace(backupData: BackupData) async throws {
        logger.warning("Replacing all existing data with backup")

        let context = dataManager.newBackgroundContext()

        try await context.perform {
            // Delete all existing data
            try self.deleteAllData(context: context)

            // Import all data
            self.importProgress = 0.3
            try self.importStudents(backupData.students, context: context, skipExisting: false)

            self.importProgress = 0.5
            try self.importPrograms(backupData.programs, context: context, skipExisting: false)

            self.importProgress = 0.7
            try self.importSessions(backupData.sessions, context: context, skipExisting: false)

            self.importProgress = 0.9
            try self.importBehaviors(backupData.behaviors, context: context, skipExisting: false)

            // Save context
            try context.save()

            self.logger.info("Replace import completed")
        }
    }

    private func importSkippingExisting(backupData: BackupData) async throws {
        // Same as merge
        try await importWithMerge(backupData: backupData)
    }

    private func importStudents(_ students: [StudentBackup], context: NSManagedObjectContext, skipExisting: Bool) throws {
        for studentBackup in students {
            guard let id = UUID(uuidString: studentBackup.id) else {
                logger.error("Invalid student UUID: \(studentBackup.id)")
                continue
            }

            // Check if exists
            if skipExisting && studentExists(id: id, context: context) {
                continue
            }

            // Create or update student
            let student = Student(context: context)
            student.id = id
            student.firstName = studentBackup.firstName
            student.lastInitial = studentBackup.lastInitial
            student.grade = studentBackup.grade
            student.teacherId = studentBackup.teacherId
            student.isActive = studentBackup.isActive
            student.createdAt = studentBackup.createdAt
            student.updatedAt = studentBackup.updatedAt
        }

        logger.info("Imported \(students.count) students")
    }

    private func importPrograms(_ programs: [ProgramBackup], context: NSManagedObjectContext, skipExisting: Bool) throws {
        for programBackup in programs {
            guard let id = UUID(uuidString: programBackup.id) else {
                logger.error("Invalid program UUID: \(programBackup.id)")
                continue
            }

            if skipExisting && programExists(id: id, context: context) {
                continue
            }

            // Find student
            guard let studentId = UUID(uuidString: programBackup.studentId),
                  let student = findStudent(id: studentId, context: context) else {
                logger.error("Student not found for program: \(programBackup.id)")
                continue
            }

            // Create program
            let program = Program(context: context)
            program.id = id
            program.name = programBackup.name
            program.type = programBackup.type
            program.targetBehaviors = programBackup.targetBehaviors
            program.masteryCriteria = programBackup.masteryCriteria
            program.isActive = programBackup.isActive
            program.createdAt = programBackup.createdAt
            program.updatedAt = programBackup.updatedAt
            program.student = student
        }

        logger.info("Imported \(programs.count) programs")
    }

    private func importSessions(_ sessions: [SessionBackup], context: NSManagedObjectContext, skipExisting: Bool) throws {
        for sessionBackup in sessions {
            guard let id = UUID(uuidString: sessionBackup.id) else {
                logger.error("Invalid session UUID: \(sessionBackup.id)")
                continue
            }

            if skipExisting && sessionExists(id: id, context: context) {
                continue
            }

            // Find student
            guard let studentId = UUID(uuidString: sessionBackup.studentId),
                  let student = findStudent(id: studentId, context: context) else {
                logger.error("Student not found for session: \(sessionBackup.id)")
                continue
            }

            // Find program (optional)
            var program: Program?
            if let programIdString = sessionBackup.programId,
               let programId = UUID(uuidString: programIdString) {
                program = findProgram(id: programId, context: context)
            }

            // Create session
            let session = Session(context: context)
            session.id = id
            session.type = sessionBackup.type
            session.startTime = sessionBackup.startTime
            session.endTime = sessionBackup.endTime
            session.location = sessionBackup.location
            session.notes = sessionBackup.notes
            session.data = sessionBackup.data
            session.student = student
            session.program = program
        }

        logger.info("Imported \(sessions.count) sessions")
    }

    private func importBehaviors(_ behaviors: [BehaviorBackup], context: NSManagedObjectContext, skipExisting: Bool) throws {
        for behaviorBackup in behaviors {
            guard let id = UUID(uuidString: behaviorBackup.id) else {
                logger.error("Invalid behavior UUID: \(behaviorBackup.id)")
                continue
            }

            if skipExisting && behaviorExists(id: id, context: context) {
                continue
            }

            // Find session
            guard let sessionId = UUID(uuidString: behaviorBackup.sessionId),
                  let session = findSession(id: sessionId, context: context) else {
                logger.error("Session not found for behavior: \(behaviorBackup.id)")
                continue
            }

            // Create behavior
            let behavior = Behavior(context: context)
            behavior.id = id
            behavior.timestamp = behaviorBackup.timestamp
            behavior.type = behaviorBackup.type
            behavior.frequency = behaviorBackup.frequency
            behavior.duration = behaviorBackup.duration
            behavior.antecedent = behaviorBackup.antecedent
            behavior.consequence = behaviorBackup.consequence
            behavior.interval = behaviorBackup.interval
            behavior.promptLevel = behaviorBackup.promptLevel
            behavior.session = session
        }

        logger.info("Imported \(behaviors.count) behaviors")
    }

    // MARK: - Helper Methods

    private func deleteAllData(context: NSManagedObjectContext) throws {
        let entities = ["Behavior", "Session", "Program", "Student"]

        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            try context.execute(deleteRequest)
        }

        logger.info("Deleted all existing data")
    }

    private func studentExists(id: UUID, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<Student>(entityName: "Student")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return (try? context.count(for: request)) ?? 0 > 0
    }

    private func programExists(id: UUID, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<Program>(entityName: "Program")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return (try? context.count(for: request)) ?? 0 > 0
    }

    private func sessionExists(id: UUID, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return (try? context.count(for: request)) ?? 0 > 0
    }

    private func behaviorExists(id: UUID, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<Behavior>(entityName: "Behavior")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return (try? context.count(for: request)) ?? 0 > 0
    }

    private func findStudent(id: UUID, context: NSManagedObjectContext) -> Student? {
        let request = NSFetchRequest<Student>(entityName: "Student")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    private func findProgram(id: UUID, context: NSManagedObjectContext) -> Program? {
        let request = NSFetchRequest<Program>(entityName: "Program")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    private func findSession(id: UUID, context: NSManagedObjectContext) -> Session? {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }
}

// MARK: - Import Strategy

enum ImportStrategy {
    case merge      // Keep existing data, add new data
    case replace    // Delete all existing data, import fresh
    case skip       // Skip items that already exist
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case incompatibleSchema(backup: Int, current: Int)
    case invalidJSON
    case fileNotFound
    case exportFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .incompatibleSchema(let backup, let current):
            return "Backup schema version (\(backup)) is incompatible with current version (\(current))"
        case .invalidJSON:
            return "The backup file contains invalid JSON data"
        case .fileNotFound:
            return "The backup file could not be found"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        }
    }
}
