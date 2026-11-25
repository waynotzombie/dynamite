import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "."

PanelWindow {
    id: root
    anchors {
        top: true
        right: true
        left: true
    }
    implicitWidth: 80
    implicitHeight: 460
    exclusiveZone: 27
    visible: true

    IpcHandler {
        target: "wallpaperCarousel"

        function toggle(): void {
            clock.wallpaperExpanded = !clock.wallpaperExpanded
            if (clock.wallpaperExpanded) {
                clock.expanded = false
                clock.controlCenterExpanded = false
            }
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            clock.controlCenterExpanded = !clock.controlCenterExpanded
            if (clock.controlCenterExpanded) {
                clock.expanded = false
                clock.wallpaperExpanded = false
            }
        }
        function show(): void {
            clock.controlCenterExpanded = true
            clock.expanded = false
            clock.wallpaperExpanded = false
        }
        function hide(): void {
            clock.controlCenterExpanded = false
        }
    }

    mask: Region {
        Region {
            item: clock
        }
    }

    color: "transparent"

    Theme {
        id: theme
    }

    Clock {
        id: clock
        palette: theme
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 5
        z: 2

        onExpandedChanged: {
            if (expanded) {
                wallpaperExpanded = false
                controlCenterExpanded = false
            }
        }

        onWallpaperRequested: {
            wallpaperExpanded = !wallpaperExpanded
            if (wallpaperExpanded) {
                expanded = false
                controlCenterExpanded = false
            }
        }

        onControlCenterRequested: {
            controlCenterExpanded = !controlCenterExpanded
            if (controlCenterExpanded) {
                expanded = false
                wallpaperExpanded = false
            }
        }
    }
}
