import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import qs
import qs.components
import qs.services

Scope {
	id: root

	property bool forceVisible: false
	property bool flashDone: false

	readonly property bool shouldShow: TimerBridge.running || forceVisible || flashDone
	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Timer notch hangs from the top edge like the collapsed menu. 2026-10-10.
	readonly property int topMargin: 0
	// LLM PROMPT [end]
	// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Match collapsed notch geometry for the timer island. 2026-10-10.
	readonly property int collapsedHeight: 32
	readonly property int cornerWing: 16
	readonly property int bodyWidth: 148
	readonly property int canvasWidth: bodyWidth + cornerWing * 2
	// LLM PROMPT [end]

	function timerShow() {
		forceVisible = true;
		hideTimer.stop();
	}

	function timerTick(remaining) {
		forceVisible = TimerBridge.running;
		if (TimerBridge.running)
			hideTimer.stop();
	}

	function timerDone() {
		flashDone = true;
		forceVisible = false;
		doneFlash.restart();
		hideTimer.restart();
	}

	function timerHide() {
		forceVisible = false;
		flashDone = false;
	}

	Connections {
		target: TimerBridge
		function onTick(remaining) { root.timerTick(remaining); }
		function onStarted() { root.timerShow(); }
		function onStopped() { root.timerHide(); }
		function onDone() { root.timerDone(); }
	}

	Timer {
		id: hideTimer
		interval: 2500
		onTriggered: {
			forceVisible = false;
			flashDone = false;
		}
	}

	Timer {
		id: doneFlash
		interval: 400
		repeat: true
		property int count: 0
		onTriggered: {
			count += 1;
			flashDone = !flashDone;
			if (count >= 6) {
				stop();
				count = 0;
				flashDone = true;
			}
		}
	}

	LazyLoader {
		active: root.shouldShow

		PanelWindow {
			id: window

			readonly property color fillColor: root.flashDone ? Theme.red : Theme.shellBackground

			anchors.top: true
			anchors.left: true
			// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Pin timer notch to top center; flush in fullscreen. 2026-10-10.
			margins.top: root.topMargin
			margins.left: screen ? Math.round((screen.width - root.canvasWidth) / 2) : 0
			// LLM PROMPT [end]
			exclusiveZone: 0
			exclusionMode: ExclusionMode.Ignore
			implicitWidth: root.canvasWidth
			implicitHeight: root.collapsedHeight
			color: "transparent"
			// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Overlay layer so always-on-top timer shows over fullscreen games. 2026-10-10.
			WlrLayershell.layer: ShellState.timerAlwaysOnTop ? WlrLayer.Overlay : WlrLayer.Bottom
			WlrLayershell.namespace: "quickshell-timer"
			// LLM PROMPT [end]
			mask: Region {}

			// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Draw timer chrome as a Dotarch-style collapsed notch. 2026-10-10.
			Item {
				id: notchSurface
				anchors.top: parent.top
				anchors.horizontalCenter: parent.horizontalCenter
				width: root.canvasWidth
				height: root.collapsedHeight

				Rectangle {
					id: notchBody
					x: root.cornerWing
					y: -15
					width: parent.width - root.cornerWing * 2
					height: parent.height + 15
					radius: Theme.radius
					color: window.fillColor
				}

				Shape {
					x: 0
					width: root.cornerWing
					height: root.cornerWing
					preferredRendererType: Shape.CurveRenderer

					ShapePath {
						id: leftShoulderPath
						readonly property real size: root.cornerWing
						strokeWidth: 0
						fillColor: window.fillColor
						startX: 0
						startY: 0
						PathLine { x: leftShoulderPath.size; y: 0 }
						PathLine { x: leftShoulderPath.size; y: leftShoulderPath.size }
						PathCubic {
							control1X: leftShoulderPath.size
							control1Y: leftShoulderPath.size * 0.448
							control2X: leftShoulderPath.size * 0.552
							control2Y: 0
							x: 0
							y: 0
						}
					}
				}

				Shape {
					x: parent.width - width
					width: root.cornerWing
					height: root.cornerWing
					preferredRendererType: Shape.CurveRenderer

					ShapePath {
						id: rightShoulderPath
						readonly property real size: root.cornerWing
						strokeWidth: 0
						fillColor: window.fillColor
						startX: rightShoulderPath.size
						startY: 0
						PathLine { x: 0; y: 0 }
						PathLine { x: 0; y: rightShoulderPath.size }
						PathCubic {
							control1X: 0
							control1Y: rightShoulderPath.size * 0.448
							control2X: rightShoulderPath.size * 0.448
							control2Y: 0
							x: rightShoulderPath.size
							y: 0
						}
					}
				}

				Row {
					anchors.left: notchBody.left
					anchors.right: notchBody.right
					anchors.top: parent.top
					height: root.collapsedHeight
					anchors.leftMargin: 10
					anchors.rightMargin: 10
					spacing: 8

					ShellText {
						anchors.verticalCenter: parent.verticalCenter
						text: TimerBridge.paused ? "󰏤" : (root.flashDone && !TimerBridge.running ? "󰔛" : "󰔟")
						color: Theme.shellForeground
						font.pixelSize: 12
						font.weight: Font.DemiBold
					}

					ShellText {
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - 28
						text: {
							const time = TimerBridge.running || root.flashDone ? TimerBridge.remainingText : "0:00";
							const label = TimerBridge.label || "";
							return label ? (label + "  " + time) : time;
						}
						color: Theme.shellForeground
						font.pixelSize: 12
						font.weight: Font.DemiBold
						elide: Text.ElideRight
					}
				}
			}
			// LLM PROMPT [end]
		}
	}
}
