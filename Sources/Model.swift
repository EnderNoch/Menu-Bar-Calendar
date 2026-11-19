import Observation
import SwiftUI

/// The four views of the system's Calendar, in its order (⌘1 to ⌘4 there and here).
enum Scope: Int, CaseIterable, Identifiable {
    case day, week, month, year
    var id: Self { self }

    var name: String {
        switch self {
        case .day: sys("Day")
        case .week: sys("Week")
        case .month: sys("Month")
        case .year: sys("Year")
        }
    }

    /// What one step of the arrows moves by.
    var unit: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

/// Text that Calendar itself shows (Day, Week, Today, No Events…), read from its bundle in the
/// system language, so it is worded exactly like Calendar's.
func sys(_ key: String) -> String {
    guard let bundle = calendarApp else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil, localizations: calendarLanguages)
}

private let calendarApp = Bundle(url: URL(fileURLWithPath: "/System/Applications/Calendar.app"))
private let calendarLanguages = Bundle.preferredLocalizations(
    from: calendarApp?.localizations ?? [], forPreferences: Locale.preferredLanguages
).map { Locale.Language(identifier: $0) }

@Observable
final class Model {
    static let shared = Model()

    /// The view chosen last, kept between launches.
    var scope: Scope {
        didSet { UserDefaults.standard.set(scope.rawValue, forKey: "scope") }
    }
    /// The day, week, month or year on screen: any day inside it.
    private(set) var date = Date()
    /// How the last change moves the page: a new view fades in, the next or previous period
    /// slides in from its side, like Calendar's pages.
    private(set) var motion = Motion.fade

    enum Motion { case fade, forward, back }
    /// Changes at midnight, so the circle moves on while the app keeps running.
    private(set) var today = Date()

    let s = Strings.for(Strings.detected)

    /// Calendar's settings, read again each time the panel opens.
    private(set) var settings = CalendarSettings.read()
    private(set) var calendar = CalendarSettings.read().calendar

    func refreshSettings() {
        let now = CalendarSettings.read()
        guard now != settings else { return }
        settings = now
        calendar = now.calendar
    }

    private init() {
        scope = (UserDefaults.standard.object(forKey: "scope") as? Int).flatMap(Scope.init) ?? .month
    }

    func start() {
        for name in [Notification.Name.NSCalendarDayChanged, NSNotification.Name.NSSystemTimeZoneDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { Model.shared.today = Date() }
            }
        }
    }

    /// The page on screen: its view and the start of its period. When it changes, the page
    /// moves.
    var page: Page { Page(scope: scope, start: cal.dateInterval(of: scope.unit, for: date)!.start) }

    struct Page: Hashable {
        let scope: Scope
        let start: Date
    }

    private static let animation = Animation.snappy(duration: 0.3)

    func step(_ n: Int) {
        go(to: cal.date(byAdding: scope.unit, value: n, to: date) ?? date)
    }

    /// The Today button and ⌘T slide to today; opening the panel just starts there.
    func goToday(animated: Bool = true) {
        today = Date()
        if animated { go(to: today) } else { motion = .fade; date = today }
    }

    /// A click on a day, a week number or a month's name: that day, week or month in its own
    /// view.
    func show(_ day: Date, in scope: Scope) {
        motion = .fade
        withAnimation(Self.animation) {
            date = day
            self.scope = scope
        }
    }

    /// The view picker and ⌘1 to ⌘4.
    func switchTo(_ scope: Scope) {
        guard scope != self.scope else { return }
        motion = .fade
        withAnimation(Self.animation) { self.scope = scope }
    }

    private func go(to day: Date) {
        if !cal.isDate(day, equalTo: date, toGranularity: scope.unit) {
            motion = day > date ? .forward : .back
        }
        withAnimation(Self.animation) { date = day }
    }

    /// The title above the calendar, in the system's date format.
    var title: String {
        switch scope {
        case .day:
            return date.formatted(dateStyle.weekday(.wide).day().month(.wide).year())
        case .week:
            let week = cal.dateInterval(of: .weekOfYear, for: date)!
            let f = DateIntervalFormatter(date: .medium, time: .none)
            let range = f.string(from: week.start, to: week.end.addingTimeInterval(-1))
            return String(format: sys("%@, Week %@"), range, "\(cal.component(.weekOfYear, from: date))")
        case .month:
            return date.formatted(dateStyle.month(.wide).year())
        case .year:
            return date.formatted(dateStyle.year())
        }
    }
}

/// The 42 days, six full weeks, that a month's page shows: from the start of the week holding
/// the 1st, like Calendar's month view.
func monthPage(_ month: Date) -> [Date] {
    let first = cal.dateInterval(of: .month, for: month)!.start
    let start = cal.dateInterval(of: .weekOfYear, for: first)!.start
    return (0..<42).map { cal.date(byAdding: .day, value: $0, to: start)! }
}

/// The seven days of the week holding the date.
func weekDays(_ date: Date) -> [Date] {
    let start = cal.dateInterval(of: .weekOfYear, for: date)!.start
    return (0..<7).map { cal.date(byAdding: .day, value: $0, to: start)! }
}

/// Weekday letters in the order of the system's first day of the week.
func weekdaySymbols(_ symbols: [String]) -> [String] {
    let first = cal.firstWeekday - 1
    return Array(symbols[first...] + symbols[..<first])
}
