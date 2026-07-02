# tests/fix/check_fix_install.sh
#!/usr/bin/env bash
# Registration check: /fix wired into install.sh (install + refresh share these loops).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
g() { grep -qE "$1" install.sh || { echo "MISSING: $2"; fail=1; }; }

g '^FIX_COMMANDS=\(fix\)'                                              'FIX_COMMANDS array'
g 'for command in "\$\{FIX_COMMANDS\[@\]\}"'                          'FIX_COMMANDS install loop'
g 'pipelines/fix-pipeline/commands/\$command\.md'                     'fix-pipeline command source path'
g '/ship, /fix'                                                       'done-message mentions /fix'

[ "$fail" -eq 0 ] && echo "check_fix_install: PASS"
exit $fail
