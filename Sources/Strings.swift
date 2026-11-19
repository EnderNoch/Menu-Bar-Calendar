import Foundation

/// UI text in the same 43 languages as the other Atypical Maker apps, following the system
/// language. Each row of `table` lists the strings in the order of the properties below; Open
/// and Quit carry the wording of Screen Light. The calendar's own words (Day, Week, Today,
/// No Events…) aren't here: they come from Calendar itself, see `sys`.
struct Strings {
    private let v: [String]

    /// "Open …" with the default calendar app's name in it.
    func open(_ app: String) -> String { String(format: v[0], app) }
    var quit: String { v[1] }
    /// The button that asks macOS for access to the calendars.
    var showEvents: String { v[2] }

    private static let count = 3

    static func `for`(_ code: String) -> Strings {
        let row = table[code] ?? []
        return Strings(v: row.count == count ? row : table["en"]!)
    }

    /// First of the system's preferred languages that we have.
    static var detected: String {
        for id in Locale.preferredLanguages {
            if table[id] != nil { return id }
            let lang = Locale.Language(identifier: id)
            guard let code = lang.languageCode?.identifier else { continue }
            if code == "zh" {
                let hant = lang.script?.identifier == "Hant" || ["TW", "HK", "MO"].contains(lang.region?.identifier ?? "")
                return hant ? "zh-Hant" : "zh-Hans"
            }
            if code == "no" || code == "nn" { return "nb" }
            if table[code] != nil { return code }
        }
        return "en"
    }

    static let table: [String: [String]] = [
        "en": ["Open %@", "Quit", "Show Events"],
        "pl": ["Otwórz %@", "Zakończ", "Pokaż wydarzenia"],
        "de": ["%@ öffnen", "Beenden", "Ereignisse anzeigen"],
        "fr": ["Ouvrir %@", "Quitter", "Afficher les événements"],
        "es": ["Abrir %@", "Salir", "Mostrar eventos"],
        "pt": ["Abrir %@", "Sair", "Mostrar eventos"],
        "it": ["Apri %@", "Esci", "Mostra eventi"],
        "nl": ["Open %@", "Stop", "Toon activiteiten"],
        "sv": ["Öppna %@", "Avsluta", "Visa händelser"],
        "da": ["Åbn %@", "Slut", "Vis begivenheder"],
        "nb": ["Åpne %@", "Avslutt", "Vis hendelser"],
        "fi": ["Avaa %@", "Lopeta", "Näytä tapahtumat"],
        "is": ["Opna %@", "Hætta", "Sýna atburði"],
        "cs": ["Otevřít %@", "Ukončit", "Zobrazit události"],
        "sk": ["Otvoriť %@", "Ukončiť", "Zobraziť udalosti"],
        "sl": ["Odpri %@", "Izhod", "Pokaži dogodke"],
        "hr": ["Otvori %@", "Zatvori", "Prikaži događaje"],
        "sr": ["Отвори %@", "Изађи", "Прикажи догађаје"],
        "bg": ["Отвори %@", "Изход", "Показване на събития"],
        "ro": ["Deschide %@", "Închideți aplicația", "Afișează evenimentele"],
        "hu": ["%@ megnyitása", "Kilépés", "Események megjelenítése"],
        "el": ["Άνοιγμα %@", "Τερματισμός", "Εμφάνιση γεγονότων"],
        "tr": ["%@ uygulamasını aç", "Çık", "Etkinlikleri Göster"],
        "uk": ["Відкрити %@", "Завершити", "Показати події"],
        "ru": ["Открыть %@", "Завершить", "Показать события"],
        "be": ["Адкрыць %@", "Выйсці", "Паказаць падзеі"],
        "lt": ["Atidaryti %@", "Baigti", "Rodyti įvykius"],
        "lv": ["Atvērt %@", "Iziet", "Rādīt notikumus"],
        "et": ["Ava %@", "Lõpeta", "Näita sündmusi"],
        "ca": ["Obrir %@", "Surt", "Mostra els esdeveniments"],
        "ar": ["فتح %@", "إنهاء", "عرض الأحداث"],
        "he": ["פתח את %@", "סיום", "הצג אירועים"],
        "fa": ["باز کردن %@", "خروج", "نمایش رویدادها"],
        "hi": ["%@ खोलें", "बंद करें", "इवेंट दिखाएँ"],
        "bn": ["%@ খুলুন", "বন্ধ করুন", "ইভেন্ট দেখান"],
        "th": ["เปิด %@", "ออก", "แสดงกิจกรรม"],
        "vi": ["Mở %@", "Thoát", "Hiển thị sự kiện"],
        "id": ["Buka %@", "Tutup", "Tampilkan Acara"],
        "ms": ["Buka %@", "Keluar", "Tunjukkan Acara"],
        "zh-Hans": ["打开 %@", "退出", "显示日程"],
        "zh-Hant": ["打開 %@", "結束", "顯示行程"],
        "ja": ["%@ を開く", "終了", "イベントを表示"],
        "ko": ["%@ 열기", "종료", "이벤트 보기"],
    ]
}
