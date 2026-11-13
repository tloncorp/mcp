#!/usr/bin/env bash
# Fetch the files listed in desk-deps.yaml, at their pinned commits, into desk-deps/.
set -euo pipefail
cd "$(dirname "$0")/.."

deps=desk-deps.yaml out=desk-deps cache=.deps-cache

# Two unrelated tools are called yq; this needs the Go one.
yq --version 2>/dev/null | grep -q mikefarah ||
  { echo "fetch needs mikefarah/yq v4 (https://github.com/mikefarah/yq)" >&2; exit 1; }

# Runs take turns, and so does the build that reads $out, which takes this
# lock too: git cannot share a cache repository, and $out is replaced below.
# The lock is on the descriptor, which the kernel closes when this exits.
mkdir -p "$cache"
exec 9>>"$cache/lock"
python3 -c 'import fcntl; fcntl.flock(9, fcntl.LOCK_EX)'

# A build waiting on the lock reads $out next, so a run that fails must leave
# the last complete one: fetch aside, and replace $out only at the end.
stage=$cache/stage
rm -rf "$stage" && mkdir "$stage"
for name in $(yq 'keys | .[]' "$deps"); do
  url=$(name=$name yq '.[strenv(name)].url' "$deps")
  rev=$(name=$name yq '.[strenv(name)].rev' "$deps")
  export_dir=$(name=$name yq '.[strenv(name)].export' "$deps")
  files=()
  while IFS= read -r file; do files+=("$file"); done \
    < <(name=$name yq '.[strenv(name)].files[]' "$deps")
  [[ $url != null && $export_dir != null && ${#files[@]} -gt 0 ]] ||
    { echo "$deps: $name needs url, rev, export and files" >&2; exit 1; }
  [[ $rev =~ ^[0-9a-f]{40}$ ]] ||
    { echo "$deps: $name: rev must be a full commit hash" >&2; exit 1; }
  for file in "${files[@]}"; do
    [[ ! -e $stage/$file ]] ||
      { echo "$deps: $name: $file is already provided by an earlier entry" >&2; exit 1; }
  done

  # Shallow clone at commit and only fetch listed files
  repo=$cache/$name
  git init --quiet "$repo"
  git -C "$repo" cat-file -e "$rev^{commit}" 2>/dev/null ||
    git -C "$repo" fetch --quiet --depth 1 --filter=blob:none "$url" "$rev"
  git -C "$repo" archive "$rev:$export_dir" "${files[@]}" | tar -x -C "$stage"
  echo "$name: ${#files[@]} files at ${rev:0:12}"
done
rm -rf "$out" && mv "$stage" "$out"
