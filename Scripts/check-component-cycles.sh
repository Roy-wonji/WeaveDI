#!/usr/bin/env bash
set -euo pipefail

REPORT_FILE="${TMPDIR:-/tmp}/weavedi-cycle-report.json"
export REPORT_FILE

swift run --configuration release WeaveDITools check-cycles --json >"$REPORT_FILE"

python3 - <<'PY'
import json
import os
import sys

path = os.environ.get('REPORT_FILE', '')
if not path or not os.path.exists(path):
    print('Component cycle report not found.', file=sys.stderr)
    sys.exit(1)

with open(path, 'r', encoding='utf-8') as fh:
    payload = json.load(fh)

cycles = payload.get('cycles', [])
component_count = payload.get('componentCount', 0)
edge_count = payload.get('edgeCount', 0)

print('🧭 Component cycle analysis')
print(f'- Components: {component_count}')
print(f'- Edges: {edge_count}')

if not cycles:
    print('✅ No component cycles detected.')
    sys.exit(0)

print(f'❌ Found {len(cycles)} potential cycle(s):')
for idx, cycle in enumerate(cycles, start=1):
    print(f' {idx}. {" -> ".join(cycle)}')

sys.exit(1)
PY

rm -f "$REPORT_FILE"
