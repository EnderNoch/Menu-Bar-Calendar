import EventKit
import SwiftUI

struct Panel: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        let s = model.s

        VStack(alignment: .leading, spacing: 12) {
            Picker(appName, selection: Binding(get: { model.scope }, set: { model.switchTo($0) })) {
                ForEach(Scope.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            // Like Calendar's toolbar: ‹ Today ›, with ← → and ⌘T.
            HStack(spacing: 6) {
                Text(model.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.interpolate)
                Spacer(minLength: 4)
                Button { model.step(-1) } label: { Image(systemName: "chevron.left") }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .accessibilityLabel(sys("Previous"))
                Button(sys("Today")) { model.goToday() }
                    .keyboardShortcut("t", modifiers: .command)
                Button { model.step(1) } label: { Image(systemName: "chevron.right") }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .accessibilityLabel(sys("Next"))
            }
            .controlSize(.small)

            // One page at a time: the next slides in over the last, clipped at the panel's edges.
            ZStack(alignment: .top) {
                Group {
                    switch model.scope {
                    case .day: DayView()
                    case .week: WeekView()
                    case .month: MonthView()
                    case .year: YearView()
                    }
                }
                .id(model.page)
                .transition(pageTransition)
            }
            .clipped()

            Divider()

            HStack {
                Button(s.open(DefaultCalendarApp.name)) { DefaultCalendarApp.open() }
                Spacer()
                Button(s.quit) { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 380)
        // ⌘1 to ⌘4 switch the view, as in Calendar.
        .background {
            ForEach(Scope.allCases) { scope in
                Button(scope.name) { model.switchTo(scope) }
                    .keyboardShortcut(KeyEquivalent(Character("\(scope.rawValue + 1)")), modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        // Each time the panel opens it starts at today, like Calendar on launch.
        .onAppear {
            model.refreshSettings()
            model.goToday(animated: false)
            events.refresh()
        }
    }

    /// With Reduce Motion on (System Settings → Accessibility → Display) pages fade instead
    /// of sliding, as Apple's own apps do.
    private var pageTransition: AnyTransition {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return .opacity }
        return switch model.motion {
        case .fade: .opacity
        case .forward: .push(from: .trailing)
        case .back: .push(from: .leading)
        }
    }
}

/// The day's number, in a filled circle of the accent color when it is today. A pressed day
/// gets the same circle, and today's turns a shade darker, so the click shows where it lands.
struct DayNumber: View {
    let day: Date
    var dimmed = false
    var size: CGFloat = 13
    var circle: CGFloat = 24
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let today = cal.isDate(day, inSameDayAs: Model.shared.today)
        let pressed = prominence == .increased
        let filled = today || pressed
        Text("\(cal.component(.day, from: day))")
            .font(.system(size: size, weight: filled ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(filled ? AnyShapeStyle(.white) : dimmed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .frame(width: circle, height: circle)
            .background {
                if filled {
                    Circle().fill(.tint)
                    if today && pressed { Circle().fill(.black.opacity(0.2)) }
                }
            }
    }
}

/// Days and week numbers as buttons: while the mouse is down they light up in the circle of
/// today's date (drawn by DayNumber and WeekNumber), and on release they open.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .environment(\.backgroundProminence, configuration.isPressed ? .increased : .standard)
    }
}

/// The week's number beside the month, as Calendar shows it with week numbers on; pressed,
/// it gets the circle too. The year view's months use a small one.
struct WeekNumber: View {
    let day: Date
    var small = false
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let pressed = prominence == .increased
        Text("\(cal.component(.weekOfYear, from: day))")
            .font(small ? .system(size: 7, weight: pressed ? .semibold : .regular)
                        : .caption2.weight(pressed ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(pressed ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
            .frame(width: small ? 12 : 20, height: small ? 12 : 20)
            .background { if pressed { Circle().fill(.tint) } }
            .frame(width: small ? 12 : 22, height: small ? 14 : 26)
    }
}

extension View {
    /// Saturday and Sunday (the weekend of the system's region) on a shaded band, as Calendar
    /// shades them in its week and month views.
    func weekend(_ on: Bool) -> some View {
        background { if on { Rectangle().fill(.fill.tertiary) } }
    }
}

// MARK: - Year

struct YearView: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        let year = cal.dateInterval(of: .year, for: model.date)!
        let start = year.start
        // A dot under days with events when Calendar shows events in its year view.
        let dots = model.settings.yearEvents && events.allowed ? events.colors(from: year.start, to: year.end) : nil
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3),
                  spacing: 12) {
            ForEach(0..<12, id: \.self) { i in
                MiniMonth(month: cal.date(byAdding: .month, value: i, to: start)!, dots: dots)
            }
        }
    }
}

/// One month of the year view: its name opens it in the month view, a day in the day view.
struct MiniMonth: View {
    let month: Date
    let dots: [Date: [Color]]?
    private let model = Model.shared

    var body: some View {
        let days = monthPage(month)
        let current = cal.isDate(month, equalTo: model.today, toGranularity: .month)
        VStack(alignment: .leading, spacing: 3) {
            Button { model.show(month, in: .month) } label: {
                Text(month.formatted(dateStyle.month(.wide)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(current ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
            .buttonStyle(.plain)

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    if model.settings.weekNumbers { Color.clear.frame(width: 1, height: 1) }
                    ForEach(Array(weekdaySymbols(cal.veryShortStandaloneWeekdaySymbols).enumerated()), id: \.offset) {
                        Text($0.element)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .weekend(cal.isDateInWeekend(days[$0.offset]))
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    GridRow(alignment: .top) {
                        // Week numbers when Calendar shows them, a click away from the week
                        // view; none beside a row that holds no day of this month.
                        if model.settings.weekNumbers {
                            if days[(row * 7)..<(row * 7 + 7)].contains(where: { cal.isDate($0, equalTo: month, toGranularity: .month) }) {
                                Button { model.show(days[row * 7], in: .week) } label: {
                                    WeekNumber(day: days[row * 7], small: true)
                                }
                                .buttonStyle(PressStyle())
                            } else {
                                Color.clear.frame(width: 12, height: 1)
                            }
                        }
                        ForEach(0..<7, id: \.self) { col in
                            let day = days[row * 7 + col]
                            Group {
                                if cal.isDate(day, equalTo: month, toGranularity: .month) {
                                    Button { model.show(day, in: .day) } label: {
                                        VStack(spacing: 0) {
                                            // Narrower beside week numbers, so three months still fit across.
                                            DayNumber(day: day, size: 9, circle: model.settings.weekNumbers ? 13.5 : 14)
                                            if let dots { Dots(colors: dots[day] ?? [], size: 2.5) }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PressStyle())
                                } else {
                                    Color.clear.frame(height: dots == nil ? 14 : 16.5)
                                }
                            }
                            // The full height of the row, so the weekend band has no gaps.
                            .frame(maxHeight: .infinity)
                            .weekend(cal.isDateInWeekend(day))
                        }
                    }
                }
            }
        }
    }
}

/// Up to three dots under a day, in the colors of the calendars with events on it.
struct Dots: View {
    let colors: [Color]
    let size: CGFloat

    var body: some View {
        HStack(spacing: size / 2) {
            ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) {
                Circle().fill($0.element).frame(width: size, height: size)
            }
        }
        .frame(height: size)
    }
}

// MARK: - Month

struct MonthView: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        let days = monthPage(model.date)
        let dots = events.colors(from: days[0], to: cal.date(byAdding: .day, value: 1, to: days[41])!)
        let weekNumbers = model.settings.weekNumbers
        // No gaps between the rows, so the weekend's shading runs down as one band.
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                if weekNumbers { Color.clear.frame(width: 1, height: 1) }
                ForEach(Array(weekdaySymbols(cal.shortStandaloneWeekdaySymbols).enumerated()), id: \.offset) {
                    Text($0.element)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .weekend(cal.isDateInWeekend(days[$0.offset]))
                }
            }
            ForEach(0..<6, id: \.self) { row in
                GridRow(alignment: .top) {
                    // Week numbers when Calendar shows them; a click opens that week.
                    if weekNumbers {
                        Button { model.show(days[row * 7], in: .week) } label: {
                            WeekNumber(day: days[row * 7])
                        }
                        .buttonStyle(PressStyle())
                        .padding(.top, 3)
                    }
                    ForEach(0..<7, id: \.self) { col in
                        let day = days[row * 7 + col]
                        Button { model.show(day, in: .day) } label: {
                            VStack(spacing: 2) {
                                DayNumber(day: day, dimmed: !cal.isDate(day, equalTo: model.date, toGranularity: .month),
                                          circle: 26)
                                Dots(colors: dots[day] ?? [], size: 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(PressStyle())
                        .weekend(cal.isDateInWeekend(day))
                    }
                }
            }
        }
    }
}

// MARK: - Week

struct WeekView: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        // Calendar's Days per week: 5 leaves the weekend out.
        let days = weekDays(model.date).filter { model.settings.daysPerWeek == 7 || !cal.isDateInWeekend($0) }
        VStack(alignment: .leading, spacing: 0) {
            if !events.allowed { AccessButton().padding(.bottom, 8) }
            ForEach(days, id: \.self) { day in
                Button { model.show(day, in: .day) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Text(day.formatted(dateStyle.weekday(.abbreviated)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            DayNumber(day: day, size: 15, circle: 28)
                        }
                        .frame(width: 40)

                        let list = events.events(on: day)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(list.prefix(3).enumerated()), id: \.offset) {
                                EventLine(event: $0.element, compact: true)
                            }
                            if list.count > 3 {
                                Text("+\(list.count - 3)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(PressStyle())
                .weekend(cal.isDateInWeekend(day))
                .padding(.horizontal, -6)
                if day != days.last { Divider() }
            }
        }
    }
}

// MARK: - Day

struct DayView: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        let list = events.events(on: model.date)
        if !events.allowed {
            AccessButton()
        } else if list.isEmpty {
            Text(sys("No Events"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            let rows = VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(list.enumerated()), id: \.offset) {
                    EventLine(event: $0.element, compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // A busy day scrolls instead of making the panel taller than the screen.
            if list.count > 8 {
                ScrollView { rows }.frame(height: 380)
            } else {
                rows
            }
        }
    }
}

/// An event with its calendar's color bar: title and time, plus the place in the day view.
struct EventLine: View {
    let event: EKEvent
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "")
                    .font(compact ? .callout : .body)
                    .lineLimit(compact ? 1 : 2)
                Text(event.timeText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if !compact, let place = event.location, !place.isEmpty {
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Until macOS has been allowed to share the calendars, the days show without events.
struct AccessButton: View {
    var body: some View {
        Button(Model.shared.s.showEvents) { Events.shared.requestAccess() }
            .frame(maxWidth: .infinity)
    }
}
