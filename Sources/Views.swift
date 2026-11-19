import EventKit
import SwiftUI

struct Panel: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        @Bindable var model = model
        let s = model.s

        VStack(alignment: .leading, spacing: 12) {
            Picker(appName, selection: $model.scope) {
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

            switch model.scope {
            case .day: DayView()
            case .week: WeekView()
            case .month: MonthView()
            case .year: YearView()
            }

            Divider()

            HStack {
                Button(s.open(DefaultCalendarApp.name)) { DefaultCalendarApp.open() }
                Spacer()
                Button(s.quit) { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 360)
        // ⌘1 to ⌘4 switch the view, as in Calendar.
        .background {
            ForEach(Scope.allCases) { scope in
                Button(scope.name) { model.scope = scope }
                    .keyboardShortcut(KeyEquivalent(Character("\(scope.rawValue + 1)")), modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        // Each time the panel opens it starts at today, like Calendar on launch.
        .onAppear {
            model.goToday()
            events.refresh()
        }
    }
}

/// The day's number, in a filled circle of the accent color when it is today.
struct DayNumber: View {
    let day: Date
    var dimmed = false
    var size: CGFloat = 13
    var circle: CGFloat = 24

    var body: some View {
        let today = cal.isDate(day, inSameDayAs: Model.shared.today)
        Text("\(cal.component(.day, from: day))")
            .font(.system(size: size, weight: today ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(today ? AnyShapeStyle(.white) : dimmed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .frame(width: circle, height: circle)
            .background { if today { Circle().fill(.tint) } }
    }
}

// MARK: - Year

struct YearView: View {
    private let model = Model.shared

    var body: some View {
        let start = cal.dateInterval(of: .year, for: model.date)!.start
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                  spacing: 12) {
            ForEach(0..<12, id: \.self) { i in
                MiniMonth(month: cal.date(byAdding: .month, value: i, to: start)!)
            }
        }
    }
}

/// One month of the year view: its name opens it in the month view, a day in the day view.
struct MiniMonth: View {
    let month: Date
    private let model = Model.shared

    var body: some View {
        let days = monthPage(month)
        let current = cal.isDate(month, equalTo: model.today, toGranularity: .month)
        VStack(alignment: .leading, spacing: 3) {
            Button { model.show(month, in: .month) } label: {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(current ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
            .buttonStyle(.plain)

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(weekdaySymbols(cal.veryShortStandaloneWeekdaySymbols).enumerated()), id: \.offset) {
                        Text($0.element)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { col in
                            let day = days[row * 7 + col]
                            if cal.isDate(day, equalTo: month, toGranularity: .month) {
                                Button { model.show(day, in: .day) } label: {
                                    DayNumber(day: day, size: 9, circle: 14)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 14)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Month

struct MonthView: View {
    private let model = Model.shared
    private let events = Events.shared

    var body: some View {
        let days = monthPage(model.date)
        let dots = events.colors(from: days[0], to: cal.date(byAdding: .day, value: 1, to: days[41])!)
        Grid(horizontalSpacing: 0, verticalSpacing: 2) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                ForEach(Array(weekdaySymbols(cal.shortStandaloneWeekdaySymbols).enumerated()), id: \.offset) {
                    Text($0.element)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<6, id: \.self) { row in
                GridRow(alignment: .top) {
                    // The week's number, as Calendar shows it with week numbers on.
                    Text("\(cal.component(.weekOfYear, from: days[row * 7]))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, height: 26)
                        .padding(.top, 2)
                    ForEach(0..<7, id: \.self) { col in
                        let day = days[row * 7 + col]
                        Button { model.show(day, in: .day) } label: {
                            VStack(spacing: 2) {
                                DayNumber(day: day, dimmed: !cal.isDate(day, equalTo: model.date, toGranularity: .month),
                                          circle: 26)
                                HStack(spacing: 2) {
                                    ForEach(Array((dots[day] ?? []).prefix(3).enumerated()), id: \.offset) {
                                        Circle().fill($0.element).frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
        let days = weekDays(model.date)
        VStack(alignment: .leading, spacing: 0) {
            if !events.allowed { AccessButton().padding(.bottom, 8) }
            ForEach(days, id: \.self) { day in
                Button { model.show(day, in: .day) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
