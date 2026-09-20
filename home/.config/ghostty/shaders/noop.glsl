// Pass-through shader: power-save.sh points the active-shader symlink here to
// disable the cursor warp effect without editing the stowed ghostty config.
// Body is the identity pass-through every ghostty shader starts with.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
}
