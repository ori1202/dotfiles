import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.services

Scope {
	id: root

	property bool visible: false

	Connections {
		target: Audio
		function onVolumeBumped() {
			root.visible = true;
			hideTimer.restart();
		}
	}

	Timer {
		id: hideTimer
		interval: 1500
		onTriggered: root.visible = false
	}

	LazyLoader {
		active: root.visible

		PanelWindow {
			anchors.right: true
			margins.right: 28
			exclusiveZone: 0
			implicitWidth: 72
			implicitHeight: 190
			color: "transparent"
			mask: Region {}

			Rectangle {
				id: pill
				anchors.centerIn: parent
				width: 52
				height: 170
				radius: 26
				color: Theme.shellBackground
				border.width: 0

				ColumnLayout {
					anchors.fill: parent
					anchors.margins: 12
					spacing: 8

					Item {
						Layout.fillWidth: true
						Layout.fillHeight: true

						// Track with stepped segments (0–150%)
						Item {
							id: track
							anchors.horizontalCenter: parent.horizontalCenter
							anchors.top: parent.top
							anchors.bottom: parent.bottom
							width: 10

							property int steps: 16
							property real fillRatio: Math.min(1.5, Math.max(0, Audio.muted ? 0 : Audio.volume)) / 1.5
							property bool danger: Audio.overamplified

							Repeater {
								model: track.steps
								Rectangle {
									required property int index
									width: track.width
									height: Math.floor((track.height - (track.steps - 1) * 3) / track.steps)
									x: 0
									y: track.height - (index + 1) * (height + 3) + 3
									radius: 2
									readonly property real stepTop: (index + 1) / track.steps
									readonly property bool filled: track.fillRatio + 0.0001 >= stepTop
									// Danger zone starts above 100% => top third of 0–150 scale
									readonly property bool inDangerZone: stepTop > (100 / 150)
									color: {
										if (!filled)
											return inDangerZone ? Qt.rgba(194 / 255, 59 / 255, 59 / 255, 0.14)
												: Qt.rgba(232 / 255, 228 / 255, 228 / 255, 0.18);
										return track.danger ? Theme.red : Theme.shellForeground;
									}
								}
							}
						}
					}

					Text {
						Layout.alignment: Qt.AlignHCenter
						text: Audio.muted ? "󰖁" : (Audio.overamplified ? "󰕾" : "")
						color: Audio.overamplified ? Theme.red : Theme.shellForeground
						font.family: Theme.iconFontFamily
						font.pixelSize: 18
					}
				}
			}
		}
	}
}
