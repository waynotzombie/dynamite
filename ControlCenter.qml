import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import "."

// Control center, embedded in the dynamic island.
// It is driven by Clock.controlCenterExpanded / the "controlcenter" IPC target
// in shell.qml, and expands in place exactly like the music popup.
Rectangle {
    id: root

    property var palette: null
    property bool open: false
    signal closeRequested()

    // ---- state -------------------------------------------------------
    property real volume: 0
    property bool muted: false

    property bool hasBrightness: true
    property real brightness: 0

    property bool wifiAvail: true
    property bool wifiOn: false
    property string wifiName: ""

    property bool btAvail: true
    property bool btOn: false

    property bool profAvail: true
    property string profile: "balanced"

    // polls are ignored for a moment after the user changes something,
    // so sliders and tiles don't snap back to a stale value
    property double volHold: 0
    property double briHold: 0

    // Media: prefer the player that is playing, but stick with the last one
    // while it is paused so the card doesn't jump to another player.
    property var activePlayer: null
    readonly property var player: activePlayer

    function pickPlayer() {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) {
                activePlayer = list[i]
                return
            }
        }
        if (activePlayer && list.indexOf(activePlayer) >= 0) return
        activePlayer = list.length > 0 ? list[0] : null
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: root.pickPlayer()
    }

    // remember the last song, so pausing or a player that clears its
    // metadata doesn't blank the card
    property string lastTitle: ""
    property string lastArtist: ""
    readonly property string curTitle: player && player.trackTitle ? player.trackTitle : ""
    readonly property string curArtist: player && player.trackArtist ? player.trackArtist : ""
    onCurTitleChanged: if (curTitle !== "") { lastTitle = curTitle; lastArtist = curArtist }
    onCurArtistChanged: if (curTitle !== "") lastArtist = curArtist
    readonly property string shownTitle: curTitle !== "" ? curTitle : (lastTitle !== "" ? lastTitle : "Nothing playing")
    readonly property string shownArtist: curTitle !== "" ? curArtist : lastArtist

    // semantic colors, exactly as project1 uses them
    readonly property color bg1: palette && palette.bg1 ? palette.bg1 : "#1F1D2E"
    readonly property color bg2: palette && palette.bg2 ? palette.bg2 : "#26233A"
    readonly property color bg3: palette && palette.bg3 ? palette.bg3 : "#2A2837"
    readonly property color bg4: palette && palette.bg4 ? palette.bg4 : "#393552"
    readonly property color fg: palette && palette.fg ? palette.fg : "#E0DEF4"
    readonly property color grey: palette && palette.grey ? palette.grey : "#6E6A86"
    readonly property color accent: palette && palette.accent ? palette.accent : "#EBBCBA"
    readonly property color yellow: palette && palette.yellow ? palette.yellow : "#F6C177"
    readonly property color red: palette && palette.red ? palette.red : "#EB6F92"

    // ---- polling -----------------------------------------------------
    function refresh() {
        volGet.running = true
        briGet.running = true
        wifiGet.running = true
        btGet.running = true
        profGet.running = true
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer { id: settle; interval: 600; onTriggered: root.refresh() }

    Process {
        id: volGet
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() < root.volHold) return
                const m = text.match(/([0-9.]+)/)
                root.volume = m ? Math.min(1, parseFloat(m[1])) : 0
                root.muted = text.indexOf("MUTED") >= 0
            }
        }
    }

    Process {
        id: briGet
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null || echo none"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",")
                if (f.length < 4) {
                    root.hasBrightness = false
                    return
                }
                root.hasBrightness = true
                if (Date.now() < root.briHold) return
                root.brightness = parseInt(f[3]) / 100
            }
        }
    }

    Process {
        id: wifiGet
        command: ["sh", "-c", [
            "command -v nmcli >/dev/null 2>&1 || { echo none; exit 0; }",
            "nmcli -t -f WIFI g",
            "nmcli -t -f active,ssid dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1 | sed 's/\\\\:/:/g'"
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                if (l[0].trim() === "none" || l[0].trim() === "") {
                    root.wifiAvail = false
                    return
                }
                root.wifiAvail = true
                root.wifiOn = l[0].trim() === "enabled"
                root.wifiName = l.length > 1 ? l[1].trim() : ""
            }
        }
    }

    Process {
        id: btGet
        command: ["sh", "-c", [
            "command -v bluetoothctl >/dev/null 2>&1 || { echo none; exit 0; }",
            "out=$(bluetoothctl show 2>&1)",
            "echo \"$out\" | grep -q 'No default controller' && { echo none; exit 0; }",
            "echo \"$out\" | grep -q 'Powered: yes' && echo on || echo off"
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim()
                root.btAvail = s === "on" || s === "off"
                root.btOn = s === "on"
            }
        }
    }

    Process {
        id: profGet
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo none"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                root.profAvail = p !== "" && p !== "none"
                if (root.profAvail) root.profile = p
            }
        }
    }

    // ---- actions -----------------------------------------------------
    property real pendingVol: -1
    Timer {
        id: volTimer
        interval: 50
        onTriggered: {
            if (root.pendingVol >= 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0",
                    "@DEFAULT_AUDIO_SINK@", root.pendingVol.toFixed(2)])
                root.pendingVol = -1
            }
        }
    }
    function setVolume(v) {
        volHold = Date.now() + 700
        volume = v
        pendingVol = v
        if (!volTimer.running) volTimer.start()
    }

    property real pendingBri: -1
    Timer {
        id: briTimer
        interval: 50
        onTriggered: {
            if (root.pendingBri >= 0) {
                Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set",
                    Math.max(1, Math.round(root.pendingBri * 100)) + "%"])
                root.pendingBri = -1
            }
        }
    }
    function setBrightness(v) {
        briHold = Date.now() + 700
        brightness = v
        pendingBri = v
        if (!briTimer.running) briTimer.start()
    }

    function toggleMute() {
        volHold = Date.now() + 500
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        muted = !muted
        settle.restart()
    }

    function toggleWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiOn ? "off" : "on"])
        wifiOn = !wifiOn
        settle.restart()
    }

    function toggleBt() {
        Quickshell.execDetached(["bluetoothctl", "power", btOn ? "off" : "on"])
        btOn = !btOn
        settle.restart()
    }

    function cycleProfile() {
        const order = ["power-saver", "balanced", "performance"]
        const next = order[(order.indexOf(profile) + 1) % order.length]
        Quickshell.execDetached(["powerprofilesctl", "set", next])
        profile = next
        settle.restart()
    }

    function run(cmd) {
        root.closeRequested()
        Quickshell.execDetached(cmd)
    }

    // ---- reveal ------------------------------------------------------
    // 0 = closed, 1 = open; drives the staggered section reveal.
    // The island itself is what grows/shrinks (see Clock.qml).
    property real progress: 0

    NumberAnimation {
        id: openAnim
        target: root
        property: "progress"
        to: 1
        duration: 380
        easing.type: Easing.OutQuint
    }
    NumberAnimation {
        id: closeAnim
        target: root
        property: "progress"
        to: 0
        duration: 160
    }

    onOpenChanged: {
        if (root.open) {
            closeAnim.stop()
            openAnim.restart()
        } else {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    // section i starts a little after section i-1
    function stag(i) {
        return Math.max(0, Math.min(1, (progress - i * 0.08) / 0.55))
    }

    anchors.fill: parent
    radius: 22
    color: root.bg1
    clip: true

    ColumnLayout {
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 12

        // toggles
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            opacity: root.stag(0)
            transform: Translate { y: (1 - root.stag(0)) * 10 }

            CCTile {
                palette: root.palette
                visible: root.wifiAvail
                title: "Wi-Fi"
                sub: root.wifiOn ? (root.wifiName !== "" ? root.wifiName : "On") : "Off"
                active: root.wifiOn
                onClicked: root.toggleWifi()
            }
            CCTile {
                palette: root.palette
                visible: root.btAvail
                title: "Bluetooth"
                sub: root.btOn ? "On" : "Off"
                active: root.btOn
                onClicked: root.toggleBt()
            }
            CCTile {
                palette: root.palette
                visible: root.profAvail
                title: "Power"
                sub: root.profile
                active: root.profile === "performance"
                onClicked: root.cycleProfile()
            }
        }

        // sliders
        CCSlide {
            palette: root.palette
            label: root.muted ? "Volume (muted)" : "Volume"
            value: root.volume
            fill: root.muted ? root.grey : root.accent
            opacity: root.stag(1)
            transform: Translate { y: (1 - root.stag(1)) * 10 }
            onMoved: v => root.setVolume(v)
        }
        CCSlide {
            palette: root.palette
            visible: root.hasBrightness
            label: "Brightness"
            value: root.brightness
            fill: root.yellow
            opacity: root.stag(2)
            transform: Translate { y: (1 - root.stag(2)) * 10 }
            onMoved: v => root.setBrightness(v)
        }

        // media
        Rectangle {
            id: media
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            radius: 14
            color: root.bg2
            clip: true
            opacity: root.stag(3)
            transform: Translate { y: (1 - root.stag(3)) * 10 }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                CCDisc {
                    palette: root.palette
                    spinning: root.player !== null && root.player.isPlaying
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 9
                        text: root.shownTitle
                        color: root.fg
                        font.pixelSize: 13
                        font.family: "CaskaydiaCove Nerd Font"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 9
                        Layout.bottomMargin: 4
                        text: root.shownArtist
                        color: root.grey
                        font.family: "CaskaydiaCove Nerd Font"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        spacing: 8
                        Layout.rightMargin: 18

                        CCMediaBtn {
                            palette: root.palette
                            glyph: ""
                            opacity: root.player ? 1 : 0.4
                            onClicked: {
                                if (root.player)
                                    root.player.shuffle = !root.player.shuffle
                            }
                        }
                        CCMediaBtn {
                            palette: root.palette
                            glyph: "󰒮"
                            opacity: root.player ? 1 : 0.4
                            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                        }
                        CCMediaBtn {
                            palette: root.palette
                            primary: true
                            glyph: root.player && root.player.isPlaying ? "" : ""
                            opacity: root.player ? 1 : 0.4
                            onClicked: if (root.player) root.player.togglePlaying()
                        }
                        CCMediaBtn {
                            palette: root.palette
                            glyph: "󰒭"
                            opacity: root.player ? 1 : 0.4
                            onClicked: if (root.player && root.player.canGoNext) root.player.next()
                        }
                        CCMediaBtn {
                            palette: root.palette
                            glyph: {
                                if (!root.player || !root.player.loopSupported)
                                    return ""

                                if (root.player.loopState === MprisLoopState.Track)
                                    return "↻¹"

                                return "↻"
                            }
                            opacity: root.player ? 1 : 0.4
                            onClicked: {
                                if (!root.player || !root.player.loopSupported)
                                    return

                                if (root.player.loopState === MprisLoopState.None) {
                                    root.player.loopState = MprisLoopState.Playlist
                                } else if (root.player.loopState === MprisLoopState.Playlist) {
                                    root.player.loopState = MprisLoopState.Track
                                } else {
                                    root.player.loopState = MprisLoopState.None
                                }
                            }
                        }
                    }
                }
            }
        }

        // power actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            opacity: root.stag(4)
            transform: Translate { y: (1 - root.stag(4)) * 10 }

            CCPowerBtn { palette: root.palette; label: "Lock"; onFire: root.run(["hyprlock"]) }
            CCPowerBtn { palette: root.palette; label: "Sleep"; confirm: true; onFire: root.run(["systemctl", "suspend"]) }
            CCPowerBtn { palette: root.palette; label: "Reboot"; confirm: true; onFire: root.run(["systemctl", "reboot"]) }
            CCPowerBtn { palette: root.palette; label: "Off"; confirm: true; onFire: root.run(["systemctl", "poweroff"]) }
        }
    }
}
