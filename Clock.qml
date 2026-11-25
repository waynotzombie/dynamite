import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import "."

Rectangle {
    id: root

    property var palette: null
    property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying)
            ?? players.find(p => (p.identity || "").toLowerCase().includes("cmus"))
            ?? players[0]
            ?? null
    }

    property bool expanded: false
    property bool wallpaperExpanded: false
    property bool controlCenterExpanded: false
    property bool hovered: false
    property bool wallpaperIconClicked: false
    property bool controlCenterIconClicked: false
    signal wallpaperRequested()
    signal controlCenterRequested()
    property string time: Qt.formatTime(new Date(), "hh:mm")
    property real trackPosition: root.player ? root.player.position : 0

    readonly property bool playing: root.player !== null && root.player.isPlaying
    readonly property color base: palette ? palette.bg1 : "#3c3836"
    readonly property color soft: palette ? palette.bg2 : "#504945"
    readonly property color stroke: palette ? palette.bg3 : "#665c54"
    readonly property color fg: palette ? palette.fg : "#ebdbb2"
    readonly property color muted: palette ? palette.grey1 : "#bdae93"
    readonly property color accent: palette ? palette.accent : "#fe8019"

    // Keep the clock text ticking.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.time = Qt.formatTime(new Date(), "hh:mm")
    }

    // Pull MPRIS position while the popup is open.
    Timer {
        interval: 100
        repeat: true
        running: root.expanded
            && root.player !== null
            && root.player.playbackState === MprisPlaybackState.Playing

        onTriggered: {
            root.player.positionChanged()
            root.trackPosition = root.player.position
        }
    }

    HoverHandler {
        onHoveredChanged: root.hovered = hovered
    }

    Timer {
        id: clearWallpaperClick
        interval: 80
        onTriggered: root.wallpaperIconClicked = false
    }

    Timer {
        id: clearControlCenterClick
        interval: 80
        onTriggered: root.controlCenterIconClicked = false
    }

    implicitWidth: root.wallpaperExpanded
        ? 720
        : (root.controlCenterExpanded
            ? 360
            : (root.expanded
                ? 250
                : (root.player ? (root.playing ? 156 : 132) : 108)))
    implicitHeight: root.wallpaperExpanded
        ? 240
        : (root.controlCenterExpanded ? 420 : (root.expanded ? 175 : 26))

    color: root.base
    radius: (root.wallpaperExpanded || root.controlCenterExpanded)
        ? 22
        : (root.expanded ? 28 : height / 2)

    layer.enabled: true
    layer.effect: DropShadow {
        anchors.fill: root
        source: root

        horizontalOffset: 0
        verticalOffset: 0
        radius: 13
        samples: 16
        color: "#30000000"
        spread: 0.50
        transparentBorder: true
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 390
            easing.type: Easing.OutQuint
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 390
            easing.type: Easing.OutQuint
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: 390
            easing.type: Easing.OutQuint
        }
    }

    // Background click area: stays behind the popup content.
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: {
            if (root.wallpaperIconClicked || root.controlCenterIconClicked)
                return
            if (root.wallpaperExpanded) {
                root.wallpaperExpanded = false
                return
            }
            if (root.controlCenterExpanded) {
                root.controlCenterExpanded = false
                return
            }
            root.expanded = !root.expanded
        }
        cursorShape: Qt.PointingHandCursor
    }

    // Collapsed pill: time + music state.
    Row {
        anchors.centerIn: parent
        spacing: 8
        visible: !root.expanded && !root.wallpaperExpanded && !root.controlCenterExpanded
        z: 1

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.time
            color: root.fg
            font.family: "CaskaydiaCove Nerd Font"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: wallpaperMouse.hovered
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                color: wallpaperMouse.hovered ? root.accent : root.muted
                font.family: "CaskaydiaCove Nerd Font"
                font.pixelSize: 12
            }

            MouseArea {
                id: wallpaperMouse
                anchors.fill: parent
                z: 2
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    mouse.accepted = true
                    root.wallpaperIconClicked = true
                    clearWallpaperClick.restart()
                    root.wallpaperRequested()
                }
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: controlCenterMouse.hovered
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: ""
                color: controlCenterMouse.hovered ? root.accent : root.muted
                font.family: "CaskaydiaCove Nerd Font"
                font.pixelSize: 12
            }

            MouseArea {
                id: controlCenterMouse
                anchors.fill: parent
                z: 2
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    mouse.accepted = true
                    root.controlCenterIconClicked = true
                    clearControlCenterClick.restart()
                    root.controlCenterRequested()
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: root.accent
            font.family: "CaskaydiaCove Nerd Font"
            font.pixelSize: 13
            visible: root.player !== null
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: root.playing

            Repeater {
                model: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 5
                    radius: 1
                    color: root.accent

                    NumberAnimation on height {
                        from: 3
                        to: 11
                        duration: 420 + index * 110
                        loops: Animation.Infinite
                        easing.type: Easing.InOutSine
                        running: root.playing && !root.expanded
                    }
                }
            }
        }
    }

    // Expanded content.
    ColumnLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 12
            leftMargin: 12
            rightMargin: 12
        }

        z: 1
        spacing: 10
        visible: root.expanded && !root.wallpaperExpanded && !root.controlCenterExpanded

        // Album art and track information.
        RowLayout {
            Layout.fillWidth: true
            spacing: 11

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 11
                color: root.soft
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.accent
                    font.pixelSize: 25
                    visible: !root.player
                        || !root.player.trackArtUrl
                        || art.status !== Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: root.player
                        ? (root.player.trackTitle || "Unknown title")
                        : "Nothing playing"
                    color: root.fg
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player
                        ? (root.player.trackArtist || "Unknown artist")
                        : "No media player"
                    color: root.accent
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        // Seek bar.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Item {
                id: seekTrack

                Layout.fillWidth: true
                Layout.preferredHeight: 18

                readonly property real fraction: root.player && root.player.length > 0
                    ? Math.max(0, Math.min(1, root.trackPosition / root.player.length))
                    : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: root.stroke
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: seekTrack.width * seekTrack.fraction
                    height: 4
                    radius: 2

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.darker(root.accent, 1.25)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.lighter(root.accent, 1.12)
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(
                        0,
                        Math.min(
                            seekTrack.width - width,
                            seekTrack.width * seekTrack.fraction - width / 2
                        )
                    )
                    width: 12
                    height: 12
                    radius: 6
                    color: root.accent
                }

                MouseArea {
                    anchors.fill: parent
                    z: 10
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor

                    function seek(mouseX) {
                        if (!root.player || !root.player.canSeek
                            || root.player.length <= 0)
                            return

                        const fraction = Math.max(0, Math.min(1, mouseX / width))
                        const position = fraction * root.player.length

                        root.trackPosition = position
                        root.player.position = position
                    }

                    onPressed: mouse => seek(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed)
                            seek(mouse.x)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: Qt.formatTime(new Date(root.trackPosition * 1000), "m:ss")
                    color: root.muted
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.player
                        ? Qt.formatTime(new Date(root.player.length * 1000), "m:ss")
                        : "0:00"
                    color: root.muted
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 10
                }
            }
        }

        // Playback controls.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 24
                visible: root.player && root.player.shuffleSupported

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: shuffleHover.hovered ? root.soft : root.base

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰒟"
                    color: root.player && root.player.shuffle
                        ? root.accent : root.fg
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 14
                }

                HoverHandler {
                    id: shuffleHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (root.player && root.player.shuffleSupported)
                            root.player.shuffle = !root.player.shuffle
                    }
                }
            }

            Item {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 24

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: prevHover.hovered ? root.soft : root.base

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.player ? root.fg : root.muted
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 15
                }

                HoverHandler {
                    id: prevHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: 12

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.lighter(root.accent, 1.15)
                        }
                        GradientStop {
                            position: 1
                            color: root.accent
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.player && root.player.isPlaying ? "" : ""
                    color: "#1a1512"
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 15
                    z: 1
                }

                HoverHandler {
                    id: playHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (root.player && root.player.canTogglePlaying)
                            root.player.togglePlaying()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 24

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: nextHover.hovered ? root.soft : root.base

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.player ? root.fg : root.muted
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 15
                }

                HoverHandler {
                    id: nextHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (root.player && root.player.canGoNext)
                            root.player.next()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 24
                visible: root.player && root.player.loopSupported

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: loopHover.hovered ? root.soft : root.base

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (!root.player || !root.player.loopSupported)
                            return ""

                        if (root.player.loopState === MprisLoopState.Track)
                            return "↻¹"

                        return "↻"
                    }
                    color: !root.player
                        || root.player.loopState === MprisLoopState.None
                        ? root.fg : root.accent
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 14
                }

                HoverHandler {
                    id: loopHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
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

    WallpaperCarousel {
        id: wallpaperCarousel
        palette: root.palette
        anchors.fill: parent
        z: 1
        visible: root.wallpaperExpanded
        onCloseRequested: root.wallpaperExpanded = false
    }

    ControlCenter {
        id: controlCenter
        palette: root.palette
        open: root.controlCenterExpanded
        anchors.fill: parent
        z: 1
        visible: root.controlCenterExpanded
        onCloseRequested: root.controlCenterExpanded = false
    }
}
