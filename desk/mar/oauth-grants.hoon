::  oauth-grants: sanitized grants snapshot from %oauth
::
::    grows to json via /lib/oauth-json. the noun form carries
::    `now` alongside the grants map so the mark's json conversion
::    can mark each grant expired/live consistently.
::
/-  oauth
/+  oj=oauth-json
|_  snap=[now=@da gs=(map provider-id:oauth grant:oauth)]
++  grad  %noun
++  grow
  |%
  ++  noun  snap
  ++  json  (grants:enjs:oj now.snap gs.snap)
  --
++  grab
  |%
  ++  noun  [now=@da gs=(map provider-id:oauth grant:oauth)]
  --
--
