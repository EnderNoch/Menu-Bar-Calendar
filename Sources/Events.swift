import AppKit
import EventKit
import Observation
import SwiftUI

/// Events from the calendars set up in Calendar (iCloud, Google, Exchange…), read only.
/// macOS asks once for access; until it is given, the calendar shows dates without events.
@Observable
final class Events {
    static let shared = Events()

    private let store = EKEventStore()
    private(set) var status = EKEventStore.authorizationStatus(for: .event)
    /// Goes up whenever anything in the calendars changes, so what is on screen is read again.
    private var version = 0

    var allowed: Bool { status == .fullAccess }

    func start() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Events.shared.version += 1 }
        }
    }

    /// Access may have been given or taken away in System Settings while the panel was closed.
    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
    }

    /// The system's question the first time; after a No, the Calendars list in Privacy &
    /// Security, the only place where it can be changed.
    func requestAccess() {
        guard status == .notDetermined else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            return
        }
        // The panel would close behind the system's question and leave it hanging.
        NSApp.activate()
        Task {
            _ = try? await store.requestFullAccessToEvents()
            status = EKEventStore.authorizationStatus(for: .event)
            version += 1
        }
    }

    /// All-day events first, then the rest by start time, like Calendar's day view. Invitations
    /// you declined are left out, as Calendar leaves them out unless View → Show Declined
    /// Events is on.
    func events(from start: Date, to end: Date) -> [EKEvent] {
        _ = version
        guard allowed else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).filter { !$0.declinedByMe }.sorted {
            ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate)
        }
    }

    func events(on day: Date) -> [EKEvent] {
        let start = cal.startOfDay(for: day)
        return events(from: start, to: cal.date(byAdding: .day, value: 1, to: start)!)
    }

    /// For the dots under the days of a month: the colors of the calendars with an event on
    /// each day, once per calendar.
    func colors(from start: Date, to end: Date) -> [Date: [Color]] {
        var days: [Date: [String: Color]] = [:]
        for event in events(from: start, to: end) {
            var day = cal.startOfDay(for: event.startDate)
            // An event ending at midnight doesn't reach into the next day.
            let last = event.endDate.addingTimeInterval(-1)
            while day <= last, day < end {
                days[day, default: [:]][event.calendar.calendarIdentifier] = Color(nsColor: event.calendar.color)
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
        }
        return days.mapValues { Array($0.sorted { $0.key < $1.key }.map(\.value)) }
    }
}

extension EKEvent {
    /// "all-day" or "9:00–10:30", in the system's time format.
    var timeText: String {
        if isAllDay { return sys("all-day") }
        return DateIntervalFormatter(date: .none, time: .short).string(from: startDate, to: endDate)
    }

    var declinedByMe: Bool {
        attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }
}
