::  oauth-grants: sanitized grants snapshot from %oauth
::
::    grows to json via /lib/oauth-json. the noun form carries
::    `now` alongside the grants map so the mark's json conversion
::    can mark each grant expired/live consistently.
::
/-  oauth
|_  snap=[now=@da gs=(map provider-id:oauth grant:oauth)]
++  grad  %noun
++  grow
  |%
  ++  noun  snap
  ++  json
    =,  enjs:format
    ^-  ^json
    :-  %a
    %+  turn  ~(tap by gs.snap)
    |=  [=provider-id:oauth =grant:oauth]
    ^-  ^json
    =/  is-expired=?
      ?~  expires-at.grant  %.n
      (lth u.expires-at.grant now.snap)
    %-  pairs
    :~  ['provider' s+(scot %tas provider-id)]
        ['connected' b+!is-expired]
        ['tokenType' s+token-type.grant]
        ['scopes' s+scopes.grant]
        ['hasRefreshToken' b+?=(^ refresh-token.grant)]
      ::
        :-  'expiresAt'
        ?~  expires-at.grant  ~
        s+(scot %da u.expires-at.grant)
      ::
        ['expired' b+is-expired]
    ==
  --
++  grab
  |%
  ++  noun  [now=@da gs=(map provider-id:oauth grant:oauth)]
  --
--
