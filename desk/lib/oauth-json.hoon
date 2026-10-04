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
::
++  action-from-json
  |=  jon=json
  ^-  (unit action:oauth)
  =/  res  (mule |.((action-from-json-raw jon)))
  ?:  ?=(%& -.res)  `p.res
  ~
::
++  parse-provider-config
  |=  jon=json
  ^-  [id=@t config=provider-config:oauth]
  ?>  ?=(%o -.jon)
  =,  dejs:format
  =/  f
    %-  ot
    :~  id+so
        auth-url+so
        token-url+so
        revoke-url+(mu so)
        client-id+so
        client-secret+so
        redirect-uri+so
        scopes+so
    ==
  =/  [id=@t auth-url=@t token-url=@t revoke-url=(unit @t) client-id=@t client-secret=@t redirect-uri=@t scopes=@t]
    (f jon)
  =/  token-resource=(unit @t)
    =/  v=(unit json)  (~(get by p.jon) 'token-resource')
    ?~  v  ~
    ?.  ?=(%s -.u.v)  ~
    ?:  =('' p.u.v)  ~
    `p.u.v
  =/  token-auth=token-auth-mode:oauth
    =/  v=(unit json)  (~(get by p.jon) 'token-auth')
    ?~  v  %basic
    ?.  ?=(%s -.u.v)  %basic
    ?:  =('body' p.u.v)  %body
    %basic
  [id [auth-url token-url revoke-url client-id client-secret redirect-uri scopes token-resource token-auth]]
::
++  action-from-json-raw
  |=  jon=json
  ^-  action:oauth
  =,  dejs:format
  =/  typ=@t  ((ot ~[action+so]) jon)
  |^
    ?+  typ  !!
        %'add-provider'
      =/  parsed=[id=@t config=provider-config:oauth]  (parse-provider-config jon)
      [%add-provider `@tas`id.parsed config.parsed]
    ::
        %'update-provider'
      =/  parsed=[id=@t config=provider-config:oauth]  (parse-provider-config jon)
      [%update-provider `@tas`id.parsed config.parsed]
    ::
        %'config-provider'
      =/  parsed=[id=@t config=provider-config:oauth]  (parse-provider-config jon)
      [%config-provider `@tas`id.parsed config.parsed]
    ::
        %'remove-provider'
      [%remove-provider `@tas`((ot ~[id+so]) jon)]
    ::
        %'connect'
      [%connect `@tas`((ot ~[id+so]) jon)]
    ::
        %'disconnect'
      [%disconnect `@tas`((ot ~[id+so]) jon)]
    ::
        %'revoke'
      [%revoke `@tas`((ot ~[id+so]) jon)]
    ::
        %'force-refresh'
      [%force-refresh `@tas`((ot ~[id+so]) jon)]
    ::
        %'remote-connect'
      ?>  ?=(%o -.jon)
      =/  id-val=json  (~(got by p.jon) 'id')
      =/  rt-val=json  (~(got by p.jon) 'return-to')
      ?>  ?=(%s -.id-val)
      ?>  ?=(%s -.rt-val)
      [%remote-connect `@tas`p.id-val p.rt-val]
    ::
        %'set-relay-url'
      ?>  ?=(%o -.jon)
      =/  url-val=(unit json)  (~(get by p.jon) 'url')
      =/  url=(unit @t)
        ?~  url-val  ~
        ?.  ?=(%s -.u.url-val)  ~
        ?:  =('' p.u.url-val)  ~
        `p.u.url-val
      [%set-relay-url url]
    ::
        %'receive-grant'
      receive-grant
    ==
  ::
  ++  receive-grant
    ^-  action:oauth
    ?>  ?=(%o -.jon)
    =/  pid-val=json  (~(got by p.jon) 'providerId')
    ?>  ?=(%s -.pid-val)
    =/  pid=@tas  `@tas`p.pid-val
    =/  grant-obj=json  (~(got by p.jon) 'grant')
    ?>  ?=(%o -.grant-obj)
    =/  access-val=json  (~(got by p.grant-obj) 'accessToken')
    ?>  ?=(%s -.access-val)
    =/  access=@t  p.access-val
    ::  optional refresh token
    =/  refresh=(unit @t)
      =/  rv=(unit json)  (~(get by p.grant-obj) 'refreshToken')
      ?~  rv  ~
      ?.  ?=(%s -.u.rv)  ~
      ?:  =('' p.u.rv)  ~
      `p.u.rv
    ::  optional token type (default to "Bearer")
    =/  ttype=@t
      =/  tv=(unit json)  (~(get by p.grant-obj) 'tokenType')
      ?~  tv  'Bearer'
      ?.  ?=(%s -.u.tv)  'Bearer'
      ?:  =('' p.u.tv)  'Bearer'
      p.u.tv
    ::  optional expires-at (RFC3339 -> @da via slav)
    =/  expires-at=(unit @da)
      =/  ev=(unit json)  (~(get by p.grant-obj) 'expiresAt')
      ?~  ev  ~
      ?.  ?=(%s -.u.ev)  ~
      ?:  =('' p.u.ev)  ~
      =/  res  (mule |.(`@da`(slav %da p.u.ev)))
      ?:  ?=(%| -.res)  ~
      `p.res
    =/  scopes=@t
      =/  sv=(unit json)  (~(get by p.grant-obj) 'scopes')
      ?~  sv  ''
      ?.  ?=(%s -.u.sv)  ''
      p.u.sv
    =/  g=grant:oauth  [access refresh ttype expires-at scopes pid]
    [%receive-grant pid g]
  --
--
