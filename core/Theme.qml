pragma Singleton

import QtQuick

/*
 * The palette for every app in the toolchain.
 *
 * Taken from ota_update_gui, which was chosen as canonical because it was the
 * more developed of the two systems already in the codebase: accents that shift
 * between light and dark rather than one being a washed-out copy of the other,
 * and the layout tokens (controlHeight, rowHeight, headerHeight, shadowColor,
 * overlay) that the other palette had no names for at all.
 *
 * The other palette is not a variant to be merged in later. motor_recorder_gui
 * used different names for the same ideas -- `accent` for `primary`, `border`
 * for `outline`, `surfaceAlt` for `surfaceVariant`, `spacingWide` for
 * `spacingLoose` -- so its port is a rename sweep, and the app does change
 * appearance. That was a deliberate call, not a side effect.
 *
 * Note the hex order: Qt reads 8-digit literals as #AARRGGBB, alpha FIRST.
 * Writing them the CSS way (#RRGGBBAA) compiles fine and renders the wrong
 * colour at the wrong transparency -- the soft variants below are all of that
 * form, so they are the easiest place in the file to get it wrong.
 *
 * `pragma Singleton` pairs with QT_QML_SINGLETON_TYPE in CMakeLists.txt. Both
 * or neither: a mismatch is fatal at load and takes down every file that
 * imports this one, which is all of them.
 */
QtObject {
    id: theme

    /* ---------------- mode ---------------- */

    property bool dark: false

    /* ---------------- surfaces ---------------- */

    readonly property color background:     dark ? "#0F151B" : "#EFF2F6"
    readonly property color surface:        dark ? "#18212B" : "#FFFFFF"
    readonly property color surfaceVariant: dark ? "#212D39" : "#EDF1F6"
    readonly property color surfaceSunken:  dark ? "#131A22" : "#F8FAFC"
    readonly property color outline:        dark ? "#2C3A48" : "#DFE5EC"
    readonly property color overlay:        dark ? "#B0000000" : "#551B2A3A"

    /* ---------------- text ---------------- */

    readonly property color textPrimary:    dark ? "#E9EEF4" : "#16202C"
    readonly property color textSecondary:  dark ? "#9BACBD" : "#5C6C7E"
    readonly property color textDisabled:   dark ? "#5E6E7E" : "#A3AFBB"
    readonly property color textOnAccent:   "#FFFFFF"

    /* ---------------- accents ----------------
       Material palette steps, picked one shade apart between modes so both keep
       contrast against their own background. */

    readonly property color primary:        dark ? "#5CA8F0" : "#1565C0"
    readonly property color primaryHover:   dark ? "#7CBCF5" : "#0D47A1"
    readonly property color primarySoft:    dark ? "#225CA8F0" : "#141565C0"

    readonly property color success:        dark ? "#5DBE63" : "#2E7D32"
    readonly property color successSoft:    dark ? "#225DBE63" : "#142E7D32"

    readonly property color warning:        dark ? "#F0A93B" : "#B26A00"
    readonly property color warningSoft:    dark ? "#22F0A93B" : "#14B26A00"

    readonly property color danger:         dark ? "#EF5F5B" : "#C62828"
    readonly property color dangerSoft:     dark ? "#22EF5F5B" : "#14C62828"

    readonly property color neutralSoft:    dark ? "#1F9BACBD" : "#145C6C7E"

    /* Recording is its own state and reads as "live", not as an error. Carried
       over from motor_recorder_gui, which is the only app with the concept; it
       lives here so the tab bar and any future app can show it consistently. */
    readonly property color recording:      dark ? "#F2708F" : "#E0245E"
    readonly property color recordingSoft:  dark ? "#22E0245E" : "#14E0245E"

    /* ---------------- type ---------------- */

    readonly property int fontTiny:    12
    readonly property int fontSmall:   13
    readonly property int fontBody:    15
    readonly property int fontMedium:  16
    readonly property int fontLarge:   18
    readonly property int fontTitle:   22
    readonly property int fontDisplay: 26

    readonly property string monoFamily: Qt.platform.os === "windows"
        ? "Consolas" : "DejaVu Sans Mono"

    /* ---------------- metrics ---------------- */

    readonly property int radiusSmall:  8
    readonly property int radius:       12
    readonly property int radiusLarge:  16

    readonly property int spacingTight: 8
    readonly property int spacing:      16
    readonly property int spacingLoose: 24

    readonly property int controlHeight: 44
    readonly property int rowHeight:     64
    readonly property int headerHeight:  40

    /* Deliberately subtle in light mode; a heavy drop shadow on white is the
       fastest way to make a UI look dated. */
    readonly property color shadowColor: dark ? "#70000000" : "#1A0F213A"
}
