#!/usr/bin/env bash
# Format the project's Python tooling with ruff. No install/PATH needed -- uvx runs it.
#   ./tools/format.sh                      # format everything under tools/
#   ./tools/format.sh path/to/file.py      # format specific file(s)
set -e
cd "$(dirname "$0")/.."
uvx ruff format "${@:-tools}"
