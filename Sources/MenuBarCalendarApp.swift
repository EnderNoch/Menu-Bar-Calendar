import ServiceManagement
import SwiftUI

/// The app's name in the system language, from the bundle (build.sh writes it there).
let appName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
    ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Menu Bar Calendar"

/// The calendar of System Settings, starting the week where Calendar's settings say.
var cal: Calendar { Model.shared.calendar }

/// Lives only in the menu bar, like the clock: no window and no Dock icon.
@main
struct MenuBarCalendarApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        // Always there; hiding it is System Settings → Menu Bar's job, and it keeps its place.
        MenuBarExtra {
            Panel()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opens at login from the first launch. Only once: switching it off is System
        // Settings → General → Login Items' job, and a later launch mustn't undo that.
        let ud = UserDefaults.standard
        if !ud.bool(forKey: "loginSetUp") {
            try? SMAppService.mainApp.register()
            ud.set(true, forKey: "loginSetUp")
        }
        Model.shared.start()
        Events.shared.start()
    }
}

/// The system's own calendar symbol. Holding ⌘ over it, or VoiceOver, reads today's date
/// alone, like the clock reads the time: the app's long name in front of it says nothing the
/// icon doesn't.
struct MenuBarLabel: View {
    private let model = Model.shared

    var body: some View {
        let date = model.today.formatted(dateStyle.weekday(.wide).day().month(.wide).year())
        // Starting with a capital, as the menu bar clock does ("Pt. 20 lis"): Polish and other
        // languages write weekdays in lower case mid-sentence.
        Image(systemName: "calendar")
            .accessibilityLabel(date.prefix(1).uppercased(with: .current) + date.dropFirst())
    }
}

/// The calendar app chosen in Calendar → Settings → General → Default calendar app. Calendar
/// stores that choice as the app for webcal: links, so that is where it is read from.
enum DefaultCalendarApp {
    static var url: URL {
        NSWorkspace.shared.urlForApplication(toOpen: URL(string: "webcal://")!)
            ?? URL(fileURLWithPath: "/System/Applications/Calendar.app")
    }

    /// Its name as Finder shows it, in the system language: "Kalendarz", "Fantastical"…
    static var name: String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    static func open() {
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
