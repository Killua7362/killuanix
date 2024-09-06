<?php

// only run if there is a file given
if ($argc < 2) {
    exit;
}

// escape spaces in file path
$file = $argv[1];
$file = str_replace(' ', '\ ', $file);

// helper function to run wezterm cli
function wez($command)
{
    return shell_exec("/nix/var/nix/profiles/system/sw/bin/zsh -c 'wezterm cli {$command}'");
}

// helper function to focus on wezterm and bring it to front
function focus($paneId)
{
    wez("activate-pane -c 'wezterm focus-pane --pane-id {$paneId}'");
}

// nothing matching found, create new window and start vim with the file
$newPane = wez("spawn");
wez("send-text \"nvim {$file}\n\" --no-paste --pane-id {$newPane}");
focus($newPane);
