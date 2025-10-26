//
//  Date+Extensions.swift
//  BCBATracker
//
//  Date formatting and manipulation extensions
//

import Foundation

extension Date {

    // MARK: - Formatting

    /// Format date with specified format string
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

    /// Format as short date (MM/dd/yyyy)
    var shortDate: String {
        formatted(Constants.DateFormat.shortDate)
    }

    /// Format as full date (Monday, January 1, 2024)
    var fullDate: String {
        formatted(Constants.DateFormat.fullDate)
    }

    /// Format as time (3:45 PM)
    var time: String {
        formatted(Constants.DateFormat.time)
    }

    /// Format as date and time (01/15/2024 3:45 PM)
    var dateTime: String {
        formatted(Constants.DateFormat.dateTime)
    }

    /// Format as ISO 8601 timestamp
    var timestamp: String {
        formatted(Constants.DateFormat.timestamp)
    }

    // MARK: - Relative Formatting

    /// Format as relative time (e.g., "2 hours ago", "Just now")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format as short relative time (e.g., "2h ago", "now")
    var shortRelativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    // MARK: - Comparisons

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is this month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Check if date is this year
    var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }

    // MARK: - Components

    /// Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of day
    var endOfDay: Date {
        let startOfDay = self.startOfDay
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }

    /// Start of week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// End of week
    var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek)?.addingTimeInterval(-1) ?? self
    }

    /// Start of month
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    /// End of month
    var endOfMonth: Date {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) {
            return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? self
        }
        return self
    }

    // MARK: - Arithmetic

    /// Add days to date
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Add hours to date
    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    /// Add minutes to date
    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    /// Days between this date and another date
    func daysBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay, to: date.startOfDay)
        return abs(components.day ?? 0)
    }

    /// Hours between this date and another date
    func hoursBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: self, to: date)
        return abs(components.hour ?? 0)
    }

    /// Minutes between this date and another date
    func minutesBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: self, to: date)
        return abs(components.minute ?? 0)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Format duration as string (HH:MM:SS)
    var durationString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Format duration as short string (e.g., "2h 30m", "45s")
    var shortDurationString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        } else if minutes > 0 {
            if seconds > 0 {
                return "\(minutes)m \(seconds)s"
            }
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    /// Format as hours and minutes
    var hoursMinutes: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}
