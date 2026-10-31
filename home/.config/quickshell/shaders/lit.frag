#version 440

// The colour comes up towards `towards`, by `lift`; the shape stays as it is.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o lit.frag.qsb lit.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
	mat4 qt_Matrix;
	float qt_Opacity;
	float lift;
	vec4 towards;
};

layout(binding = 1) uniform sampler2D source;

void main() {
	vec4 c = texture(source, qt_TexCoord0);
	c.rgb = mix(c.rgb, towards.rgb * c.a, lift);
	fragColor = c * qt_Opacity;
}
