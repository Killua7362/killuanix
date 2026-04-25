{inputs, ...}: {
  # Intentionally empty — prior `pipewire-pin` overlay replaced pkgs.pipewire
  # with a pinned build, which cascaded rebuilds into every downstream
  # consumer (ffmpeg, gtk4, electron, …). The LDAC fix is now applied as a
  # runtime-only override in killua/bluez5-ldac-pin.nix, leaving pkgs.pipewire
  # unchanged so the whole closure substitutes from cache.
}
