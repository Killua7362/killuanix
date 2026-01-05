{ lib, ... }: {
      wayland.windowManager.hyprland.settings = {
        gestures = {
    workspace_swipe_distance = 700;
    workspace_swipe_cancel_ratio = 0.2;
    workspace_swipe_min_speed_to_force = 5;
    workspace_swipe_direction_lock = true;
    workspace_swipe_direction_lock_threshold = 10;
    workspace_swipe_create_new = true;
        };
        gesture = [
"3, swipe, move,"
"4, horizontal, workspace"
"4, pinch, float"
"4, up, dispatcher, global, quickshell:overviewToggle"
"4, down, dispatcher, global, quickshell:overviewClose"
        ];
      };
}
