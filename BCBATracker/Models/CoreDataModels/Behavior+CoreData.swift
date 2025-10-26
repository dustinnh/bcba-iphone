//
//  Behavior+CoreData.swift
//  BCBATracker
//
//  Core Data entity for individual behavior occurrences
//  Captures specific behavioral observations with timestamps
//

import Foundation
import CoreData

@objc(Behavior)
public class Behavior: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var type: String
    @NSManaged public var antecedent: String?       // For ABC data
    @NSManaged public var consequence: String?      // For ABC data
    @NSManaged public var duration: Double          // For duration recording (seconds)
    @NSManaged public var frequency: Int32          // For frequency recording
    @NSManaged public var interval: String?         // For interval recording
    @NSManaged public var promptLevel: String?      // For DTT and Task Analysis

    // Relationships
    @NSManaged public var session: Session?

    /// Behavior type enum for type safety
    public enum BehaviorType: String, CaseIterable {
        case target = "Target"          // Target behavior being worked on
        case replacement = "Replacement"  // Replacement behavior
        case interfering = "Interfering"  // Interfering/problem behavior
        case skill = "Skill"            // Skill acquisition

        var displayName: String { rawValue }
    }

    /// Prompt level enum for DTT and Task Analysis
    enum PromptLevel: String, CaseIterable {
        case independent = "Independent"
        case verbal = "Verbal"
        case gestural = "Gestural"
        case modelPhysical = "Model/Physical"
        case fullPhysical = "Full Physical"

        var displayName: String { rawValue }

        var abbreviation: String {
            switch self {
            case .independent: return "I"
            case .verbal: return "V"
            case .gestural: return "G"
            case .modelPhysical: return "M"
            case .fullPhysical: return "P"
            }
        }
    }

    /// Typed behavior type
    var behaviorType: BehaviorType {
        BehaviorType(rawValue: type) ?? .target
    }

    /// Typed prompt level
    var typedPromptLevel: PromptLevel? {
        guard let promptLevel = promptLevel else { return nil }
        return PromptLevel(rawValue: promptLevel)
    }

    /// Formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Has ABC data
    var hasABCData: Bool {
        antecedent != nil || consequence != nil
    }
}

// MARK: - Convenience Initializer
extension Behavior {
    /// Create a new behavior occurrence with required fields
    static func create(
        in context: NSManagedObjectContext,
        type: BehaviorType,
        session: Session,
        timestamp: Date = Date()
    ) -> Behavior {
        let behavior = Behavior(context: context)
        behavior.id = UUID()
        behavior.type = type.rawValue
        behavior.session = session
        behavior.timestamp = timestamp
        behavior.duration = 0
        behavior.frequency = 0
        return behavior
    }

    /// Create a frequency behavior
    static func createFrequency(
        in context: NSManagedObjectContext,
        session: Session,
        count: Int32 = 1
    ) -> Behavior {
        let behavior = create(in: context, type: .target, session: session)
        behavior.frequency = count
        return behavior
    }

    /// Create a duration behavior
    static func createDuration(
        in context: NSManagedObjectContext,
        session: Session,
        duration: TimeInterval
    ) -> Behavior {
        let behavior = create(in: context, type: .target, session: session)
        behavior.duration = duration
        return behavior
    }

    /// Create an ABC behavior
    static func createABC(
        in context: NSManagedObjectContext,
        session: Session,
        type: BehaviorType,
        antecedent: String? = nil,
        consequence: String? = nil
    ) -> Behavior {
        let behavior = create(in: context, type: type, session: session)
        behavior.antecedent = antecedent
        behavior.consequence = consequence
        return behavior
    }

    /// Create an interval behavior
    static func createInterval(
        in context: NSManagedObjectContext,
        session: Session,
        interval: String
    ) -> Behavior {
        let behavior = create(in: context, type: .target, session: session)
        behavior.interval = interval
        return behavior
    }

    /// Create a DTT behavior with prompt level
    static func createDTT(
        in context: NSManagedObjectContext,
        session: Session,
        promptLevel: PromptLevel
    ) -> Behavior {
        let behavior = create(in: context, type: .skill, session: session)
        behavior.promptLevel = promptLevel.rawValue
        return behavior
    }
}

// MARK: - Fetch Requests
extension Behavior {
    /// Fetch all behaviors
    @nonobjc public class func fetchAllBehaviors() -> NSFetchRequest<Behavior> {
        let request = NSFetchRequest<Behavior>(entityName: "Behavior")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Behavior.timestamp, ascending: false)]
        return request
    }

    /// Fetch behaviors for a specific session
    @nonobjc public class func fetchBehaviors(forSession sessionId: UUID) -> NSFetchRequest<Behavior> {
        let request = NSFetchRequest<Behavior>(entityName: "Behavior")
        request.predicate = NSPredicate(format: "session.id == %@", sessionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Behavior.timestamp, ascending: true)]
        return request
    }

    /// Fetch behaviors by type
    @nonobjc public class func fetchBehaviors(ofType type: BehaviorType) -> NSFetchRequest<Behavior> {
        let request = NSFetchRequest<Behavior>(entityName: "Behavior")
        request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Behavior.timestamp, ascending: false)]
        return request
    }

    /// Fetch behaviors within a date range
    @nonobjc public class func fetchBehaviors(from startDate: Date, to endDate: Date) -> NSFetchRequest<Behavior> {
        let request = NSFetchRequest<Behavior>(entityName: "Behavior")
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                      startDate as CVarArg, endDate as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Behavior.timestamp, ascending: false)]
        return request
    }
}
