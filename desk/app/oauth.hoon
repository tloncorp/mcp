::  oauth: OAuth 2.0 + PKCE token management agent
::
::    manages provider configs, handles browser auth flows,
::    stores tokens, auto-refreshes before expiry.
::    other agents scry or subscribe for tokens.
::
/-  oauth
/+  default-agent, dbug, server
|%
+$  card  card:agent:gall
--
::
%-  agent:dbug
=|  state-2:oauth
=*  state  -
=/  refreshing  *(set provider-id:oauth)  ::  in-flight refresh locks (non-persisted)
::  in-flight remote-connect flows: wire-id -> {eyre-id, return-to}
=/  remote-pending  *(map @t [eyre-id=@ta return-to=@t])
::  in-flight relay provider list fetches: wire-id -> eyre-id
=/  relay-list-pending  *(map @t @ta)
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  :_  this
  :~  [%pass /eyre/connect %arvo %e %connect [~ /oauth] %oauth]
  ==
::
++  on-save  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  (mule |.(!<(versioned-state:oauth old-state)))
  ?:  ?=(%| -.old)
    on-init
  =/  new-state=state-2:oauth
    ?-  -.p.old
        %2  p.old
        %1  [%2 (upgrade-provider-map providers.p.old) grants.p.old pending.p.old relay-url.p.old]
        %0  [%2 (upgrade-provider-map providers.p.old) grants.p.old pending.p.old ~]
    ==
  ::  re-register refresh timers for all grants with expiry
  =/  eyre-cards=(list card)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /oauth] %oauth]
    ==
  =/  timer-cards=(list card)
    %+  murn  ~(tap by grants.new-state)
    |=  [pid=provider-id:oauth gra=grant:oauth]
    ?~  expires-at.gra  ~
    ?~  refresh-token.gra  ~
    =/  refresh-time=@da
      =/  margin=@dr  ~m5
      ?:  (gth u.expires-at.gra (add now.bowl margin))
        (sub u.expires-at.gra margin)
      (add now.bowl ~s5)
    `[%pass /timer/refresh/[pid] %arvo %b %wait refresh-time]
  :_  this(state new-state)
  (weld eyre-cards timer-cards)
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark  (on-poke:def mark vase)
      %oauth-action
    (handle-action !<(action:oauth vase))
  ::
      %json
    =/  jon=json  !<(json vase)
    =/  act=(unit action:oauth)  (action-from-json jon)
    ?~  act  `this
    (handle-action u.act)
  ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    (handle-http eyre-id req)
  ==
  ::
  ++  handle-action
    |=  act=action:oauth
    ^-  (quip card _this)
    ?>  =(our src):bowl
    ?-  -.act
    ::
        %add-provider
      ?:  (~(has by providers) id.act)
        ~|(%oauth-provider-exists !!)
      =.  providers  (~(put by providers) id.act config.act)
      `this
    ::
        %remove-provider
      =.  providers  (~(del by providers) id.act)
      =.  grants     (~(del by grants) id.act)
      `this
    ::
        %update-provider
      ::  preserve existing client-secret if the new one is empty
      =/  existing=(unit provider-config:oauth)  (~(get by providers) id.act)
      =/  new-cfg=provider-config:oauth  config.act
      =?  new-cfg  ?&(?=(^ existing) =('' client-secret.new-cfg))
        new-cfg(client-secret client-secret.u.existing)
      =.  providers  (~(put by providers) id.act new-cfg)
      `this
    ::
        %config-provider
      =.  providers  (~(put by providers) id.act config.act)
      `this
    ::
        %connect
      =/  cfg=(unit provider-config:oauth)  (~(get by providers) id.act)
      ?~  cfg
        ~|(%oauth-provider-not-found !!)
      ::  generate PKCE verifier and state
      ::
      =/  raw-eny=@  eny.bowl
      =/  state-param=@t  (scot %uv `@uv`raw-eny)
      =/  verifier=@t  (make-verifier raw-eny)
      =/  challenge=@t  (make-challenge verifier)
      ::  store pending auth
      ::
      =/  pend=pending-auth:oauth
        [state-param verifier id.act]
      =.  pending  (~(put by pending) state-param pend)
      ::  build auth URL
      ::
      =/  auth=@t
        %+  build-auth-url  u.cfg
        [state-param challenge]
      ::  return the URL as a JSON response via fact on /redirects
      ::
      :_  this
      :~  [%give %fact [/redirects]~ %json !>((frond:enjs:format 'url' s+auth))]
      ==
    ::
        %disconnect
      =/  had=?  (~(has by grants) id.act)
      =.  grants  (~(del by grants) id.act)
      ?.  had  `this
      :_  this
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%grant-removed id.act])]
      ==
    ::
        %force-refresh
      ::  trigger immediate token refresh (called by %mcp-proxy on 401)
      =/  gra=(unit grant:oauth)  (~(get by grants) id.act)
      ?~  gra
        ~&  >>  [%oauth %force-refresh-skip id.act %no-grant]
        `this
      ?~  refresh-token.u.gra
        ~&  >>  [%oauth %force-refresh-skip id.act %no-refresh-token]
        `this
      ?:  (~(has in refreshing) id.act)
        ~&  >>  [%oauth %force-refresh-skip id.act %already-refreshing]
        `this
      =/  cfg=(unit provider-config:oauth)  (~(get by providers) id.act)
      ::  no local provider-config: managed grant from the relay,
      ::  client credentials live there. Route refresh through the relay.
      ::
      ?~  cfg
        ?~  relay-url
          ~&  >>  [%oauth %force-refresh-skip id.act %no-config-no-relay]
          `this
        =.  refreshing  (~(put in refreshing) id.act)
        ~&  >  [%oauth %force-refresh-relay id.act]
        =/  body=@t  (build-relay-refresh-body id.act u.refresh-token.u.gra)
        =/  url=@t   (rap 3 ~[u.relay-url '/v1/refresh'])
        :_  this
        :~  :*  %pass  /iris/relay-refresh/[id.act]
                %arvo  %i  %request
                :*  %'POST'
                    url
                    (relay-headers our.bowl now.bowl)
                    `(as-octs:mimes:html body)
                ==
                *outbound-config:iris
            ==
        ==
      =.  refreshing  (~(put in refreshing) id.act)
      =/  body=@t
        (build-refresh-body u.cfg u.gra)
      ~&  >  [%oauth %force-refresh id.act]
      :_  this
      :~  :*  %pass  /iris/token-refresh/[id.act]
              %arvo  %i  %request
              :*  %'POST'
                  token-url.u.cfg
                  (token-headers u.cfg)
                  `(as-octs:mimes:html body)
              ==
              *outbound-config:iris
          ==
      ==
    ::
        %revoke
      =/  gra=(unit grant:oauth)  (~(get by grants) id.act)
      ?~  gra
        ~|(%oauth-no-grant !!)
      =/  cfg=(unit provider-config:oauth)  (~(get by providers) id.act)
      ?~  cfg
        ~|(%oauth-provider-not-found !!)
      ?~  revoke-url.u.cfg
        ::  no revoke endpoint, just disconnect
        ::
        =.  grants  (~(del by grants) id.act)
        :_  this
        :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%grant-removed id.act])]
        ==
      ::  POST revoke request
      ::
      =/  body=@t
        %+  rap  3
        :~  'token='
            access-token.u.gra
            '&client_id='
            client-id.u.cfg
        ==
      :_  this
      :~  :*  %pass  /iris/revoke/[id.act]
              %arvo  %i  %request
              :*  %'POST'
                  u.revoke-url.u.cfg
                  ~[['content-type' 'application/x-www-form-urlencoded']]
                  `(as-octs:mimes:html body)
              ==
              *outbound-config:iris
          ==
      ==
    ::
        %set-relay-url
      =.  relay-url  url.act
      `this
    ::
        %remote-connect
      ::  initiated via handle-http; no-op as a direct agent poke
      `this
    ::
        %receive-grant
      ::  poked locally (pioneer → click thread → %oauth)
      ?>  =(our src):bowl
      ::  on refresh, providers commonly omit refresh_token from the
      ::  response — preserve the existing one so we don't lose the
      ::  ability to refresh again.
      ::
      =/  old=(unit grant:oauth)  (~(get by grants) provider-id.act)
      =/  final=grant:oauth  grant.act
      =?  final  &(?=(^ old) ?=(~ refresh-token.final))
        final(refresh-token refresh-token.u.old)
      =.  grants  (~(put by grants) provider-id.act final)
      ::  schedule refresh timer if there's an expiry
      =/  timer-cards=(list card)
        ?~  expires-at.final  ~
        ?~  refresh-token.final  ~
        =/  refresh-time=@da
          =/  margin=@dr  ~m5
          ?:  (gth u.expires-at.final (add now.bowl margin))
            (sub u.expires-at.final margin)
          (add now.bowl ~s5)
        ^-  (list card)
        :~  [%pass /timer/refresh/[provider-id.act] %arvo %b %wait refresh-time]
        ==
      =/  notify=(list card)
        ^-  (list card)
        :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%grant-added provider-id.act final])]
        ==
      [(weld timer-cards notify) this]
    ::
    ::  dojo introspection: print configuration to dojo. these are
    ::  read-only; they emit ~& side effects and return no cards.
    ::  invoke with `:oauth &oauth-action [%show-providers ~]` etc.
    ::
        %show-providers
      ~&  >  %oauth-providers
      =/  ps=(list [pid=provider-id:oauth cfg=provider-config:oauth])
        ~(tap by providers)
      |-  ^-  (quip card _this)
      ?~  ps  `this
      =/  pid=provider-id:oauth        pid.i.ps
      =/  cfg=provider-config:oauth    cfg.i.ps
      ~&  :*  pid
              auth-url=auth-url.cfg
              token-url=token-url.cfg
              client-id=client-id.cfg
              scopes=scopes.cfg
              token-auth=token-auth.cfg
          ==
      $(ps t.ps)
    ::
        %show-grants
      ~&  >  %oauth-grants
      =/  gs=(list [pid=provider-id:oauth gra=grant:oauth])
        ~(tap by grants)
      |-  ^-  (quip card _this)
      ?~  gs  `this
      =/  pid=provider-id:oauth  pid.i.gs
      =/  gra=grant:oauth        gra.i.gs
      ~&  :*  pid
              token-type=token-type.gra
              scopes=scopes.gra
              has-refresh=?=(^ refresh-token.gra)
              expires-at=expires-at.gra
          ==
      $(gs t.gs)
    ::
        %show-relay
      ~&  [%oauth-relay-url relay-url]
      `this
    ::
        %show-config
      ~&  >  %oauth-config-dump
      ~&  relay-url=relay-url
      ~&  provider-count=~(wyt by providers)
      ~&  grant-count=~(wyt by grants)
      `this
    ==
  ::
  ::  HTTP request handler
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.rl
    ::  /oauth/callback — handle OAuth redirect
    ::
    ?:  ?=([%oauth %callback *] site)
      (handle-callback eyre-id req)
    ::  /oauth/api/* — JSON API
    ::
    ?:  ?=([%oauth %api *] site)
      ?.  authenticated.req
        :_  this
        %+  give-simple-payload:app:server  eyre-id
        (login-redirect:gen:server request.req)
      (handle-api eyre-id req t.t.site)
    ::  no human-facing UI here — the user surface is on horizon/tlonbot,
    ::  the operator surface is the dojo show-* pokes (%show-providers,
    ::  %show-grants, %show-relay, %show-config).
    ::
    :_  this
    (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
  ::
  ::  handle OAuth callback from provider
  ::
  ++  handle-callback
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server  (parse-request-line:server url.request.req)
    =/  params=(list [key=@t value=@t])  args.rl
    =/  code=(unit @t)   (get-param params 'code')
    =/  st=(unit @t)     (get-param params 'state')
    ::  validate params
    ::
    ?~  code
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'text/html']] (some (as-octs:mimes:html '<h1>Error: missing code parameter</h1>')))
    ?~  st
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'text/html']] (some (as-octs:mimes:html '<h1>Error: missing state parameter</h1>')))
    ::  look up pending auth
    ::
    =/  pend=(unit pending-auth:oauth)  (~(get by pending) u.st)
    ?~  pend
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'text/html']] (some (as-octs:mimes:html '<h1>Error: unknown state parameter (expired or invalid)</h1>')))
    ::  look up provider config
    ::
    =/  cfg=(unit provider-config:oauth)  (~(get by providers) provider-id.u.pend)
    ?~  cfg
      =.  pending  (~(del by pending) u.st)
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'text/html']] (some (as-octs:mimes:html '<h1>Error: provider no longer configured</h1>')))
    ::  build token exchange request
    ::
    =/  body=@t
      (build-code-exchange-body u.cfg u.code verifier.u.pend)
    ::  send token exchange via iris, serve wait page
    ::
    :_  this
    %+  weld
      :~  :*  %pass  /iris/token-exchange/[u.st]
              %arvo  %i  %request
              :*  %'POST'
                  token-url.u.cfg
                  (token-headers u.cfg)
                  `(as-octs:mimes:html body)
              ==
              *outbound-config:iris
          ==
      ==
    (give-http eyre-id 200 ~[['content-type' 'text/html']] (some (as-octs:mimes:html callback-html)))
  ::
  ::  JSON API handler
  ::
  ++  handle-api
    |=  [eyre-id=@ta req=inbound-request:eyre site=(list @t)]
    ^-  (quip card _this)
    ?:  =(%'GET' method.request.req)
      ?+  site
        :_  this
        (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
      ::
          [%providers ~]
        :_  this
        (give-json eyre-id (build-providers-json ~))
      ::
          [%grants ~]
        :_  this
        (give-json eyre-id (build-grants-json ~))
      ::
      ::  pass-through list of provider instances the relay supports
      ::
          [%'relay-providers' ~]
        ?~  relay-url
          :_  this
          (give-http eyre-id 503 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay not configured","providers":[]}')))
        =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
        =.  relay-list-pending  (~(put by relay-list-pending) wire-id eyre-id)
        =/  relay-url-full=@t  (rap 3 ~[u.relay-url '/v1/providers'])
        :_  this
        :~  :*  %pass  /iris/relay-list/[wire-id]
                %arvo  %i  %request
                :*  %'GET'
                    relay-url-full
                    ~[['accept' 'application/json']]
                    ~
                ==
                *outbound-config:iris
            ==
        ==
      ==
    ?:  =(%'POST' method.request.req)
      =/  body=@t
        ?~  body.request.req  ''
        `@t`q.u.body.request.req
      =/  jon=(unit json)  (de:json:html body)
      ?~  jon
        :_  this
        (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad json"}')))
      =/  act=(unit action:oauth)  (action-from-json u.jon)
      ?~  act
        :_  this
        (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad action"}')))
      ::  special handling for %connect: return auth URL in response
      ::
      ?:  ?=(%connect -.u.act)
        =/  cfg=(unit provider-config:oauth)  (~(get by providers) id.u.act)
        ?~  cfg
          :_  this
          (give-http eyre-id 404 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"provider not found"}')))
        =/  raw-eny=@  eny.bowl
        =/  state-param=@t  (scot %uv `@uv`raw-eny)
        =/  verifier=@t  (make-verifier raw-eny)
        =/  challenge=@t  (make-challenge verifier)
        =/  pend=pending-auth:oauth  [state-param verifier id.u.act]
        =.  pending  (~(put by pending) state-param pend)
        =/  auth=@t  (build-auth-url u.cfg [state-param challenge])
        =/  resp=@t  (en:json:html (frond:enjs:format 'url' s+auth))
        :_  this
        (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html resp)))
      ::  special handling for %remote-connect: call oauth-proxy relay
      ::
      ?:  ?=(%remote-connect -.u.act)
        ?~  relay-url
          :_  this
          (give-http eyre-id 503 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay not configured"}')))
        ::  scry own +code; used as Bearer token to the relay
        =/  code=@p
          .^(@p %j /(scot %p our.bowl)/code/(scot %da now.bowl)/(scot %p our.bowl))
        =/  code-str=@t  (crip (slag 1 (scow %p code)))
        =/  ship-str=@t  (crip (slag 1 (scow %p our.bowl)))
        ::  look up provider's saved scopes to forward to the relay
        =/  cfg=(unit provider-config:oauth)  (~(get by providers) id.u.act)
        =/  scopes=@t  ?~(cfg '' scopes.u.cfg)
        =/  fields=(list [@t json])
          :~  ['provider' s+(scot %tas id.u.act)]
              ['return_to' s+return-to.u.act]
          ==
        =?  fields  !=('' scopes)
          (snoc fields ['scopes' s+scopes])
        =/  body=@t
          (en:json:html [%o (malt fields)])
        =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
        =.  remote-pending
          (~(put by remote-pending) wire-id [eyre-id return-to.u.act])
        =/  relay-start=@t  (rap 3 ~[u.relay-url '/v1/start'])
        :_  this
        :~  :*  %pass  /iris/relay-start/[wire-id]
                %arvo  %i  %request
                :*  %'POST'
                    relay-start
                    :~  ['content-type' 'application/json']
                        ['accept' 'application/json']
                        ['x-ship' ship-str]
                        ['authorization' (rap 3 ~['Bearer ' code-str])]
                    ==
                    `(as-octs:mimes:html body)
                ==
                *outbound-config:iris
            ==
        ==
      ::  all other actions
      ::
      =/  result  (handle-action u.act)
      :_  +.result
      %+  weld  -.result
      (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"ok":true}')))
    :_  this
    (give-http eyre-id 405 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'method not allowed')))
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%http-response @ ~]
    `this
  ::
      [%grants ~]
    ?>  =(our.bowl src.bowl)
    ::  send initial grant state
    ::
    :_  this
    %+  turn  ~(tap by grants)
    |=  [pid=provider-id:oauth gra=grant:oauth]
    [%give %fact ~ %oauth-update !>(`update:oauth`[%grant-added pid gra])]
  ::
      [%redirects ~]
    `this
  ==
::
++  on-agent  on-agent:def
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
  ::
      [%eyre *]
    ?:  ?=(%bound +<.sign)
      ~?  !accepted.sign  [%oauth %binding-rejected binding.sign]
      `this
    `this
  ::
  ::  relay /v1/providers passthrough: forward the JSON body back to the browser
  ::
      [%iris %relay-list @ ~]
    =/  wire-id=@t  i.t.t.wire
    =/  pnd-eid=(unit @ta)  (~(get by relay-list-pending) wire-id)
    =.  relay-list-pending  (~(del by relay-list-pending) wire-id)
    ?~  pnd-eid  `this
    ?.  ?=([%iris %http-response *] sign)
      :_  this
      (give-http u.pnd-eid 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay unreachable","providers":[]}')))
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      :_  this
      (give-http u.pnd-eid 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay unreachable","providers":[]}')))
    ?.  =(200 status-code.response-header.resp)
      :_  this
      (give-http u.pnd-eid 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay rejected","providers":[]}')))
    ?~  full-file.resp
      :_  this
      (give-http u.pnd-eid 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay empty body","providers":[]}')))
    =/  body=@t  `@t`q.data.u.full-file.resp
    :_  this
    (give-http u.pnd-eid 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html body)))
  ::
  ::  relay /v1/start response: extract authorize_url, 302 the browser
  ::
      [%iris %relay-start @ ~]
    =/  wire-id=@t  i.t.t.wire
    =/  pnd=(unit [eyre-id=@ta return-to=@t])
      (~(get by remote-pending) wire-id)
    =.  remote-pending  (~(del by remote-pending) wire-id)
    ?~  pnd  `this
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%oauth %relay-start-failed %bad-sign]
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay unreachable"}')))
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay unreachable"}')))
    ?.  =(200 status-code.response-header.resp)
      ~&  >>>  [%oauth %relay-start-failed %status status-code.response-header.resp]
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay rejected"}')))
    ?~  full-file.resp
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay empty body"}')))
    =/  body=@t  `@t`q.data.u.full-file.resp
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay bad json"}')))
    ?.  ?=(%o -.u.jon)
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay bad json"}')))
    =/  url-val=(unit json)  (~(get by p.u.jon) 'authorize_url')
    ?~  url-val
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay no url"}')))
    ?.  ?=(%s -.u.url-val)
      :_  this
      (give-http eyre-id.u.pnd 502 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"relay bad url"}')))
    =/  auth-url=@t  p.u.url-val
    ::  respond to the original POST with the URL so the GUI can window.open it
    =/  resp-body=@t  (en:json:html (frond:enjs:format 'url' s+auth-url))
    :_  this
    (give-http eyre-id.u.pnd 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html resp-body)))
  ::
  ::  token exchange response
  ::
      [%iris %token-exchange @ ~]
    =/  st=@t  i.t.t.wire
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%oauth %token-exchange-failed st %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%oauth %token-exchange-failed st %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ~&  >>>  [%oauth %token-exchange-failed st %status status-code.response-header.resp]
      =.  pending  (~(del by pending) st)
      `this
    ?~  full-file.resp
      ~&  >>>  [%oauth %token-exchange-failed st %no-body]
      =.  pending  (~(del by pending) st)
      `this
    =/  body=@t  `@t`q.data.u.full-file.resp
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      ~&  >>>  [%oauth %token-exchange-failed st %bad-json]
      =.  pending  (~(del by pending) st)
      `this
    ::  parse token response
    ::
    =/  pend=(unit pending-auth:oauth)  (~(get by pending) st)
    ?~  pend
      ~&  >>>  [%oauth %token-exchange-failed st %no-pending]
      `this
    =/  gra=(unit grant:oauth)  (parse-token-response u.jon provider-id.u.pend now.bowl)
    ?~  gra
      ~&  >>>  [%oauth %token-exchange-failed st %parse-failed]
      =.  pending  (~(del by pending) st)
      `this
    ::  store grant, clear pending
    ::
    =.  grants   (~(put by grants) provider-id.u.pend u.gra)
    =.  pending  (~(del by pending) st)
    ::  notify subscribers + set refresh timer
    ::
    =/  cards=(list card)
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%grant-added provider-id.u.pend u.gra])]
      ==
    =?  cards  ?=(^ expires-at.u.gra)
      =/  refresh-time=@da
        =/  exp=@da  u.expires-at.u.gra
        =/  margin=@dr  ~m5
        ?:  (gth exp (add now.bowl margin))
          (sub exp margin)
        (add now.bowl ~s30)
      (snoc cards [%pass /timer/refresh/[provider-id.u.pend] %arvo %b %wait refresh-time])
    [cards this]
  ::
  ::  token refresh response
  ::
      [%iris %token-refresh @ ~]
    =/  pid=provider-id:oauth  i.t.t.wire
    =.  refreshing  (~(del in refreshing) pid)
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%oauth %refresh-failed pid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%oauth %refresh-failed pid %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ::  check for invalid_grant (requires re-auth, not retry)
      =/  err-body=@t
        ?~  full-file.resp  ''
        `@t`q.data.u.full-file.resp
      =/  is-invalid=?
        !=(~ (find "invalid_grant" (trip err-body)))
      ~&  >>>  [%oauth %refresh-failed pid %status status-code.response-header.resp ?:(is-invalid %invalid-grant %other)]
      ::  remove grant if invalid_grant (forces re-auth)
      =?  grants  is-invalid  (~(del by grants) pid)
      :_  this
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%token-expired pid])]
      ==
    ?~  full-file.resp
      ~&  >>>  [%oauth %refresh-failed pid %no-body]
      `this
    =/  body=@t  `@t`q.data.u.full-file.resp
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      ~&  >>>  [%oauth %refresh-failed pid %bad-json]
      `this
    =/  gra=(unit grant:oauth)  (parse-token-response u.jon pid now.bowl)
    ?~  gra
      ~&  >>>  [%oauth %refresh-failed pid %parse-failed]
      :_  this
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%token-expired pid])]
      ==
    ::  preserve refresh token if new one not provided
    ::
    =/  old=(unit grant:oauth)  (~(get by grants) pid)
    =/  final=grant:oauth
      ?:  &(?=(^ old) ?=(~ refresh-token.u.gra))
        u.gra(refresh-token refresh-token.u.old)
      u.gra
    ~&  >  [%oauth %grant-refreshed pid expires-at.final]
    =.  grants  (~(put by grants) pid final)
    =/  cards=(list card)
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%grant-refreshed pid final])]
      ==
    =?  cards  ?=(^ expires-at.final)
      =/  refresh-time=@da
        =/  exp=@da  u.expires-at.final
        =/  margin=@dr  ~m5
        ?:  (gth exp (add now.bowl margin))
          (sub exp margin)
        (add now.bowl ~s30)
      (snoc cards [%pass /timer/refresh/[pid] %arvo %b %wait refresh-time])
    [cards this]
  ::
  ::  revoke response
  ::
      [%iris %revoke @ ~]
    =/  pid=provider-id:oauth  i.t.t.wire
    =.  grants  (~(del by grants) pid)
    :_  this
    :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%grant-removed pid])]
    ==
  ::
  ::  relay refresh response: clear the single-flight lock and log.
  ::  the actual grant update arrives separately when the relay pokes
  ::  pioneer, which click-pokes %receive-grant on this agent.
  ::
      [%iris %relay-refresh @ ~]
    =/  pid=provider-id:oauth  i.t.t.wire
    =.  refreshing  (~(del in refreshing) pid)
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%oauth %relay-refresh-failed pid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%oauth %relay-refresh-failed pid %not-finished]
      `this
    =/  status=@ud  status-code.response-header.resp
    ?.  &((gte status 200) (lth status 300))
      =/  err-body=@t
        ?~  full-file.resp  ''
        =/  b=@t  `@t`q.data.u.full-file.resp
        ?:  (gth (met 3 b) 500)  (cat 3 (cut 3 [0 500] b) '...[truncated]')
        b
      ~&  >>>  [%oauth %relay-refresh-failed pid %status status err-body]
      :_  this
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%token-expired pid])]
      ==
    ~&  >  [%oauth %relay-refresh-ok pid]
    `this
  ::
  ::  refresh timer
  ::
      [%timer %refresh @ ~]
    =/  pid=provider-id:oauth  i.t.t.wire
    ?.  ?=([%behn %wake *] sign)  `this
    ::  single-flight: skip if already refreshing
    ?:  (~(has in refreshing) pid)  `this
    =/  gra=(unit grant:oauth)  (~(get by grants) pid)
    ?~  gra  `this
    ::  stale-timer guard: schedule sites always %wait at
    ::  expires-at - 5min, so a current timer fires within ~5min of
    ::  the grant's expiry. If expires-at is far in the future, this
    ::  timer was orphaned by a more recent refresh that pushed the
    ::  expiry out — skip it rather than refresh redundantly.
    ::
    ?:  ?&  ?=(^ expires-at.u.gra)
            (gth u.expires-at.u.gra (add now.bowl ~m10))
        ==
      ~&  >>  [%oauth %skip-stale-refresh-timer pid]
      `this
    ?~  refresh-token.u.gra
      :_  this
      :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%token-expired pid])]
      ==
    =/  cfg=(unit provider-config:oauth)  (~(get by providers) pid)
    ::  managed grant (no local config): route through relay if available
    ::
    ?~  cfg
      ?~  relay-url
        :_  this
        :~  [%give %fact [/grants]~ %oauth-update !>(`update:oauth`[%token-expired pid])]
        ==
      =.  refreshing  (~(put in refreshing) pid)
      =/  body=@t  (build-relay-refresh-body pid u.refresh-token.u.gra)
      =/  url=@t   (rap 3 ~[u.relay-url '/v1/refresh'])
      :_  this
      :~  :*  %pass  /iris/relay-refresh/[pid]
              %arvo  %i  %request
              :*  %'POST'
                  url
                  (relay-headers our.bowl now.bowl)
                  `(as-octs:mimes:html body)
              ==
              *outbound-config:iris
          ==
      ==
    =.  refreshing  (~(put in refreshing) pid)
    =/  body=@t
      (build-refresh-body u.cfg u.gra)
    :_  this
    :~  :*  %pass  /iris/token-refresh/[pid]
            %arvo  %i  %request
            :*  %'POST'
                token-url.u.cfg
                (token-headers u.cfg)
                `(as-octs:mimes:html body)
            ==
            *outbound-config:iris
        ==
    ==
  ==
::
++  on-leave  on-leave:def
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?>  =(our src):bowl
  ?+  path  [~ ~]
      [%x %grant @ ~]
    =/  pid=provider-id:oauth  `@tas`i.t.t.path
    =/  gra=(unit grant:oauth)  (~(get by grants) pid)
    ?~  gra  [~ ~]
    ``noun+!>(u.gra)
  ::
      [%x %providers ~]
    ``noun+!>(providers)
  ::
      ::  /x/grants: sanitized grant list for platform clients.
      ::  Return %json directly so Clay does not need a custom grants mark
      ::  during Kelvin upgrade. Never exposes access/refresh tokens.
      ::
      [%x %grants ~]
    ``json+!>((build-grants-scry-json now.bowl))
  ::
      [%x %has-grant @ ~]
    =/  pid=provider-id:oauth  `@tas`i.t.t.path
    ``noun+!>((~(has by grants) pid))
  ::
      ::  /x/token/<provider-id>: get access token as @t
      ::  returns the token if valid, or '' if expired/missing
      ::  callers should poke %oauth with %connect if '' is returned
      ::
      [%x %token @ ~]
    =/  pid=provider-id:oauth  `@tas`i.t.t.path
    =/  gra=(unit grant:oauth)  (~(get by grants) pid)
    ?~  gra  ``noun+!>(`@t`'')
    ::  check if expired
    ?:  ?&  ?=(^ expires-at.u.gra)
            (lth u.expires-at.u.gra now.bowl)
        ==
      ``noun+!>(`@t`'')
    ``noun+!>(access-token.u.gra)
  ::
      ::  /x/auth-header/<provider-id>: get full Authorization header
      ::  e.g. "Bearer xxx" - ready to use as header value
      ::
      ::  always emits "Bearer " regardless of what token-type the
      ::  provider returned (e.g. Linear returns lowercase "bearer"
      ::  in their token response but then strictly case-matches on
      ::  "Bearer" in the resource server, rejecting lowercase as
      ::  "invalid_token - missing or invalid access token")
      ::
      [%x %auth-header @ ~]
    =/  pid=provider-id:oauth  `@tas`i.t.t.path
    =/  gra=(unit grant:oauth)  (~(get by grants) pid)
    ?~  gra  ``noun+!>(`@t`'')
    ?:  ?&  ?=(^ expires-at.u.gra)
            (lth u.expires-at.u.gra now.bowl)
        ==
      ``noun+!>(`@t`'')
    ``noun+!>((rap 3 ~['Bearer ' access-token.u.gra]))
  ==
::
++  on-fail  on-fail:def
--
::
::  helper core
::
|%
::
::  PKCE helpers
::
++  upgrade-provider-map
  |=  old=(map provider-id:oauth provider-config-1:oauth)
  ^-  (map provider-id:oauth provider-config:oauth)
  %-  ~(gas by *(map provider-id:oauth provider-config:oauth))
  %+  turn  ~(tap by old)
  |=  [pid=provider-id:oauth cfg=provider-config-1:oauth]
  [pid (upgrade-provider-config cfg)]
::
++  upgrade-provider-config
  |=  cfg=provider-config-1:oauth
  ^-  provider-config:oauth
  [auth-url.cfg token-url.cfg revoke-url.cfg client-id.cfg client-secret.cfg redirect-uri.cfg scopes.cfg ~ %basic]
::
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
  =?  body  ?|  =(%body token-auth.cfg)
                =('' client-secret.cfg)
            ==
    (rap 3 ~[body '&client_id=' client-id.cfg])
  =?  body  ?&  =(%body token-auth.cfg)
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
  =?  body  ?|  =(%body token-auth.cfg)
                =('' client-secret.cfg)
            ==
    (rap 3 ~[body '&client_id=' client-id.cfg])
  =?  body  ?&  =(%body token-auth.cfg)
                 !=('' client-secret.cfg)
             ==
    (rap 3 ~[body '&client_secret=' client-secret.cfg])
  =?  body  ?=(^ token-resource.cfg)
    (rap 3 ~[body '&resource=' u.token-resource.cfg])
  body
::
::  body for POST <relay>/v1/refresh: provider id + current refresh token
::
++  build-relay-refresh-body
  |=  [pid=provider-id:oauth refresh-token=@t]
  ^-  @t
  %-  en:json:html
  :-  %o
  %-  malt
  :~  ['provider' s+(scot %tas pid)]
      ['refresh_token' s+refresh-token]
  ==
::
::  HTTP headers for relay-mediated calls: bearer is the ship's +code
::
++  relay-headers
  |=  [our=@p now=@da]
  ^-  (list [@t @t])
  =/  code=@p
    .^(@p %j /(scot %p our)/code/(scot %da now)/(scot %p our))
  =/  code-str=@t  (crip (slag 1 (scow %p code)))
  =/  ship-str=@t  (crip (slag 1 (scow %p our)))
  :~  ['content-type' 'application/json']
      ['accept' 'application/json']
      ['x-ship' ship-str]
      ['authorization' (rap 3 ~['Bearer ' code-str])]
  ==
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
::  URL builder
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
::  query param extractor
::
++  get-param
  |=  [params=(list [key=@t value=@t]) key=@t]
  ^-  (unit @t)
  =/  match=(list [key=@t value=@t])
    (skim params |=([k=@t v=@t] =(k key)))
  ?~  match  ~
  `value.i.match
::
::  token response parser
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
      %-  mule  |.
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
::
::  JSON action parser (for HTTP API)
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
  ==
::
::  JSON builders
::
++  build-providers-json
  |=  ~
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  :-  'providers'
      :-  %a
      %+  turn  ~(tap by providers)
      |=  [pid=provider-id:oauth cfg=provider-config:oauth]
      %-  pairs
      :~  ['id' s+(scot %tas pid)]
          ['name' s+(scot %tas pid)]
          ['authUrl' s+auth-url.cfg]
          ['tokenUrl' s+token-url.cfg]
          :-  'revokeUrl'
          ?~  revoke-url.cfg  ~
          s+u.revoke-url.cfg
          ['clientId' s+client-id.cfg]
          ['redirectUri' s+redirect-uri.cfg]
          ['scopes' s+scopes.cfg]
          :-  'tokenResource'
          ?~  token-resource.cfg  ~
          s+u.token-resource.cfg
          ['tokenAuth' s+?:(?=(%body token-auth.cfg) 'body' 'basic')]
          ['hasSecret' b+!=('' client-secret.cfg)]
          ['hasGrant' b+(~(has by grants) pid)]
      ==
  ==
::
++  build-grants-json
  |=  ~
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  :-  'grants'
      :-  %a
      %+  turn  ~(tap by grants)
      |=  [pid=provider-id:oauth gra=grant:oauth]
      %-  pairs
      :~  ['providerId' s+(scot %tas pid)]
          ['tokenType' s+token-type.gra]
          ['scopes' s+scopes.gra]
          :-  'expiresAt'
          ?~  expires-at.gra  ~
          s+(scot %da u.expires-at.gra)
          ['hasRefreshToken' b+?=(^ refresh-token.gra)]
      ==
  ==
::
++  build-grants-scry-json
  |=  at=@da
  ^-  json
  =,  enjs:format
  :-  %a
  %+  turn  ~(tap by grants)
  |=  [pid=provider-id:oauth gra=grant:oauth]
  =/  is-expired=?
    ?~  expires-at.gra  %.n
    (lth u.expires-at.gra at)
  %-  pairs
  :~  ['provider' s+(scot %tas pid)]
      ['connected' b+!is-expired]
      ['tokenType' s+token-type.gra]
      ['scopes' s+scopes.gra]
      ['hasRefreshToken' b+?=(^ refresh-token.gra)]
    ::
      :-  'expiresAt'
      ?~  expires-at.gra  ~
      s+(scot %da u.expires-at.gra)
    ::
      ['expired' b+is-expired]
  ==
::
::  HTTP helpers
::
++  give-http
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  [[status headers] body]
::
++  give-json
  |=  [eyre-id=@ta jon=json]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  (json-response:gen:server jon)
::
::  static content
::
++  callback-html
  ^-  @t
  '''
  <!DOCTYPE html>
  <html>
  <head><title>OAuth - Processing</title></head>
  <body style="font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0;">
    <div style="text-align: center;">
      <h2>Authorization received</h2>
      <p>Exchanging token... you can close this tab.</p>
      <p><a href="/oauth">Back to OAuth Manager</a></p>
    </div>
  </body>
  </html>
  '''
::
--
