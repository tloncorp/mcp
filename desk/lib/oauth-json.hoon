::  oauth-json: encoders from %oauth state to JSON
::
/-  oauth
|%
++  enjs
  =,  enjs:format
  |%
  ::
  ::  sanitized grants array — never exposes access/refresh tokens.
  ::  caller supplies `now` so expiry evaluation is consistent
  ::  across the response.
  ::
  ++  grants
    |=  [now=@da gs=(map provider-id:oauth grant:oauth)]
    ^-  json
    :-  %a
    %+  turn  ~(tap by gs)
    |=  [=provider-id:oauth =grant:oauth]
    ^-  json
    ::  expired iff there is an expiry and it has passed. connected
    ::  reflects "usable right now" — a stored-but-expired grant is
    ::  NOT connected, so the UI shows a Reconnect/Connect affordance
    ::  rather than a green check.
    ::
    =/  is-expired=?
      ?~  expires-at.grant  %.n
      (lth u.expires-at.grant now)
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
--
