//
//  Student+CoreData.swift
//  BCBATracker
//
//  Core Data entity for student profiles
//  Stores minimal PII for FERPA/COPPA compliance
//

import Foundation
import CoreData

@objc(Student)
public class Student: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var firstName: String
    @NSManaged public var lastInitial: String
    @NSManaged public var grade: Int16
    @NSManaged public var teacherId: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // Relationships
    @NSManaged public var programs: NSSet?
    @NSManaged public var sessions: NSSet?

    /// Display name for UI (FirstName L.)
    var displayName: String {
        "\(firstName) \(lastInitial)."
    }

    /// Active programs for this student
    var activePrograms: [Program] {
        let programsSet = programs as? Set<Program> ?? []
        return programsSet.filter { $0.isActive }.sorted { $0.name < $1.name }
    }

    /// Recent sessions (last 30 days)
    var recentSessions: [Session] {
        let sessionsSet = sessions as? Set<Session> ?? []
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return sessionsSet.filter { $0.startTime >= thirtyDaysAgo }
            .sorted { $0.startTime > $1.startTime }
    }
}

// MARK: - Convenience Initializer
extension Student {
    /// Create a new student with required fields
    static func create(
        in context: NSManagedObjectContext,
        firstName: String,
        lastInitial: String,
        grade: Int16,
        teacherId: String? = nil
    ) -> Student {
        let student = Student(context: context)
        student.id = UUID()
        student.firstName = firstName
        student.lastInitial = lastInitial
        student.grade = grade
        student.teacherId = teacherId
        student.isActive = true
        student.createdAt = Date()
        student.updatedAt = Date()
        return student
    }
}

// MARK: - Fetch Requests
extension Student {
    /// Fetch all active students
    @nonobjc public class func fetchActiveStudents() -> NSFetchRequest<Student> {
        let request = NSFetchRequest<Student>(entityName: "Student")
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Student.firstName, ascending: true)]
        return request
    }

    /// Fetch students by teacher
    @nonobjc public class func fetchStudents(forTeacher teacherId: String) -> NSFetchRequest<Student> {
        let request = NSFetchRequest<Student>(entityName: "Student")
        request.predicate = NSPredicate(format: "isActive == %@ AND teacherId == %@",
                                      NSNumber(value: true), teacherId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Student.firstName, ascending: true)]
        return request
    }
}

// MARK: - Generated accessors for relationships
extension Student {
    @objc(addProgramsObject:)
    @NSManaged public func addToPrograms(_ value: Program)

    @objc(removeProgramsObject:)
    @NSManaged public func removeFromPrograms(_ value: Program)

    @objc(addPrograms:)
    @NSManaged public func addToPrograms(_ values: NSSet)

    @objc(removePrograms:)
    @NSManaged public func removeFromPrograms(_ values: NSSet)

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: Session)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: Session)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)
}
