#!/bin/bash
# Builds "Menu Bar Calendar.app" from Sources/ and installs it in /Applications.
# Also refreshes Menu-Bar-Calendar.zip, the download linked from the README.
set -euo pipefail
cd "$(dirname "$0")"

APP="Menu Bar Calendar.app"
ID="atyp.makers.menubarcalendar"
# The About window's signature, like the system's own "Copyright © … Apple Inc. All rights
# reserved.", with the author in place of Apple.
AUTHOR="EnderNoch (Atypical Maker)"
SINCE=2026
YEARS="$SINCE"; [ "$(date +%Y)" != "$SINCE" ] && YEARS="$SINCE–$(date +%Y)"
COPYRIGHT="Copyright © $YEARS $AUTHOR. All rights reserved."
# Why the app asks for the calendars, shown in the system's question; Polish below, the other
# languages keep the English one.
USAGE_EN="Your events appear under the days in the calendar in the menu bar. Nothing is changed or sent anywhere."
USAGE_PL="Twoje wydarzenia pojawiają się pod dniami w kalendarzu na pasku menu. Nic nie jest zmieniane ani nigdzie wysyłane."

echo "› compiling"
rm -rf "$APP" Menu-Bar-Calendar.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -default-isolation MainActor \
	-target arm64-apple-macos26.0 \
	Sources/*.swift -o "$APP/Contents/MacOS/MenuBarCalendar"

# The icon is layered like the system's own (MenuBarCalendar.icon, from Icon Composer): macOS
# lays its glass over it and follows the icon style set in System Settings → Appearance.
# actool builds Assets.car from it, plus MenuBarCalendar.icns for older places. It remembers
# icons by file path and misses edited layers at the same path, so it gets a fresh copy.
echo "› icon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R MenuBarCalendar.icon "$TMP/MenuBarCalendar.icon"
xcrun actool "$TMP/MenuBarCalendar.icon" --compile "$PWD/$APP/Contents/Resources" \
	--platform macosx --minimum-deployment-target 26.0 --app-icon MenuBarCalendar \
	--output-partial-info-plist "$TMP/icon.plist" >/dev/null

echo "› Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Menu Bar Calendar</string>
	<key>CFBundleDisplayName</key><string>Menu Bar Calendar</string>
	<key>LSHasLocalizedDisplayName</key><true/>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>MenuBarCalendar</string>
	<key>CFBundleIconFile</key><string>MenuBarCalendar</string>
	<key>CFBundleIconName</key><string>MenuBarCalendar</string>
	<key>CFBundleIdentifier</key><string>$ID</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.1</string>
	<key>CFBundleVersion</key><string>2</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
	<key>NSHighResolutionCapable</key><true/>
	<!-- menu bar only: no Dock icon, no window -->
	<key>LSUIElement</key><true/>
	<key>NSHumanReadableCopyright</key><string>$COPYRIGHT</string>
	<key>NSCalendarsFullAccessUsageDescription</key><string>$USAGE_EN</string>
</dict>
</plist>
PLIST

# The app's name in each language, like the system's own apps: Finder, the Dock, the menu
# bar and the window title all follow the system language. The app reads its name back from
# here, so this list is the only place it is spelled out.
# The copyright line in each language comes from Photo Booth, with the author and years
# swapped in; languages macOS doesn't ship keep the English one.
BOOTH="/System/Applications/Photo Booth.app/Contents/Resources/InfoPlist.loctable"
echo "› localized names and copyright"
while IFS='|' read -r code name; do
	mkdir -p "$APP/Contents/Resources/$code.lproj"
	case "$code" in nb) sys=no;; pt) sys=pt_PT;; zh-Hans) sys=zh_CN;; zh-Hant) sys=zh_TW;; *) sys="$code";; esac
	line="$(plutil -extract "$sys.NSHumanReadableCopyright" raw -o - "$BOOTH" 2>/dev/null)" || line="$COPYRIGHT"
	# Apple writes "Apple Inc." with a no-break space in some languages and wraps it in
	# direction marks in Hebrew; perl understands both, the marks stay where they are.
	line="$(printf '%s' "$line" | YEARS="$YEARS" AUTHOR="$AUTHOR" perl -CSDA -pe \
		's/\d{4}(?:\x{2013}\d{4})?([\s\x{200F}\x{2068}]*)Apple[\s\x{00A0}]Inc\./$ENV{YEARS}$1$ENV{AUTHOR}./; s/\.(\x{2069})\./$1./')"
	line="${line//\"/\\\"}"
	printf '"CFBundleName" = "%s";\n"CFBundleDisplayName" = "%s";\n"NSHumanReadableCopyright" = "%s";\n' \
		"$name" "$name" "$line" > "$APP/Contents/Resources/$code.lproj/InfoPlist.strings"
	case "$code" in en) usage="$USAGE_EN";; pl) usage="$USAGE_PL";; *) usage="";; esac
	if [ -n "$usage" ]; then
		printf '"NSCalendarsFullAccessUsageDescription" = "%s";\n' "$usage" \
			>> "$APP/Contents/Resources/$code.lproj/InfoPlist.strings"
	fi
done <<'NAMES'
en|Menu Bar Calendar
pl|Kalendarz na pasku menu
de|Menüleisten-Kalender
fr|Calendrier de la barre des menus
es|Calendario de la barra de menús
pt|Calendário da barra de menus
it|Calendario nella barra dei menu
nl|Menubalkkalender
sv|Menyradskalender
da|Menulinjekalender
nb|Menylinjekalender
fi|Valikkorivin kalenteri
is|Dagatal á valmyndastiku
cs|Kalendář v řádku nabídek
sk|Kalendár v lište ponúk
sl|Koledar v menijski vrstici
hr|Kalendar u traci izbornika
sr|Календар у траци менија
bg|Календар в лентата с менюта
ro|Calendar în bara de meniu
hu|Menüsori naptár
el|Ημερολόγιο γραμμής μενού
tr|Menü Çubuğu Takvimi
uk|Календар у рядку меню
ru|Календарь в строке меню
be|Каляндар у радку меню
lt|Meniu juostos kalendorius
lv|Izvēļņu joslas kalendārs
et|Menüüriba kalender
ca|Calendari de la barra de menús
ar|تقويم شريط القوائم
he|לוח שנה בשורת התפריטים
fa|تقویم نوار منو
hi|मेनू बार कैलेंडर
bn|মেনু বার ক্যালেন্ডার
th|ปฏิทินแถบเมนู
vi|Lịch trên thanh menu
id|Kalender Bar Menu
ms|Kalendar Bar Menu
zh-Hans|菜单栏日历
zh-Hant|選單列行事曆
ja|メニューバーカレンダー
ko|메뉴 막대 캘린더
NAMES

echo "› signing ad-hoc"
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" Menu-Bar-Calendar.zip

RUNNING=0
if pgrep -x MenuBarCalendar >/dev/null; then
	RUNNING=1
	echo "› quitting the running copy"
	osascript -e "if application id \"$ID\" is running then tell application id \"$ID\" to quit" 2>/dev/null || true
	sleep 1
fi

echo "› installing in /Applications"
rm -rf "/Applications/$APP"
ditto "$APP" "/Applications/$APP"
# refresh the icon cache, otherwise Finder keeps the old one
touch "/Applications/$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP" || true
# a copy that was running comes back as the new version, like a restart
if [ "$RUNNING" = 1 ]; then
	echo "› reopening"
	open -g "/Applications/$APP"
fi
echo "› done: /Applications/$APP"
