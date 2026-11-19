import Foundation

/// Calendar's own settings (Calendar → Settings), read from its preferences so the panel shows
/// what Calendar shows: Start week on, Days per week, Show week numbers, Show events in year
/// view and Turn on time zone support. The app has no switches of its own for them.
struct CalendarSettings: Equatable {
    /// Calendar's Start week on as Foundation counts weekdays (1 is Sunday); nil follows the
    /// system.
    var firstWeekday: Int?
    /// 5 leaves the weekend out of the week view, as Calendar's Days per week does.
    var daysPerWeek = 7
    var weekNumbers = false
    /// Calendar's heat map in the year view; here a dot under each day with events.
    var yearEvents = false
    /// With Calendar's time zone support on, the zone chosen in its toolbar; nil is the
    /// system's.
    var timeZone: TimeZone?

    static func read() -> CalendarSettings {
        guard let prefs = UserDefaults(suiteName: "com.apple.iCal") else { return CalendarSettings() }
        var s = CalendarSettings()
        // Calendar counts from 0 for Sunday, its popup's order.
        if let first = prefs.object(forKey: "first day of week") as? Int, (0...6).contains(first) {
            s.firstWeekday = first + 1
        }
        if prefs.integer(forKey: "n days of week") == 5 { s.daysPerWeek = 5 }
        s.weekNumbers = prefs.bool(forKey: "Show Week Numbers")
        s.yearEvents = prefs.bool(forKey: "Show heat map in Year View")
        if prefs.bool(forKey: "TimeZone support enabled"), let id = prefs.string(forKey: "lastViewsTimeZone") {
            s.timeZone = TimeZone(identifier: id)
        }
        return s
    }

    /// The system's calendar, with Calendar's first day of the week.
    var calendar: Calendar {
        var c = Calendar.autoupdatingCurrent
        if let firstWeekday { c.firstWeekday = firstWeekday }
        if let timeZone { c.timeZone = timeZone }
        return c
    }
}

/// Dates written out in the system's language and format, in the calendar's time zone.
var dateStyle: Date.FormatStyle { Date.FormatStyle(calendar: cal, timeZone: cal.timeZone) }

extension DateIntervalFormatter {
    /// A range in the system's format, in the calendar's time zone.
    convenience init(date: DateIntervalFormatter.Style, time: DateIntervalFormatter.Style) {
        self.init()
        dateStyle = date
        timeStyle = time
        calendar = cal
        timeZone = cal.timeZone
    }
}
