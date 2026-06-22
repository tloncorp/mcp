::  oauth-grants: sanitized grants snapshot from %oauth
::
::    Keep the snapshot molds desk-local so 408 Clay can prebuild this mark
::    during Kelvin upgrade without resolving /sur/oauth while building marks.
::
=,  |%
    +$  oauth-grant
      $:  access-token=@t
          refresh-token=(unit @t)
          token-type=@t
          expires-at=(unit @da)
          scopes=@t
          provider-id=@tas
      ==
    +$  oauth-grants
      [now=@da gs=(map @tas oauth-grant)]
    --
|_  snap=oauth-grants
++  grad  %noun
++  grow
  |%
  ++  noun  snap
  ++  json
    =,  enjs:format
    :-  %a
    %+  turn  ~(tap by gs.snap)
    |=  [provider-id=@tas grant=oauth-grant]
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
  ++  noun  oauth-grants
  --
--
