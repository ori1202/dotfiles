pragma Singleton
import Quickshell
import QtQuick

Singleton {
	id: root

	property bool open: false
	property int viewYear: new Date().getFullYear()
	property int viewMonth: new Date().getMonth() // 0-11

	function toggle() {
		if (open) {
			hide();
		} else {
			show();
		}
	}

	function show() {
		const now = new Date();
		viewYear = now.getFullYear();
		viewMonth = now.getMonth();
		open = true;
	}

	function hide() {
		open = false;
	}

	function prevMonth() {
		if (viewMonth === 0) {
			viewMonth = 11;
			viewYear -= 1;
		} else {
			viewMonth -= 1;
		}
	}

	function nextMonth() {
		if (viewMonth === 11) {
			viewMonth = 0;
			viewYear += 1;
		} else {
			viewMonth += 1;
		}
	}
}
