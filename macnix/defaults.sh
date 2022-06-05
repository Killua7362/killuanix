#!/bin/sh
#to disablee some macos animation
tweak(){
defaults write -g QLPanelAnimationDuration -float 0
defaults write -g NSToolbarFullScreenAnimationDuration -float 0
}

default(){
defaults delete -g QLPanelAnimationDuration
defaults delete -g NSToolbarFullScreenAnimationDuration
}
