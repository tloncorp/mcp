# Where the desk is assembled.
out := "desk-out"

# Tlon's click. Override to add options, such as `-b /path/to/vere` for a pier
# without a docked runtime.
click := "scripts/click"

# Assemble the desk: the files fetched from deps.yaml, then this desk on top.
build: fetch
    rm -rf {{ quote(out) }}
    mkdir -p {{ quote(out) }}
    cp -R desk-deps/. desk/. {{ quote(out) }}/

# Copy the assembled desk into a mounted desk. Files already there are kept.
install desk: build
    test -d {{ quote(desk) }} || { echo "desk mount '{{ desk }}' does not exist" >&2; exit 1; }
    rsync --recursive --checksum {{ quote(out) }}/ {{ quote(desk) }}/

# Install into a mounted desk, then ask the running ship to commit it.
commit desk: (install desk)
    #!/usr/bin/env bash
    set -euo pipefail
    mount=$(cd {{ quote(desk) }} && pwd)
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

# Fetch the files listed in deps.yaml, at their pinned commits, into desk-deps/.
fetch:
    scripts/fetch-deps.sh

# Remove the assembled desk.
clean:
    rm -rf {{ quote(out) }}

# Remove everything generated: the assembled desk, fetched files and fetch cache.
distclean: clean
    rm -rf desk-deps .deps-cache
