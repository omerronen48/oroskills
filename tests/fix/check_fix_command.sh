# tests/fix/check_fix_command.sh
#!/usr/bin/env bash
# Contract check for the /fix orchestrator command.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=pipelines/fix-pipeline/commands/fix.md
fail=0
check() { grep -qiE "$1" "$f" || { echo "MISSING: $2"; fail=1; }; }

test -f "$f" || { echo "MISSING FILE: $f"; exit 1; }
check '\$ARGUMENTS'                         'blurb input via $ARGUMENTS'
check '\.fix/roadmap\.md'                   'roadmap file'
check 'oro-coder'                           'delegates to oro-coder'
check 'oro-tester'                          'delegates to oro-tester'
check 'oro-reviewer'                        'oro-reviewer at end'
check 'full test suite|full suite'          'full-suite regression guard'
check 'regression'                          'regression guard named'
check 'halt|stop'                           'halt-on-red behavior'
check 'fix/N-|fix/N|stack'                  'stacked fix branches'
check 'do not merge|not merge|no merge'     'no auto-merge'
check 'baseline'                            'green-baseline gate'

[ "$fail" -eq 0 ] && echo "check_fix_command: PASS"
exit $fail
