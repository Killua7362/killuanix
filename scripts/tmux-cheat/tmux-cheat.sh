#!/bin/bash
#thanks prime
#
selected=`cat ~/killuanix/scripts/tmux-cheat/tmux-cht-languages ~/killuanix/scripts/tmux-cheat/tmux-cht-command | fzf`
if [[ -z $selected ]]; then
    exit 0
fi

read -p "Enter Query: " query

if grep -qs "$selected" ~/killuanix/scripts/tmux-cheat/tmux-cht-languages; then
    query=`echo $query | tr ' ' '+'`
    tmux neww bash -c "cht.sh $selected/$query | less -R"
else
    tmux neww bash -c "cht.sh $selected~$query | less -R"
fi
