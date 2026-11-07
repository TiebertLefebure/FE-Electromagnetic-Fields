#!/bin/zsh
# Double-click in Finder: compute the healthy model and open its result in Gmsh.
cd -- "$(dirname -- "$0")" || exit 1
python3 run.py --open
status_code=$?
if [ "$status_code" -ne 0 ]; then
  printf '\nRun failed. Read the message above; press Return to close.\n'
  read -r
fi
exit "$status_code"
