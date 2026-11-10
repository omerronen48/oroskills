# How agents run this project

oroskills is a set of skills, agents, commands and hook scripts; it has no server.

## Launch
- `HOME="$(mktemp -d)" ./install.sh` installs everything into a throwaway HOME (sandbox install).

## Logs
- n/a — scripts print to stdout/stderr.

## Smoke
- `bash tests/check_sandbox_install.sh`

## Browser
- n/a
