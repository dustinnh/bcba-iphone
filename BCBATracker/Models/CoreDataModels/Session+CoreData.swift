//
//  Session+CoreData.swift
//  BCBATracker
//
//  Core Data entity for data collection sessions
//  Stores timestamped behavioral observations
//

import Foundation
import CoreData

@objc(Session)
public class Session: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var type: String
    @NSManaged public var data: Data?  // JSON encoded session-specific data
    @NSManaged public var notes: String?
    @NSManaged public var location: String?

    // Relationships
    @NSManaged public var student: Student?
    @NSManaged public var program: Program?
    @NSManaged public var behaviors: NSSet?

    /// Session type enum for type safety
    public enum SessionType: String, CaseIterable {
        case frequency = "Frequency"
        case duration = "Duration"
        case abc = "ABC"
        case interval = "Interval"
        case dtt = "DTT"          // Discrete Trial Training
        case taskAnalysis = "TaskAnalysis"

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .frequency: return "number.circle.fill"
            case .duration: return "timer"
            case .abc: return "list.bullet.clipboard"
            case .interval: return "clock.arrow.2.circlepath"
            case .dtt: return "checkmark.square.fill"
            case .taskAnalysis: return "list.number"
            }
        }
    }

    /// Typed session type
    var sessionType: SessionType {
        SessionType(rawValue: type) ?? .frequency
    }

    /// Duration of the session in seconds
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    /// Is this session currently active (not ended)
    var isActive: Bool {
        endTime == nil
    }

    /// All behaviors in this session
    var allBehaviors: [Behavior] {
        let behaviorsSet = behaviors as? Set<Behavior> ?? []
        return behaviorsSet.sorted { $0.timestamp < $1.timestamp }
    }

    /// Formatted duration string
    var formattedDuration: String {
        guard let duration = duration else { return "In Progress" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Decode JSON data into a dictionary
    func decodedData<T: Decodable>() -> T? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Encode and store session data
    func encodeData<T: Encodable>(_ object: T) throws {
        data = try JSONEncoder().encode(object)
    }
}

// MARK: - Convenience Initializer
extension Session {
    /// Create a new session with required fields
    static func create(
        in context: NSManagedObjectContext,
        type: SessionType,
        student: Student,
        program: Program? = nil,
        location: String? = nil
    ) -> Session {
        let session = Session(context: context)
        session.id = UUID()
        session.type = type.rawValue
        session.startTime = Date()
        session.student = student
        session.program = program
        session.location = location
        return session
    }

    /// End the session
    func end() {
        endTime = Date()
    }
}

// MARK: - Fetch Requests
extension Session {
    /// Fetch all sessions
    @nonobjc public class func fetchAllSessions() -> NSFetchRequest<Session> {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
        return request
    }

    /// Fetch sessions for a specific student
    @nonobjc public class func fetchSessions(forStudent studentId: UUID) -> NSFetchRequest<Session> {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.predicate = NSPredicate(format: "student.id == %@", studentId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
        return request
    }

    /// Fetch sessions by type
    @nonobjc public class func fetchSessions(ofType type: SessionType) -> NSFetchRequest<Session> {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
        return request
    }

    /// Fetch active (ongoing) sessions
    @nonobjc public class func fetchActiveSessions() -> NSFetchRequest<Session> {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.predicate = NSPredicate(format: "endTime == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
        return request
    }

    /// Fetch sessions within a date range
    @nonobjc public class func fetchSessions(from startDate: Date, to endDate: Date) -> NSFetchRequest<Session> {
        let request = NSFetchRequest<Session>(entityName: "Session")
        request.predicate = NSPredicate(format: "startTime >= %@ AND startTime <= %@",
                                      startDate as CVarArg, endDate as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Session.startTime, ascending: false)]
        return request
    }
}

// MARK: - Generated accessors for relationships
extension Session {
    @objc(addBehaviorsObject:)
    @NSManaged public func addToBehaviors(_ value: Behavior)

    @objc(removeBehaviorsObject:)
    @NSManaged public func removeFromBehaviors(_ value: Behavior)

    @objc(addBehaviors:)
    @NSManaged public func addToBehaviors(_ values: NSSet)

    @objc(removeBehaviors:)
    @NSManaged public func removeFromBehaviors(_ values: NSSet)
}
