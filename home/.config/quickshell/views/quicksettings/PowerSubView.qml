import "../.."
import "."
import QtQuick

ActionListSubView {
	id: root

	title: "Power"
	actions: SessionActions.actions.map(a => ({
		title: a.label,
		desc: a.desc,
		icon: a.lineIcon,
		verb: a.verb,
		confirm: a.confirm,
		tint: a.confirm ? Theme.warning : Theme.accentBlue,
		run: () => {
			Panels.close("quicksettings");
			SessionActions.run(a.id);
		}
	}))
}
