-- Input config placeholder. Ported from input.nix (empty in nix; defaults apply).
-- Add device-specific tweaks here when needed.

hl.config({
	input = {
		touchpad = {
			-- Two-finger scroll speed. Default 1.0; lower = slower scroll distance.
			scroll_factor = 0.6,
		},
	},
})
