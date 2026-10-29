import QtQuick
import QtQuick.Effects

// A soft dark glow for text and icons (layer.effect), readable on any wallpaper.
MultiEffect {
	shadowEnabled: true
	shadowColor: "black"
	shadowOpacity: 1.0
	shadowBlur: 0.6
	blurMax: 8
	shadowHorizontalOffset: 0
	shadowVerticalOffset: 0
}
