import QtQuick
import QtQuick.Effects

// A soft dark glow around text and icons, for an item's `layer.effect`: it
// keeps them readable on whatever the wallpaper puts behind them without a
// backdrop of their own.
MultiEffect {
	shadowEnabled: true
	shadowColor: "black"
	shadowOpacity: 1.0
	shadowBlur: 0.6
	blurMax: 8
	shadowHorizontalOffset: 0
	shadowVerticalOffset: 0
}
