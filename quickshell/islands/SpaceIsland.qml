// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Floating island for daily space checklist / game lock status. 2026-10-12.
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

Scope {
	id: root

	property bool expanded: false

	readonly property int collapsedWidth: 176
	readonly property int expandedWidth: 330
	readonly property int collapsedHeight: 52
	readonly property int expandedHeight: Math.max(120, 58 + SpaceBridge.tasks.length * 34 + 28)

	PanelWindow {
		anchors.left: true
		anchors.bottom: true
		margins.left: 18
		margins.bottom: 18
		exclusiveZone: 0
		exclusionMode: ExclusionMode.Ignore
		implicitWidth: root.expanded ? root.expandedWidth : root.collapsedWidth
		implicitHeight: root.expanded ? root.expandedHeight : root.collapsedHeight
		color: "transparent"
		WlrLayershell.layer: WlrLayer.Top
		WlrLayershell.namespace: "quickshell-space"
		mask: Region {
			item: islandBody
		}

		Behavior on implicitWidth {
			NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic }
		}
		Behavior on implicitHeight {
			NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic }
		}

		Rectangle {
			id: islandBody
			anchors.fill: parent
			radius: 16
			color: Theme.shellBackground
			border.width: 1
			border.color: !SpaceBridge.enabled
				? Theme.mutedDark
				: (SpaceBridge.unlocked ? Theme.primary : Theme.red)
			clip: true

			Column {
				id: contentCol
				anchors.fill: parent
				anchors.margins: 10
				spacing: 8

				Item {
					width: parent.width
					height: 28

					Row {
						anchors.fill: parent
						spacing: 8

						Rectangle {
							width: 8
							height: 8
							radius: 4
							anchors.verticalCenter: parent.verticalCenter
							color: !SpaceBridge.enabled
								? Theme.mutedDark
								: (SpaceBridge.unlocked ? Theme.primary : Theme.red)
						}

						Column {
							anchors.verticalCenter: parent.verticalCenter
							width: parent.width - 54
							spacing: 1

							ShellText {
								width: parent.width
								text: SpaceBridge.enabled
									? (SpaceBridge.unlocked ? "Space clear" : "Space locked")
									: "Space off"
								font.pixelSize: 12
								font.weight: Font.DemiBold
								elide: Text.ElideRight
							}

							ShellText {
								width: parent.width
								text: SpaceBridge.unlocked
									? "Games free until tomorrow"
									: "Checklist unlocks games"
								color: Theme.muted
								font.pixelSize: 8
								elide: Text.ElideRight
							}
						}

						ShellText {
							anchors.verticalCenter: parent.verticalCenter
							text: SpaceBridge.done + "/" + SpaceBridge.total
							color: Theme.muted
							font.pixelSize: 11
							font.weight: Font.DemiBold
						}
					}

					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.LeftButton | Qt.RightButton
						cursorShape: Qt.PointingHandCursor
						onClicked: (mouse) => {
							if (mouse.button === Qt.RightButton) {
								SpaceBridge.openNotes();
								return;
							}
							root.expanded = !root.expanded;
						}
					}
				}

				Repeater {
					model: root.expanded ? SpaceBridge.tasks : []

					delegate: Rectangle {
						required property var modelData
						width: contentCol.width
						height: 30
						radius: 8
						color: modelData.done ? Theme.primaryContainer : Theme.bg0

						Row {
							anchors.fill: parent
							anchors.margins: 6
							spacing: 8

							Rectangle {
								width: 16
								height: 16
								radius: 4
								anchors.verticalCenter: parent.verticalCenter
								color: modelData.done ? Theme.primary : "transparent"
								border.width: 1
								border.color: modelData.done ? Theme.primary : Theme.mutedDark

								ShellText {
									anchors.centerIn: parent
									text: modelData.done ? "✓" : ""
									color: Theme.bgDim
									font.pixelSize: 10
									font.weight: Font.Bold
								}
							}

							ShellText {
								anchors.verticalCenter: parent.verticalCenter
								width: parent.width - 28
								text: modelData.label || modelData.id
								font.pixelSize: 10
								elide: Text.ElideRight
								color: modelData.done ? Theme.muted : Theme.foreground
							}
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							onClicked: SpaceBridge.toggleTask(modelData.id)
						}
					}
				}

				ShellText {
					visible: root.expanded
					width: parent.width
					text: "Right-click opens Notes · resets tomorrow"
					color: Theme.mutedDark
					font.pixelSize: 8
				}
			}
		}
	}
}
// LLM PROMPT [end]
