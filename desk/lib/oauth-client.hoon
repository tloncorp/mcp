::  oauth-client: PKCE, authorization requests, and token exchange
::
/-  oauth
|%
++  make-basic-auth
  |=  [client-id=@t client-secret=@t]
  ^-  @t
  =/  creds=@t  (rap 3 ~[client-id ':' client-secret])
  =/  encoded=@t  (en:base64:mimes:html [(met 3 creds) creds])
  (rap 3 ~['Basic ' encoded])
::
++  token-headers
  |=  cfg=provider-config:oauth
  ^-  (list [@t @t])
  =/  headers=(list [@t @t])
    :~  ['content-type' 'application/x-www-form-urlencoded']
        ['accept' 'application/json']
    ==
  ?:  ?&  =(%basic token-auth.cfg)
          !=('' client-secret.cfg)
      ==
    (snoc headers ['authorization' (make-basic-auth client-id.cfg client-secret.cfg)])
  headers
::
++  build-code-exchange-body
  |=  [cfg=provider-config:oauth code=@t verifier=@t]
  ^-  @t
  =/  body=@t
    %+  rap  3
    :~  'grant_type=authorization_code'
        '&code='
        code
        '&redirect_uri='
        redirect-uri.cfg
        '&code_verifier='
        verifier
    ==
  =?  body
    ?|  =(%body token-auth.cfg)
        =('' client-secret.cfg)
    ==
    (rap 3 ~[body '&client_id=' client-id.cfg])
  =?  body
    ?&  =(%body token-auth.cfg)
        !=('' client-secret.cfg)
    ==
    (rap 3 ~[body '&client_secret=' client-secret.cfg])
  =?  body  ?=(^ token-resource.cfg)
    (rap 3 ~[body '&resource=' u.token-resource.cfg])
  body
::
++  build-refresh-body
  |=  [cfg=provider-config:oauth gra=grant:oauth]
  ^-  @t
  =/  refresh-token=@t  ?~(refresh-token.gra '' u.refresh-token.gra)
  =/  body=@t
    %+  rap  3
    :~  'grant_type=refresh_token'
        '&refresh_token='
        refresh-token
    ==
  =?  body
    ?|  =(%body token-auth.cfg)
        =('' client-secret.cfg)
    ==
    (rap 3 ~[body '&client_id=' client-id.cfg])
  =?  body
    ?&  =(%body token-auth.cfg)
        !=('' client-secret.cfg)
    ==
    (rap 3 ~[body '&client_secret=' client-secret.cfg])
  =?  body  ?=(^ token-resource.cfg)
    (rap 3 ~[body '&resource=' u.token-resource.cfg])
  body
::
++  make-verifier
  |=  eny=@
  ^-  @t
  ::  generate 43-char base64url string from entropy
  ::  shax takes an atom, returns a 256-bit hash as @
  ::
  =/  raw=@  (shax eny)
  =/  b64=@t  (en:base64:mimes:html [32 raw])
  (safe-scag 43 (base64-to-url b64))
::
++  make-challenge
  |=  verifier=@t
  ^-  @t
  ::  SHA-256 hash of verifier bytes, base64url encoded
  ::  trip the cord to get bytes, then hash as atom
  ::
  =/  vt=tape  (trip verifier)
  =/  hash=@  (shax (crip vt))
  =/  b64=@t  (en:base64:mimes:html [32 hash])
  (base64-to-url b64)
::
++  base64-to-url
  |=  b64=@t
  ^-  @t
  ::  convert standard base64 to base64url:
  ::  replace + with -, / with _, strip = padding
  ::
  %-  crip
  %+  turn
    %+  skip  (trip b64)
    |=(c=@tD =(c '='))
  |=  c=@tD
  ?:  =(c '+')  '-'
  ?:  =(c '/')  '_'
  c
::
++  safe-scag
  |=  [n=@ud t=@t]
  ^-  @t
  (crip (scag n (trip t)))
::
++  build-auth-url
  |=  [cfg=provider-config:oauth state=@t challenge=@t]
  ^-  @t
  =/  auth=@t
    %+  rap  3
    :~  auth-url.cfg
        '?client_id='
        client-id.cfg
        '&redirect_uri='
        redirect-uri.cfg
        '&response_type=code'
        '&state='
        state
        '&code_challenge='
        challenge
        '&code_challenge_method=S256'
        '&scope='
        scopes.cfg
    ==
  =?  auth  ?=(^ token-resource.cfg)
    (rap 3 ~[auth '&resource=' u.token-resource.cfg])
  auth
::
++  parse-token-response
  |=  [jon=json pid=provider-id:oauth now=@da]
  ^-  (unit grant:oauth)
  =/  res  (mule |.((parse-token-json jon pid now)))
  ?:  ?=(%& -.res)  `p.res
  ~
::
++  parse-token-json
  |=  [jon=json pid=provider-id:oauth now=@da]
  ^-  grant:oauth
  ?>  ?=(%o -.jon)
  =/  at=@t
    =/  v=(unit json)  (~(get by p.jon) 'access_token')
    ?~  v  ''
    ?.  ?=(%s -.u.v)  ''
    p.u.v
  =/  rt=(unit @t)
    =/  v=(unit json)  (~(get by p.jon) 'refresh_token')
    ?~  v  ~
    ?.  ?=(%s -.u.v)  ~
    `p.u.v
  =/  tt=@t
    =/  v=(unit json)  (~(get by p.jon) 'token_type')
    ?~  v  'Bearer'
    ?.  ?=(%s -.u.v)  'Bearer'
    p.u.v
  =/  exp=(unit @da)
    =/  v=(unit json)  (~(get by p.jon) 'expires_in')
    ?~  v  ~
    =/  res=(each @ud tang)
      %-  mule
      |.
      ?:  ?=(%n -.u.v)  (ni:dejs:format u.v)
      ?:  ?=(%s -.u.v)  (rash p.u.v dem:ag)
      !!
    ?.  ?=(%& -.res)  ~
    `(add now (mul p.res ~s1))
  =/  sc=@t
    =/  v=(unit json)  (~(get by p.jon) 'scope')
    ?~  v  ''
    ?.  ?=(%s -.u.v)  ''
    p.u.v
  [at rt tt exp sc pid]
--
