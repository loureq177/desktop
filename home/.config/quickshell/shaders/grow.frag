#version 440

// Shows the source inside a soft-edged circle; everything in pixels.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o grow.frag.qsb grow.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
	mat4 qt_Matrix;
	float qt_Opacity;
	float radius;
	float feather;
	vec2 center;
	vec2 size;
};

layout(binding = 1) uniform sampler2D source;

void main() {
	float d = distance(qt_TexCoord0 * size, center);
	float inside = 1.0 - smoothstep(radius - feather, radius, d);
	fragColor = texture(source, qt_TexCoord0) * inside * qt_Opacity;
}
