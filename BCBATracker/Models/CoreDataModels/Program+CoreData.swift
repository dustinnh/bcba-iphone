//
//  Program+CoreData.swift
//  BCBATracker
//
//  Core Data entity for behavioral programs
//  Represents BIPs, IEP goals, FBAs, and custom programs
//

import Foundation
import CoreData

@objc(Program)
public class Program: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: String  // BIP, IEP, FBA, Custom
    @NSManaged public var targetBehaviors: [String]?
    @NSManaged public var masteryCriteria: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // Relationships
    @NSManaged public var student: Student?
    @NSManaged public var sessions: NSSet?

    /// Program type enum for type safety
    public enum ProgramType: String, CaseIterable {
        case bip = "BIP"           // Behavior Intervention Plan
        case iep = "IEP"           // Individualized Education Program
        case fba = "FBA"           // Functional Behavior Assessment
        case custom = "Custom"     // Custom program

        var displayName: String {
            switch self {
            case .bip: return "Behavior Intervention Plan"
            case .iep: return "IEP Goal"
            case .fba: return "Functional Behavior Assessment"
            case .custom: return "Custom Program"
            }
        }
    }

    /// Typed program type
    var programType: ProgramType {
        ProgramType(rawValue: type) ?? .custom
    }

    /// All sessions for this program
    var allSessions: [Session] {
        let sessionsSet = sessions as? Set<Session> ?? []
        return sessionsSet.sorted { $0.startTime > $1.startTime }
    }

    /// Number of target behaviors
    var targetCount: Int {
        targetBehaviors?.count ?? 0
    }

    /// Check if program has reached mastery
    func checkMastery() -> Bool {
        // This would implement mastery criteria checking logic
        // For now, returns false as placeholder
        return false
    }
}

// MARK: - Convenience Initializer
extension Program {
    /// Create a new program with required fields
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        type: ProgramType,
        student: Student,
        targetBehaviors: [String]? = nil,
        masteryCriteria: String? = nil
    ) -> Program {
        let program = Program(context: context)
        program.id = UUID()
        program.name = name
        program.type = type.rawValue
        program.student = student
        program.targetBehaviors = targetBehaviors
        program.masteryCriteria = masteryCriteria
        program.isActive = true
        program.createdAt = Date()
        program.updatedAt = Date()
        return program
    }
}

// MARK: - Fetch Requests
extension Program {
    /// Fetch all active programs
    @nonobjc public class func fetchActivePrograms() -> NSFetchRequest<Program> {
        let request = NSFetchRequest<Program>(entityName: "Program")
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Program.name, ascending: true)]
        return request
    }

    /// Fetch programs for a specific student
    @nonobjc public class func fetchPrograms(forStudent studentId: UUID) -> NSFetchRequest<Program> {
        let request = NSFetchRequest<Program>(entityName: "Program")
        request.predicate = NSPredicate(format: "isActive == %@ AND student.id == %@",
                                      NSNumber(value: true), studentId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Program.name, ascending: true)]
        return request
    }

    /// Fetch programs by type
    @nonobjc public class func fetchPrograms(ofType type: ProgramType) -> NSFetchRequest<Program> {
        let request = NSFetchRequest<Program>(entityName: "Program")
        request.predicate = NSPredicate(format: "isActive == %@ AND type == %@",
                                      NSNumber(value: true), type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Program.name, ascending: true)]
        return request
    }
}

// MARK: - Generated accessors for relationships
extension Program {
    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: Session)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: Session)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)
}
