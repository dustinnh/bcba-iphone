//
//  DataManager.swift
//  BCBATracker
//
//  Central data management service for Core Data and CloudKit sync
//  Single source of truth for all data operations
//

import Foundation
import CoreData
import CloudKit
import Combine
import OSLog

/// Main data manager for the application
/// Handles Core Data persistence and CloudKit synchronization
@MainActor
class DataManager: ObservableObject {

    // MARK: - Singleton
    static let shared = DataManager()

    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    // MARK: - Core Data Stack

    /// Persistent container (CloudKit disabled for development)
    /// To enable CloudKit: Change to NSPersistentCloudKitContainer and configure entitlements
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BCBATracker")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        // CloudKit integration (disabled for development)
        // Uncomment when ready to enable CloudKit sync:
        /*
        // Enable persistent history tracking for CloudKit sync
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Configure CloudKit container options
        let cloudKitOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.bcba.tracker"
        )
        description.cloudKitContainerOptions = cloudKitOptions
        */

        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                Logger.dataManager.critical("Failed to load Core Data: \(error.localizedDescription)")
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }

            Logger.dataManager.info("Core Data loaded successfully: \(storeDescription.description)")
        }

        // Automatically merge changes from parent
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Set up context for UI updates
        container.viewContext.name = "viewContext"
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true

        return container
    }()

    /// Main view context for UI operations (main thread only)
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Logger
    private let logger = Logger.dataManager

    // MARK: - Initialization
    private init() {
        setupNotifications()
    }

    // MARK: - Core Data Operations

    /// Save changes to the view context
    func save() {
        let context = viewContext

        guard context.hasChanges else {
            logger.debug("No changes to save")
            return
        }

        do {
            try context.save()
            logger.info("Context saved successfully")
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
            syncError = error
        }
    }

    /// Create a new background context for non-UI operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }

    /// Perform a background task
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)
        }
    }

    // MARK: - Batch Operations

    /// Delete all data (for testing or reset)
    func deleteAllData() async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let entities = ["Student", "Program", "Session", "Behavior"]

            for entityName in entities {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs

                do {
                    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                    let changes = [NSDeletedObjectsKey: objectIDArray]

                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [self.viewContext]
                    )

                    self.logger.info("Deleted all \(entityName) entities")
                } catch {
                    self.logger.error("Failed to delete \(entityName): \(error.localizedDescription)")
                    throw error
                }
            }

            try context.save()
        }
    }

    // MARK: - CloudKit Sync

    /// Manually trigger CloudKit sync
    func syncWithCloudKit() async {
        await MainActor.run {
            isSyncing = true
        }

        logger.info("Starting manual CloudKit sync")

        // Save any pending changes first
        save()

        // CloudKit sync happens automatically with NSPersistentCloudKitContainer
        // This method is mainly for UI feedback

        // Simulate sync completion (actual sync is automatic)
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        await MainActor.run {
            isSyncing = false
            lastSyncDate = Date()
        }

        logger.info("CloudKit sync completed")
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    @objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
        logger.info("Remote changes detected from CloudKit")

        Task { @MainActor in
            lastSyncDate = Date()
        }
    }

    // MARK: - Convenience Methods

    /// Fetch all active students
    func fetchActiveStudents() -> [Student] {
        let request = Student.fetchActiveStudents()

        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch active students: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch student by ID
    func fetchStudent(id: UUID) -> Student? {
        let request = NSFetchRequest<Student>(entityName: "Student")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first
        } catch {
            logger.error("Failed to fetch student: \(error.localizedDescription)")
            return nil
        }
    }

    /// Create a new student
    func createStudent(firstName: String, lastInitial: String, grade: Int16, teacherId: String? = nil) -> Student {
        let student = Student.create(
            in: viewContext,
            firstName: firstName,
            lastInitial: lastInitial,
            grade: grade,
            teacherId: teacherId
        )
        save()
        logger.info("Created new student: \(student.displayName)")
        return student
    }

    /// Soft delete a student (set isActive = false)
    func deleteStudent(_ student: Student) {
        student.isActive = false
        student.updatedAt = Date()
        save()
        logger.info("Soft deleted student: \(student.displayName)")
    }

    /// Hard delete a student (permanent removal)
    func permanentlyDeleteStudent(_ student: Student) {
        viewContext.delete(student)
        save()
        logger.warning("Permanently deleted student: \(student.displayName)")
    }

    // MARK: - Session Management

    /// Create a new session
    func createSession(
        type: Session.SessionType,
        student: Student,
        program: Program? = nil,
        location: String? = nil
    ) -> Session {
        let session = Session.create(
            in: viewContext,
            type: type,
            student: student,
            program: program,
            location: location
        )
        save()
        logger.info("Created new \(type.rawValue) session for \(student.displayName)")
        return session
    }

    /// End an active session
    func endSession(_ session: Session) {
        session.end()
        save()
        logger.info("Ended session \(session.id)")
    }

    // MARK: - Behavior Recording

    /// Record a frequency behavior
    func recordFrequency(session: Session, count: Int32 = 1) -> Behavior {
        let behavior = Behavior.createFrequency(in: viewContext, session: session, count: count)
        save()
        logger.debug("Recorded frequency behavior")
        return behavior
    }

    /// Record a duration behavior
    func recordDuration(session: Session, duration: TimeInterval) -> Behavior {
        let behavior = Behavior.createDuration(in: viewContext, session: session, duration: duration)
        save()
        logger.debug("Recorded duration behavior: \(duration)s")
        return behavior
    }

    /// Record an ABC behavior
    func recordABC(
        session: Session,
        type: Behavior.BehaviorType,
        antecedent: String? = nil,
        consequence: String? = nil
    ) -> Behavior {
        let behavior = Behavior.createABC(
            in: viewContext,
            session: session,
            type: type,
            antecedent: antecedent,
            consequence: consequence
        )
        save()
        logger.debug("Recorded ABC behavior")
        return behavior
    }
}

// MARK: - Logger Extension
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.bcba.tracker"
    static let dataManager = Logger(subsystem: subsystem, category: "DataManager")
}
