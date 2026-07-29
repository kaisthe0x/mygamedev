#!/usr/bin/env bash
# One-time dev setup: build the local tools venv and enable the auto-format hook.
# Run once after cloning:  bash scripts/setup-dev.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

python3 -m venv .devtools
.devtools/bin/pip install --quiet --upgrade pip
.devtools/bin/pip install --quiet pre-commit "gdtoolkit==4.*" ruff
.devtools/bin/pre-commit install

echo
echo "Dev tools ready. On 'git commit', Python (tools/, vfx/script/) is auto-formatted."
echo "GDScript is NOT auto-formatted (gdformat mangles our style -- see .pre-commit-config.yaml);"
echo "it's kept consistent via .editorconfig + review."
echo "  Format Python now      : .devtools/bin/pre-commit run --all-files"
echo "  Lint GDScript (opt-in) : .devtools/bin/pre-commit run --hook-stage manual gdlint"
