# Where the desk is assembled.
out := "desk-out"

# Tlon's click. Override to add options, such as `-b /path/to/vere` for a pier
# without a docked runtime.
click := "scripts/click"

# Assemble the desk: the files fetched from desk-deps.yaml, then this desk on top.
build: fetch
    #!/usr/bin/env bash
    set -euo pipefail
    # Builds take turns, under the lock that fetch-deps.sh takes to write
    # desk-deps/. The lock is on the descriptor, which the kernel closes when
    # this exits.
    mkdir -p .deps-cache
    exec 9>>.deps-cache/lock
    python3 -c 'import fcntl; fcntl.flock(9, fcntl.LOCK_EX)'
    # Whoever ran an earlier build may still be reading the output, which is
    # not under the lock, so the desk is built aside and the output updated in
    # place: rsync leaves files that have not changed untouched.
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    mkdir "$tmp/desk"
    # A file with no Clay mark fails the desk commit outright, so Finder's
    # .DS_Store must stay out. The desk's own files go second and win on any
    # overlap.
    rsync -aL --exclude=.DS_Store desk-deps/ "$tmp/desk/"
    rsync -aL --exclude=.DS_Store desk/ "$tmp/desk/"
    mkdir -p {{ quote(out) }}
    # Everything else in the output is deleted, so it must not hold the sources.
    dest=$(cd {{ quote(out) }} && pwd -P) here=$(pwd -P)
    [[ $dest != / && $here/ != "$dest"/* && $dest/ != "$here"/desk/* && $dest/ != "$here"/desk-deps/* ]] ||
      { echo "refusing to assemble into $dest: the build would delete its own sources" >&2; exit 1; }
    rsync -a --delete --checksum "$tmp/desk/" "$dest/"

# Replace a mounted desk with the assembled one, deleting everything else there.
install desk: build
    #!/usr/bin/env bash
    set -euo pipefail
    desk={{ quote(desk) }}
    # just runs recipes from this directory; the path is relative to the caller's.
    mount=$(cd {{ quote(invocation_directory()) }} && cd "$desk" 2>/dev/null && pwd) ||
      { echo "desk mount '$desk' does not exist" >&2; exit 1; }
    # Everything else in the target is deleted, so it has to be a desk mount:
    # a directory in a pier, named as a desk (which rules out the pier's .urb).
    [[ $(basename "$mount") =~ ^[a-z][a-z0-9-]*$ && -d $mount/../.urb ]] ||
      { echo "'$desk' is not a desk mounted in a pier" >&2; exit 1; }
    # Under the build lock, so that no other build changes the desk mid-copy.
    exec 9>>.deps-cache/lock
    python3 -c 'import fcntl; fcntl.flock(9, fcntl.LOCK_EX)'
    rsync -a --delete --checksum {{ quote(out) }}/ "$mount/"

# Copy the assembled desk into a mounted desk. Files it does not contain are kept.
install-dev desk: build
    #!/usr/bin/env bash
    set -euo pipefail
    desk={{ quote(desk) }}
    # just runs recipes from this directory; the path is relative to the caller's.
    mount=$(cd {{ quote(invocation_directory()) }} && cd "$desk" 2>/dev/null && pwd) ||
      { echo "desk mount '$desk' does not exist" >&2; exit 1; }
    # Files there with the desk's names are overwritten, so it has to be a desk
    # mount: a directory in a pier, named as a desk.
    [[ $(basename "$mount") =~ ^[a-z][a-z0-9-]*$ && -d $mount/../.urb ]] ||
      { echo "'$desk' is not a desk mounted in a pier" >&2; exit 1; }
    # Under the build lock, so that no other build changes the desk mid-copy.
    exec 9>>.deps-cache/lock
    python3 -c 'import fcntl; fcntl.flock(9, fcntl.LOCK_EX)'
    rsync --recursive --checksum {{ quote(out) }}/ "$mount/"

# Run install-dev, then ask the running ship to commit the desk.
commit desk: (install-dev desk)
    #!/usr/bin/env bash
    set -euo pipefail
    mount=$(cd {{ quote(invocation_directory()) }} && cd {{ quote(desk) }} && pwd)
    name=$(basename "$mount") pier=$(dirname "$mount")
    # The mount name becomes a Hoon term in the thread below.
    [[ $name =~ ^[a-z][a-z0-9-]*$ ]] ||
      { echo "desk mount name '$name' is not a valid desk name" >&2; exit 1; }

    # Unix limits socket paths to 108 bytes; socat would truncate a longer one.
    socket=$pier/.urb/conn.sock
    (( ${#socket} < 108 )) ||
      { echo "pier path is too long for the ship's socket: $socket" >&2; exit 1; }

    # click exits zero even when the thread fails, so require its receipt.
    # It joins these lines into one, so each must end in a two-space gap.
    # The receipt is a long term because short atoms come back as numbers.
    result=$({{ click }} -t 120 -i - -kp "$pier" <<EOF
    =/  m  (strand ,vase)  
    ;<  our=ship  bind:m  get-our  
    ;<  ~  bind:m  (poke [our %hood] kiln-commit+!>([%$name |]))  
    (pure:m !>(%mcp-commit-sent))  
    EOF
    )
    echo "$result"
    [[ $result == *"[0 %avow 0 %noun %mcp-commit-sent]"* ]] ||
      { echo "Clay commit failed for %$name" >&2; exit 1; }
    echo "Clay commit requested for %$name"

# Fetch the files listed in desk-deps.yaml, at their pinned commits, into desk-deps/.
fetch:
    scripts/fetch-deps.sh

# Remove the assembled desk.
clean:
    rm -rf {{ quote(out) }}

# Remove everything generated: the assembled desk, fetched files and fetch cache.
distclean: clean
    rm -rf desk-deps .deps-cache
