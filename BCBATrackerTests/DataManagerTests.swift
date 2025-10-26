//
//  DataManagerTests.swift
//  BCBATrackerTests
//
//  Unit tests for DataManager
//

import XCTest
import CoreData
@testable import BCBATracker

@MainActor
final class DataManagerTests: XCTestCase {

    var dataManager: DataManager!
    var testContext: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory persistent store for testing
        dataManager = DataManager.shared

        // Create a test context
        testContext = dataManager.newBackgroundContext()
        testContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    override func tearDownWithError() throws {
        // Clean up
        testContext = nil
        dataManager = nil

        try super.tearDownWithError()
    }

    // MARK: - Student Tests

    func testCreateStudent() async throws {
        // Given
        let firstName = "John"
        let lastInitial = "D"
        let grade: Int16 = 5

        // When
        await MainActor.run {
            let student = dataManager.createStudent(
                firstName: firstName,
                lastInitial: lastInitial,
                grade: grade
            )

            // Then
            XCTAssertNotNil(student)
            XCTAssertEqual(student.firstName, firstName)
            XCTAssertEqual(student.lastInitial, lastInitial)
            XCTAssertEqual(student.grade, grade)
            XCTAssertTrue(student.isActive)
            XCTAssertNotNil(student.id)
        }
    }

    func testSoftDeleteStudent() async throws {
        // Given
        await MainActor.run {
            let student = dataManager.createStudent(
                firstName: "Jane",
                lastInitial: "S",
                grade: 3
            )

            // When
            dataManager.deleteStudent(student)

            // Then
            XCTAssertFalse(student.isActive)
        }
    }

    func testFetchActiveStudents() async throws {
        // Given
        await MainActor.run {
            _ = dataManager.createStudent(firstName: "Alice", lastInitial: "A", grade: 1)
            _ = dataManager.createStudent(firstName: "Bob", lastInitial: "B", grade: 2)
            let student3 = dataManager.createStudent(firstName: "Charlie", lastInitial: "C", grade: 3)

            // Soft delete one student
            dataManager.deleteStudent(student3)

            // When
            let activeStudents = dataManager.fetchActiveStudents()

            // Then
            XCTAssertEqual(activeStudents.count, 2)
            XCTAssertTrue(activeStudents.allSatisfy { $0.isActive })
        }
    }

    // MARK: - Session Tests

    func testCreateSession() async throws {
        await MainActor.run {
            // Given
            let student = dataManager.createStudent(
                firstName: "Test",
                lastInitial: "T",
                grade: 1
            )

            // When
            let session = dataManager.createSession(
                type: .frequency,
                student: student,
                location: "Classroom"
            )

            // Then
            XCTAssertNotNil(session)
            XCTAssertEqual(session.type, Session.SessionType.frequency.rawValue)
            XCTAssertEqual(session.student, student)
            XCTAssertEqual(session.location, "Classroom")
            XCTAssertNil(session.endTime)
            XCTAssertTrue(session.isActive)
        }
    }

    func testEndSession() async throws {
        await MainActor.run {
            // Given
            let student = dataManager.createStudent(
                firstName: "Test",
                lastInitial: "T",
                grade: 1
            )
            let session = dataManager.createSession(
                type: .frequency,
                student: student
            )

            // When
            dataManager.endSession(session)

            // Then
            XCTAssertNotNil(session.endTime)
            XCTAssertFalse(session.isActive)
            XCTAssertNotNil(session.duration)
            XCTAssertGreaterThanOrEqual(session.duration ?? 0, 0)
        }
    }

    // MARK: - Behavior Tests

    func testRecordFrequencyBehavior() async throws {
        await MainActor.run {
            // Given
            let student = dataManager.createStudent(
                firstName: "Test",
                lastInitial: "T",
                grade: 1
            )
            let session = dataManager.createSession(
                type: .frequency,
                student: student
            )

            // When
            let behavior = dataManager.recordFrequency(session: session, count: 5)

            // Then
            XCTAssertNotNil(behavior)
            XCTAssertEqual(behavior.frequency, 5)
            XCTAssertEqual(behavior.session, session)
        }
    }

    func testRecordDurationBehavior() async throws {
        await MainActor.run {
            // Given
            let student = dataManager.createStudent(
                firstName: "Test",
                lastInitial: "T",
                grade: 1
            )
            let session = dataManager.createSession(
                type: .duration,
                student: student
            )
            let duration: TimeInterval = 120 // 2 minutes

            // When
            let behavior = dataManager.recordDuration(session: session, duration: duration)

            // Then
            XCTAssertNotNil(behavior)
            XCTAssertEqual(behavior.duration, duration)
            XCTAssertEqual(behavior.session, session)
        }
    }

    func testRecordABCBehavior() async throws {
        await MainActor.run {
            // Given
            let student = dataManager.createStudent(
                firstName: "Test",
                lastInitial: "T",
                grade: 1
            )
            let session = dataManager.createSession(
                type: .abc,
                student: student
            )

            // When
            let behavior = dataManager.recordABC(
                session: session,
                type: .interfering,
                antecedent: "Asked to complete task",
                consequence: "Redirected to task"
            )

            // Then
            XCTAssertNotNil(behavior)
            XCTAssertEqual(behavior.type, Behavior.BehaviorType.interfering.rawValue)
            XCTAssertEqual(behavior.antecedent, "Asked to complete task")
            XCTAssertEqual(behavior.consequence, "Redirected to task")
            XCTAssertTrue(behavior.hasABCData)
        }
    }

    // MARK: - Performance Tests

    func testBulkStudentCreationPerformance() {
        measure {
            Task { @MainActor in
                for i in 0..<100 {
                    _ = dataManager.createStudent(
                        firstName: "Student\(i)",
                        lastInitial: "S",
                        grade: Int16(i % 12 + 1)
                    )
                }
            }
        }
    }
}
