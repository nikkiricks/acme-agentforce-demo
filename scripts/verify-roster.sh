#!/usr/bin/env bash
set -euo pipefail
# FORCE_COLOR=0: this shell environment sets FORCE_COLOR=3 globally, which makes
# `sf ... --json` emit ANSI color codes even in --json mode, breaking JSON parsing
# downstream. Override it so --json output is clean, parseable JSON.
export FORCE_COLOR=0
echo "== Total example.com candidates (expect 25):"
sf data query -q "SELECT COUNT(Id) c FROM Contact WHERE Email LIKE '%example.com'" --json | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['records'][0]['c'])"
echo "== Spot-check description round-trip (Elena Vasquez):"
sf data query -q "SELECT Description FROM Contact WHERE Email = 'elena.vasquez@example.com'" --json | python3 -c "import sys,json; d=json.load(sys.stdin)['result']['records'][0]['Description']; print(len(d.split()), 'words'); assert 40 <= len(d.split()) <= 100"
