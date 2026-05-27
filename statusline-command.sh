#!/bin/sh
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

printf '%s' "$model"

if [ -n "$remaining" ]; then
  if [ "$remaining" -gt 50 ] 2>/dev/null; then
    color="\033[0;32m"
  elif [ "$remaining" -lt 20 ] 2>/dev/null; then
    color="\033[0;31m"
  else
    color="\033[0;33m"
  fi
  reset="\033[0m"
  printf " | ${color}%s%% remaining${reset}" "$remaining"
fi
