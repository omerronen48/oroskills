#!/usr/bin/env bash
# lessons-for.sh <lessons-file> [file...]
# Prints up to 5 lessons relevant to the given files: repo-wide lessons (no
# "files:") plus lessons whose "files:" globs match any given file, highest
# "seen:" first. Missing lessons file → prints nothing.
# ponytail: glob match on paths, no semantic ranking; add embeddings if lessons grow past a few hundred.
set -uo pipefail
set -f   # globs in lessons are patterns, never expand them against the cwd
lf="${1:-}"; shift || true
[[ -f "$lf" ]] || exit 0
while IFS= read -r line; do
  [[ "$line" == "- "* ]] || continue
  seen="$(sed -nE 's/.*seen: ([0-9]+).*/\1/p' <<<"$line")"; seen="${seen:-1}"
  globs="$(sed -nE 's/.*files: ([^;)]*).*/\1/p' <<<"$line")"
  hit=0
  if [[ -z "$globs" ]]; then hit=1; else
    for g in ${globs//,/ }; do for f in "$@"; do [[ "$f" == $g ]] && hit=1; done; done
  fi
  if (( hit )); then printf '%s\t%s\n' "$seen" "$line"; fi
done < "$lf" | sort -t $'\t' -k1,1nr | head -n 5 | cut -f2-
