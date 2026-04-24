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
    %-  pairs
    :~  ['provider' s+(scot %tas provider-id)]
        ['connected' b+%.y]
        ['tokenType' s+token-type.grant]
        ['scopes' s+scopes.grant]
        ['hasRefreshToken' b+?=(^ refresh-token.grant)]
      ::
        :-  'expiresAt'
        ?~  expires-at.grant  ~
        s+(scot %da u.expires-at.grant)
      ::
        :-  'expired'
        ?~  expires-at.grant  b+%.n
        b+(lth u.expires-at.grant now)
    ==
  --
--
