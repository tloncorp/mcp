::  mcp-proxy: proxy for remote MCP servers
::
::    configure remote MCP server endpoints via dojo pokes
::    (mcp-proxy-action) or via JSON to /apps/mcp/api.
::    point an LLM at /apps/mcp/mcp for an aggregate endpoint
::    that combines tools from all configured servers.
::    or /apps/mcp/mcp/{server-id} for a single server.
::
/-  mcp-proxy
/-  oauth
/+  default-agent, dbug, server
|%
+$  card  card:agent:gall
::
+$  agg-request
  $:  eyre-id=@ta
      req-id=json
      method=@t
      total=@ud
      results=(map server-id:mcp-proxy (unit json))
  ==
--
::
%-  agent:dbug
=|  state-5:mcp-proxy
=*  state  -
=/  pending  *(map @t @ta)
=/  wrap-set  *(map @t json)                      ::  wire-id -> client's JSON-RPC id (for MCP wrapping)
=/  cookies  *(map server-id:mcp-proxy @t)
=/  agg-pending  *(map @t agg-request)
=/  spec-cache  *(map server-id:mcp-proxy json)
::  cached tool list per proxy upstream — populated as a side
::  effect of fan-out, used by code-mode meta tools to search
::  without round-tripping back to upstreams.
=/  proxy-tools-cache  *(map server-id:mcp-proxy (list json))
::  401 retry plumbing. when an iris call to an upstream returns 401
::  AND the call carried an oauth bearer, stash the wire's iris request
::  here and trigger %force-refresh on %oauth. when the new grant fact
::  arrives, replay the request once with the rotated bearer. wires in
::  retried-wires are not retried a second time.
=/  retry-context  *(map @t [pid=@tas request=request:http])
=/  retried-wires  *(set @t)
::  MCP Streamable HTTP session ids per upstream proxy server.
::  Servers like PostHog assign a session id in the initialize
::  response and reject every subsequent call without an
::  Mcp-Session-Id header that echoes it. Linear is lenient and
::  works without sessions; we keep this map populated only for
::  servers that actually return a session id.
=/  mcp-sessions  *(map server-id:mcp-proxy @t)
::  wire-id -> server-id, so when an iris response on /iris/proxy/<wid>
::  arrives we know which server's mcp-sessions entry to update from
::  the response's Mcp-Session-Id header (some servers rotate per
::  request, e.g. Supabase, Ref).
=/  wire-server  *(map @t server-id:mcp-proxy)
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  =/  initial-key=@t  (gen-token eny.bowl)
  =.  code-mode  %.y
  =.  client-key  `initial-key
  =/  sid=@tas  (self-id our.bowl)
  =/  self-url=@t  (build-self-url our.bowl now.bowl)
  =/  auth-header=header:mcp-proxy  ['x-api-key' initial-key]
  =/  self-srv=mcp-server:mcp-proxy
    :*  'Urbit MCP server'
        self-url
        ~[auth-header]
        %.y  ~  %proxy  ~
    ==
  =.  servers  (~(put by servers) sid self-srv)
  =.  server-order  [sid server-order]
  =/  base=(list card)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /apps/mcp/api] %mcp-proxy]
        [%pass /eyre/mcp %arvo %e %connect [~ /apps/mcp/mcp] %mcp-proxy]
        (sync-server-key-card our.bowl initial-key)
    ==
  =?  base  !(~(has by wex.bowl) /oauth/grants [our.bowl %oauth])
    :_(base [%pass /oauth/grants %agent [our.bowl %oauth] %watch /grants])
  =/  prime-cards=(list card)
    (prime-proxy-cards servers server-order cookies our.bowl now.bowl)
  :_  this
  (weld base prime-cards)
::
++  on-save  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  (mule |.(!<(versioned-state:mcp-proxy old-state)))
  ?:  ?=(%| -.old)
    on-init
  =/  eyre-cards=(list card)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /apps/mcp/api] %mcp-proxy]
        [%pass /eyre/mcp %arvo %e %connect [~ /apps/mcp/mcp] %mcp-proxy]
    ==
  =?  eyre-cards  !(~(has by wex.bowl) /oauth/grants [our.bowl %oauth])
    :_(eyre-cards [%pass /oauth/grants %agent [our.bowl %oauth] %watch /grants])
  =/  raw-state=state-5:mcp-proxy
    ?-  -.p.old
        %5  p.old
        %4  [%5 servers.p.old server-order.p.old tool-filters.p.old client-key.p.old internal-token.p.old %.n]
        %3  [%5 servers.p.old server-order.p.old tool-filters.p.old ~ ~ %.n]
        %2  [%5 servers.p.old server-order.p.old ~ ~ ~ %.n]
    ::
        %1
      =/  new-servers=(map server-id:mcp-proxy mcp-server:mcp-proxy)
        %-  ~(run by servers.p.old)
        |=(s=mcp-server-1:mcp-proxy [name.s url.s headers.s enabled.s oauth-provider.s %proxy ~])
      [%5 new-servers server-order.p.old ~ ~ ~ %.n]
    ::
        %0
      =/  new-servers=(map server-id:mcp-proxy mcp-server:mcp-proxy)
        %-  ~(run by servers.p.old)
        |=(s=mcp-server-0:mcp-proxy [name.s url.s headers.s enabled.s ~ %proxy ~])
      [%5 new-servers server-order.p.old ~ ~ ~ %.n]
    ==
  ::  ensure a client-key exists; generate if missing
  =/  ensured-key=@t
    ?~  client-key.raw-state  (gen-token eny.bowl)
    u.client-key.raw-state
  ::  rename any legacy %urbit-mcp upstream to the @p-derived id, and
  ::  ensure it exists with the right key + auto-derived loopback URL
  =/  sid=@tas  (self-id our.bowl)
  =/  legacy=(unit mcp-server:mcp-proxy)  (~(get by servers.raw-state) %urbit-mcp)
  =/  current=(unit mcp-server:mcp-proxy)  (~(get by servers.raw-state) sid)
  =/  prev=(unit mcp-server:mcp-proxy)  ?~(current legacy current)
  =/  url=@t
    ?~  prev  (build-self-url our.bowl now.bowl)
    ::  refresh stale derivations: the old hardcoded port, or a
    ::  boot-time eyre ports scry that ran before eyre bound a real
    ::  port and produced a portless or port-0 loopback
    ?:  ?|  =('http://localhost:8080/mcp' url.u.prev)
            =('http://localhost/mcp' url.u.prev)
            =('http://localhost:0/mcp' url.u.prev)
        ==
      (build-self-url our.bowl now.bowl)
    url.u.prev
  =/  auth-header=header:mcp-proxy  ['x-api-key' ensured-key]
  =/  self-srv=mcp-server:mcp-proxy
    :*  'Urbit MCP server'
        url
        ~[auth-header]
        %.y  ~  %proxy  ~
    ==
  =/  servers-no-legacy=(map server-id:mcp-proxy mcp-server:mcp-proxy)
    (~(del by servers.raw-state) %urbit-mcp)
  =/  patched-servers=(map server-id:mcp-proxy mcp-server:mcp-proxy)
    (~(put by servers-no-legacy) sid self-srv)
  =/  order-no-legacy=(list server-id:mcp-proxy)
    (skip server-order.raw-state |=(s=server-id:mcp-proxy =(s %urbit-mcp)))
  =/  patched-order=(list server-id:mcp-proxy)
    ?:  (~(has in (sy order-no-legacy)) sid)
      order-no-legacy
    [sid order-no-legacy]
  =/  new-state=state-5:mcp-proxy
    raw-state(client-key `ensured-key, servers patched-servers, server-order patched-order, code-mode %.y)
  ::  re-fetch specs for openapi servers (cache is non-persisted)
  =/  spec-cards=(list card)
    %+  murn  ~(tap by servers.new-state)
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    ?.  =(%openapi mode.srv)  ~
    ?~  schema-url.srv  ~
    %-  some
    :*  %pass  /iris/spec/[sid]
        %arvo  %i  %request
        [%'GET' u.schema-url.srv ~[['accept' 'application/json']] ~]
        *outbound-config:iris
    ==
  ::  re-sync key with mcp-server every load (idempotent)
  =/  sync-cards=(list card)  ~[(sync-server-key-card our.bowl ensured-key)]
  ::  re-prime tools/list for proxy upstreams, including the native
  ::  self /mcp upstream, so code-mode search has the default Urbit
  ::  tools before any client connects.
  =/  prime-cards=(list card)
    %+  prime-proxy-cards  servers.new-state
    [server-order.new-state cookies our.bowl now.bowl]
  ::  those primes can't attach OAuth headers (scrying %oauth during
  ::  desk revival can suspend the desk), so oauth-linked upstreams
  ::  401 and stay out of the code-mode cache. re-prime them with
  ::  tokens once the desk is fully live.
  =/  oauth-prime-cards=(list card)
    %+  murn  ~(tap by servers.new-state)
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    ^-  (unit card)
    ?~  oauth-provider.srv  ~
    `[%pass /prime-oauth/[sid] %arvo %b %wait (add now.bowl ~s10)]
  :_  this(state new-state)
  :(weld eyre-cards sync-cards spec-cards prime-cards oauth-prime-cards)
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark  (on-poke:def mark vase)
      %mcp-proxy-action
    (handle-action !<(action:mcp-proxy vase))
  ::
      %json
    =/  jon=json  !<(json vase)
    =/  act=(unit action:mcp-proxy)  (parse-json-action jon)
    ?~  act  `this
    (handle-action u.act)
  ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    (handle-http eyre-id req)
  ==
  ::
  ++  handle-action
    |=  act=action:mcp-proxy
    ^-  (quip card _this)
    ?>  =(src.bowl our.bowl)
    ?-  -.act
        %add-server
      ?:  (~(has by servers) id.act)  `this
      =.  servers  (~(put by servers) id.act mcp-server.act)
      =.  server-order  (snoc server-order id.act)
      `this
        %config-oauth-server
      =/  existed=?  (~(has by servers) id.act)
      =.  servers  (~(put by servers) id.act mcp-server.act)
      =?  server-order  !existed
        (snoc server-order id.act)
      ?:  ?&(=(%openapi mode.mcp-server.act) ?=(^ schema-url.mcp-server.act))
        (fetch-spec id.act u.schema-url.mcp-server.act)
      ?:  =(%proxy mode.mcp-server.act)
        =/  c=(unit card)
          %-  prime-one-proxy-card
          [id.act mcp-server.act (~(get by cookies) id.act) our.bowl now.bowl]
        ?~  c  `this
        :_  this  ~[u.c]
      `this
        %remove-server
      =.  servers  (~(del by servers) id.act)
      =.  server-order  (skip server-order |=(s=server-id:mcp-proxy =(s id.act)))
      =.  cookies  (~(del by cookies) id.act)
      `this
        %update-server
      =.  servers  (~(put by servers) id.act mcp-server.act)
      `this
        %toggle-server
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) id.act)
      ?~  srv  `this
      =.  servers  (~(put by servers) id.act u.srv(enabled !enabled.u.srv))
      `this
        %refresh-spec
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) id.act)
      ?~  srv  `this
      ?:  =(%openapi mode.u.srv)
        ?~  schema-url.u.srv  `this
        (fetch-spec id.act u.schema-url.u.srv)
      ::  proxy mode: re-prime tools/list cache for this upstream
      =/  c=(unit card)
        %-  prime-one-proxy-card
        [id.act u.srv (~(get by cookies) id.act) our.bowl now.bowl]
      ?~  c  `this
      :_  this  ~[u.c]
    ::
        %set-tool-filter
      =.  tool-filters  (~(put by tool-filters) id.act tool-filter.act)
      `this
    ::
        %clear-tool-filter
      =.  tool-filters  (~(del by tool-filters) id.act)
      `this
    ::
        %login-server
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) id.act)
      ?~  srv
        ~&  >>>  [%mcp-proxy %server-not-found id.act]
        `this
      (do-login id.act u.srv)
    ::
        %set-client-key
      =^  cards  state  (apply-key key.act)
      [cards this]
    ::
        %regenerate-client-key
      =^  cards  state  (apply-key (gen-token eny.bowl))
      [cards this]
    ::
        %clear-client-key
      =.  client-key  ~
      :_  this
      ~[(sync-server-key-card our.bowl '')]
    ::
        %set-internal-token
      ::  legacy: a no-op now that mcp-proxy owns the key
      `this
    ::
        %set-code-mode
      =.  code-mode  %.y
      `this
    ==
  ::
  ++  apply-key
    |=  new-key=@t
    ^-  (quip card state-5:mcp-proxy)
    =.  client-key  `new-key
    ::  ensure self upstream exists with the new key as its x-api-key header
    =/  sid=@tas  (self-id our.bowl)
    =/  prev=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
    =/  url=@t
      ?~  prev  (build-self-url our.bowl now.bowl)
      url.u.prev
    =/  auth-header=header:mcp-proxy  ['x-api-key' new-key]
    =/  self-srv=mcp-server:mcp-proxy
      :*  'Urbit MCP server'
          url
          ~[auth-header]
          %.y  ~  %proxy  ~
      ==
    =.  servers  (~(put by servers) sid self-srv)
    =?  server-order  !(~(has in (sy server-order)) sid)
      [sid server-order]
    :_  state
    ~[(sync-server-key-card our.bowl new-key)]
  ::
  ++  do-login
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    ^-  (quip card _this)
    =/  code=@p
      .^(@p %j /(scot %p our.bowl)/code/(scot %da now.bowl)/(scot %p our.bowl))
    =/  pass=@t  (scot %p code)
    =/  base=@t  (get-base-url url.srv)
    =/  login-url=@t  (cat 3 base '/~/login')
    =/  body=@t  (cat 3 'password=' pass)
    :_  this
    :~  :*  %pass  /iris/login/[sid]
            %arvo  %i  %request
            [%'POST' login-url ~[['content-type' 'application/x-www-form-urlencoded']] `(as-octs:mimes:html body)]
            *outbound-config:iris
        ==
    ==
  ::
  ++  fetch-spec
    |=  [sid=server-id:mcp-proxy url=@t]
    ^-  (quip card _this)
    :_  this
    :~  :*  %pass  /iris/spec/[sid]
            %arvo  %i  %request
            [%'GET' url ~[['accept' 'application/json']] ~]
            *outbound-config:iris
        ==
    ==
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.rl
    ?:  ?=([%apps %mcp %mcp *] site)
      =/  rest=(list @t)  t.t.t.site
      ::  aggregate endpoint: /apps/mcp/mcp or /apps/mcp/mcp/
      ::
      ?:  |(=(~ rest) ?=([%$ ~] rest))
        (handle-agg eyre-id req)
      ::  single-server proxy: /apps/mcp/mcp/{server-id}
      ::
      (handle-mcp eyre-id req rest)
    ?.  ?=([%apps %mcp %api *] site)
      :_  this
      (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    =/  api-path=(list @t)  t.t.t.site
    ?.  authenticated.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.req)
    ?:  =(%'GET' method.request.req)
      (handle-get eyre-id api-path)
    ?:  =(%'POST' method.request.req)
      (handle-post eyre-id req)
    :_  this
    (give-http eyre-id 405 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'method not allowed')))
  ::
  ++  handle-get
    |=  [eyre-id=@ta site=(list @t)]
    ^-  (quip card _this)
    ?+  site
      :_  this
      (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
        [%servers ~]
      :_  this
      (give-json eyre-id (build-servers-json ~))
    ::
        [%client-key ~]
      :_  this
      %+  give-json  eyre-id
      %-  pairs:enjs:format
      :~  :-  'clientKey'
          ?~  client-key  ~
          s+u.client-key
          ['hasKey' b+?=(^ client-key)]
          ['codeMode' b+%.y]
      ==
    ::
        [%tools @ ~]
      ::  list tools for a specific server
      =/  sid=server-id:mcp-proxy  `@tas`i.t.site
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
      ?~  srv
        :_  this
        (give-json eyre-id (pairs:enjs:format ~[['tools' a+~]]))
      ?:  =(%openapi mode.u.srv)
        ::  openapi: generate from cached spec
        =/  spec=(unit json)  (~(get by spec-cache) sid)
        ?~  spec
          :_  this
          (give-json eyre-id (pairs:enjs:format ~[['tools' a+~]]))
        =/  tools=(list json)  (apply-tool-filter sid (spec-to-tools sid u.spec) tool-filters)
        :_  this
        (give-json eyre-id (pairs:enjs:format ~[['tools' a+tools]]))
      ::  proxy: fetch tools/list from upstream via iris
      =/  upstream-body=@t
        %-  en:json:html
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']  ['method' s+'tools/list']
            ['id' (numb:enjs:format 1)]  ['params' (pairs:enjs:format ~)]
        ==
      =/  out-headers=(list [key=@t value=@t])
        %+  weld
          ::  MCP Streamable HTTP requires advertising both json and
          ::  SSE; Linear returns SSE by default and 401s us as
          ::  "invalid_token" if we don't accept it
          :~  ['content-type' 'application/json']
              ['accept' 'application/json, text/event-stream']
              ['mcp-protocol-version' '2025-03-26']
              ['user-agent' 'urbit-mcp']
          ==
        headers.u.srv
      =/  cookie=(unit @t)  (~(get by cookies) sid)
      =?  out-headers  ?=(^ cookie)
        (snoc out-headers ['cookie' u.cookie])
      =/  oauth-hdr=(unit [key=@t value=@t])
        (get-oauth-header oauth-provider.u.srv our.bowl now.bowl)
      =?  out-headers  ?=(^ oauth-hdr)
        (snoc out-headers u.oauth-hdr)
      =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
      =.  pending  (~(put by pending) wire-id eyre-id)
      :_  this
      :~  [%pass /iris/toolsapi/[sid]/[wire-id] %arvo %i %request [%'POST' url.u.srv out-headers `(as-octs:mimes:html upstream-body)] *outbound-config:iris]
      ==
    ==
  ::
  ++  handle-post
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  body=@t
      ?~  body.request.req  ''
      `@t`q.u.body.request.req
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      :_  this
      (give-http eyre-id 400 ~[cors] (some (as-octs:mimes:html '{"error":"bad json"}')))
    =/  act=(unit action:mcp-proxy)  (parse-json-action u.jon)
    ?~  act
      :_  this
      (give-http eyre-id 400 ~[cors] (some (as-octs:mimes:html '{"error":"bad action"}')))
    =/  result  (handle-action u.act)
    :_  +.result
    %+  weld  -.result
    (give-http eyre-id 200 ~[cors] (some (as-octs:mimes:html '{"ok":true}')))
  ::
  ::  extract x-api-key header value (case-insensitive)
  ::
  ++  get-api-key-header
    |=  req=inbound-request:eyre
    ^-  (unit @t)
    =/  hdrs=(list [key=@t value=@t])  header-list.request.req
    |-  ^-  (unit @t)
    ?~  hdrs  ~
    ?:  =((cass (trip key.i.hdrs)) "x-api-key")  `value.i.hdrs
    $(hdrs t.hdrs)
  ::
  ::  verify x-api-key header matches stored client-key
  ::
  ++  check-client-key
    |=  req=inbound-request:eyre
    ^-  ?
    ?~  client-key  %.n
    =/  supplied=(unit @t)  (get-api-key-header req)
    ?~  supplied  %.n
    =(u.supplied u.client-key)
  ::
  ::  aggregate endpoint: combine tools from all servers
  ::
  ++  handle-agg
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    ::  CORS
    ?:  =(%'OPTIONS' method.request.req)
      :_  this
      %-  give-http  :^  eyre-id  204
      :~  cors
          ['access-control-allow-methods' 'GET, POST, DELETE, OPTIONS']
          ['access-control-allow-headers' 'Content-Type, Accept, Authorization, Mcp-Session-Id, X-Api-Key']
          ['access-control-expose-headers' 'Mcp-Session-Id']
          ['access-control-max-age' '86400']
      ==
      ~
    ::  require client-key to be set
    ?~  client-key
      :_  this
      %-  give-http  :^  eyre-id  503
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"proxy not configured: set an x-api-key via the GUI"}'))
    ::  verify x-api-key header
    ?.  (check-client-key req)
      :_  this
      %-  give-http  :^  eyre-id  401
      ~[cors ['content-type' 'application/json'] ['www-authenticate' 'X-Api-Key']]
      (some (as-octs:mimes:html '{"error":"missing or invalid x-api-key"}'))
    ::  non-POST: return 200 empty (GET SSE not supported)
    ?.  =(%'POST' method.request.req)
      :_  this
      (give-http eyre-id 200 ~[cors] ~)
    =/  body=@t
      ?~  body.request.req  ''
      `@t`q.u.body.request.req
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      :_  this
      (give-http eyre-id 400 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad json"}')))
    =/  method=@t  (get-json-string u.jon 'method')
    =/  req-id=json  (get-json-field u.jon 'id')
    ::
    ?+  method
      :_  this
      (give-http eyre-id 400 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"unknown method"}')))
    ::
        %'initialize'
      :_  this
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']
            ['id' req-id]
            :-  'result'
            %-  pairs:enjs:format
            :~  :-  'capabilities'
                %-  pairs:enjs:format
                :~  ['tools' (pairs:enjs:format ~[['listChanged' b+|]])]
                    ['resources' (pairs:enjs:format ~[['listChanged' b+|] ['subscribe' b+|]])]
                    ['prompts' (pairs:enjs:format ~[['listChanged' b+|]])]
                ==
                :-  'serverInfo'
                %-  pairs:enjs:format
                :~  ['name' s+(crip "{(trip (scot %p our.bowl))} mcp-proxy")]
                    ['version' s+'1.0.0']
                ==
                ['protocolVersion' s+'2024-11-05']
            ==
        ==
      (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
    ::
        %'notifications/initialized'
      :_  this
      (give-http eyre-id 200 ~[cors] ~)
    ::
        ?(%'tools/list' %'resources/list' %'prompts/list')
      ::  code-mode: return meta-tools for tools/list and empty
      ::  arrays for the other two. without this short-circuit the
      ::  initial handshake fans prompts/list and resources/list out
      ::  to every upstream and blocks until they all respond, which
      ::  is what makes /apps/mcp/mcp appear stuck on connect.
      =/  result-key=@t
        ?:  =(%'tools/list' method)      'tools'
        ?:  =(%'resources/list' method)  'resources'
        'prompts'
      =/  items=(list json)
        ?:  =(%'tools/list' method)  meta-tools
        ~
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']  ['id' req-id]
            :-  'result'
            (pairs:enjs:format ~[[result-key a+items]])
        ==
      :_  this
      (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
    ::
        ?(%'tools/call' %'resources/read' %'prompts/get')
      ::  code-mode: intercept the meta-tool calls before normal routing
      ?:  =(%'tools/call' method)
        =/  params=json  (get-json-field u.jon 'params')
        =/  tool-name-called=@t  (get-json-string params 'name')
        ?:  =('list_upstreams' tool-name-called)
          (handle-meta-list-upstreams eyre-id req-id)
        ?:  =('mcp_list_upstreams' tool-name-called)
          (handle-meta-list-upstreams eyre-id req-id)
        ?:  =('search' tool-name-called)
          (handle-meta-search eyre-id req-id params)
        ?:  =('mcp_search' tool-name-called)
          (handle-meta-search eyre-id req-id params)
        ?:  =('describe' tool-name-called)
          (handle-meta-describe eyre-id req-id params)
        ?:  =('mcp_describe' tool-name-called)
          (handle-meta-describe eyre-id req-id params)
        ?:  =('call' tool-name-called)
          (handle-meta-call eyre-id req u.jon params)
        ?:  =('mcp_call' tool-name-called)
          (handle-meta-call eyre-id req u.jon params)
        ::  unknown meta-name; fall through to normal routing
        (route-call eyre-id req u.jon method)
      (route-call eyre-id req u.jon method)
    ==
  ::
  ::  fan out a list request to all enabled servers
  ::
  ++  fan-out
    |=  [eyre-id=@ta req-id=json method=@t]
    ^-  (quip card _this)
    =/  result-key=@t
      ?+  method  'items'
        %'tools/list'      'tools'
        %'resources/list'  'resources'
        %'prompts/list'    'prompts'
      ==
    =/  enabled=(list [server-id:mcp-proxy mcp-server:mcp-proxy])
      %+  skim
        %+  turn  server-order
        |=(sid=server-id:mcp-proxy [sid (~(got by servers) sid)])
      |=([* srv=mcp-server:mcp-proxy] enabled.srv)
    ?~  enabled
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']  ['id' req-id]
            ['result' (pairs:enjs:format ~[[result-key a+~]])]
        ==
      :_  this
      (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
    ::  separate proxy servers (need Iris) from openapi servers (local)
    =/  all=(list [server-id:mcp-proxy mcp-server:mcp-proxy])
      (turn enabled |=([sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy] [sid srv]))
    =/  proxy-servers=(list [server-id:mcp-proxy mcp-server:mcp-proxy])
      (skim all |=([sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy] =(%proxy mode.srv)))
    =/  openapi-servers=(list [server-id:mcp-proxy mcp-server:mcp-proxy])
      (skim all |=([sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy] =(%openapi mode.srv)))
    ::  generate openapi results locally from cached specs
    =/  local-results=(map server-id:mcp-proxy (unit json))
      %-  ~(gas by *(map server-id:mcp-proxy (unit json)))
      %+  turn  openapi-servers
      |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
      =/  spec=(unit json)  (~(get by spec-cache) sid)
      ?~  spec  [sid ~]
      ?.  =(%'tools/list' method)
        ::  openapi only supports tools for now
        [sid `(pairs:enjs:format ~[['jsonrpc' s+'2.0'] ['id' (numb:enjs:format 1)] ['result' (pairs:enjs:format ~[[result-key a+~]])]])]
      =/  tools=(list json)  (apply-tool-filter sid (spec-to-tools sid u.spec) tool-filters)
      [sid `(pairs:enjs:format ~[['jsonrpc' s+'2.0'] ['id' (numb:enjs:format 1)] ['result' (pairs:enjs:format ~[['tools' a+tools]])]])]
    =/  total=@ud  (lent enabled)
    ::  if no proxy servers, respond immediately with local results
    ?.  ?=(^ proxy-servers)
      =.  agg-pending
        (~(put by agg-pending) 'immediate' [eyre-id req-id method total local-results])
      ::  trigger immediate aggregation via the on-arvo path - but we have all results
      ::  just combine and respond directly
      =/  name-key=@t
        ?+  method  'name'
          %'tools/list'  'name'  %'resources/list'  'uri'  %'prompts/list'  'name'
        ==
      =/  all-items=(list json)
        %-  zing
        %+  turn  ~(tap by local-results)
        |=  [s-id=server-id:mcp-proxy res=(unit json)]
        ?~  res  ~
        =/  result=json  (get-json-field u.res 'result')
        ?.  ?=(%o -.result)  ~
        =/  items-json=(unit json)  (~(get by p.result) result-key)
        ?~  items-json  ~
        ?.  ?=(%a -.u.items-json)  ~
        %+  turn  p.u.items-json
        |=  item=json
        ?.  ?=(%o -.item)  item
        =/  orig-name=@t
          =/  n=(unit json)  (~(get by p.item) name-key)
          ?~  n  ''  ?.  ?=(%s -.u.n)  ''  p.u.n
        [%o (~(put by p.item) name-key s+(cat 3 (cat 3 (scot %tas s-id) '_') orig-name))]
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']  ['id' req-id]
            ['result' (pairs:enjs:format ~[[result-key a+all-items]])]
        ==
      :_  this
      (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
    ::  has proxy servers: set up agg-pending with local results pre-populated
    =/  group-id=@t  (scot %uv `@uv`eny.bowl)
    =.  agg-pending
      (~(put by agg-pending) group-id [eyre-id req-id method total local-results])
    =/  upstream-body=@t
      %-  en:json:html
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']  ['method' s+method]
          ['id' (numb:enjs:format 1)]  ['params' (pairs:enjs:format ~)]
      ==
    :_  this
    %+  turn  proxy-servers
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        ::  MCP Streamable HTTP spec: clients must accept both
        ::  application/json and text/event-stream; some servers
        ::  (linear) 406 if we don't. also include MCP protocol
        ::  version so the server knows what we speak.
        :~  ['content-type' 'application/json']
            ['accept' 'application/json, text/event-stream']
            ['mcp-protocol-version' '2025-03-26']
            ['user-agent' 'urbit-mcp']
        ==
      headers.srv
    =/  cookie=(unit @t)  (~(get by cookies) sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    =/  session=(unit @t)  (~(get by mcp-sessions) sid)
    =?  out-headers  ?=(^ session)
      (snoc out-headers ['mcp-session-id' u.session])
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.srv our.bowl now.bowl)
    =?  out-headers  ?=(^ oauth-hdr)
      (snoc out-headers u.oauth-hdr)
    :*  %pass  /iris/agg/[group-id]/[sid]
        %arvo  %i  %request
        [%'POST' url.srv out-headers `(as-octs:mimes:html upstream-body)]
        *outbound-config:iris
    ==
  ::
  ::  route a call/read/get to a specific server based on name prefix
  ::
  ++  route-call
    |=  [eyre-id=@ta req=inbound-request:eyre jon=json method=@t]
    ^-  (quip card _this)
    =/  params=json  (get-json-field jon 'params')
    =/  req-id=json  (get-json-field jon 'id')
    =/  name-key=@t
      ?+  method  'name'
        %'tools/call'  'name'  %'resources/read'  'uri'  %'prompts/get'  'name'
      ==
    =/  full-name=@t  (get-json-string params name-key)
    =/  [sid=@t real-name=@t]  (split-on-underscore full-name)
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) `@tas`sid)
    ?~  srv
      :_  this
      %-  give-http  :^  eyre-id  404
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"server not found in tool prefix"}'))
    ::  build auth headers. user-agent is required by some APIs
    ::  (notably GitHub) and harmless elsewhere.
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        :~  ['accept' 'application/json']
            ['user-agent' 'urbit-mcp']
        ==
      headers.u.srv
    =/  cookie=(unit @t)  (~(get by cookies) `@tas`sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.u.srv our.bowl now.bowl)
    =?  out-headers  ?=(^ oauth-hdr)
      (snoc out-headers u.oauth-hdr)
    ::  openapi mode: make direct REST API call
    ?:  =(%openapi mode.u.srv)
      =/  spec=(unit json)  (~(get by spec-cache) `@tas`sid)
      ?~  spec
        ~&  >>>  [%mcp-proxy %spec-not-cached sid]
        :_  this
        %-  give-http  :^  eyre-id  500
        ~[cors ['content-type' 'application/json']]
        (some (as-octs:mimes:html '{"error":"spec not cached, try again"}'))
      =/  op=(unit [path=@t method=@t operation=json])
        (find-operation u.spec real-name)
      ?~  op
        ~&  >>>  [%mcp-proxy %op-not-found sid real-name]
        :_  this
        %-  give-http  :^  eyre-id  404
        ~[cors ['content-type' 'application/json']]
        (some (as-octs:mimes:html '{"error":"operation not found in spec"}'))
      ::  extract arguments from params
      =/  args=json
        =/  a=(unit json)  ?.(?=(%o -.params) ~ (~(get by p.params) 'arguments'))
        (fall a params)
      ::  build API URL with path params and query string
      =/  path-params=(set @t)  (extract-path-params path.u.op)
      =/  base-url=@t
        =/  spec-base=@t  (get-spec-base-url u.spec)
        =/  override=@t   url.u.srv
        ::  if the spec only declares a relative path (Swagger 2.0
        ::  basePath without a host), append it to the operator's
        ::  upstream URL. Otherwise prefer the operator override; fall
        ::  back to the spec's full URL.
        ::
        =/  spec-base-t=tape  (trip spec-base)
        =/  spec-is-relative=?
          ?~  spec-base-t  %.n
          =('/' i.spec-base-t)
        ?:  ?&(!=('' override) spec-is-relative)
          =/  override-t=tape  (trip override)
          =?  override-t  &(!=(~ override-t) =('/' (rear override-t)))
            (snip override-t)
          (cat 3 (crip override-t) spec-base)
        ?:  !=('' override)  override
        spec-base
      ::  no base URL means we'd issue a relative-URL request to iris
      ::  and crash the agent. Return a structured error instead so
      ::  the LLM gets an actionable message.
      ::
      ?:  =('' base-url)
        ~&  >>>  [%mcp-proxy %no-base-url sid]
        :_  this
        %-  give-http  :^  eyre-id  400
        ~[cors ['content-type' 'application/json']]
        :-  ~
        %-  as-octs:mimes:html
        %+  rap  3
        :~  '{"error":"upstream base URL not configured for '
            (scot %tas sid)
            '. Set the upstream URL in mcp-proxy or include servers[0].url in the OpenAPI spec."}'
        ==
      =/  api-url=@t
        =/  base-with-path=@t  (build-api-url base-url path.u.op args)
        =/  excluded=(set @t)  (~(put in path-params) 'body')
        =/  qs=@t  (build-all-args-query args excluded)
        (cat 3 base-with-path qs)
      ::  build body for POST/PUT/PATCH
      =/  req-method=method:http
        ?+  method.u.op  %'GET'
          %'get'  %'GET'  %'post'  %'POST'  %'put'  %'PUT'
          %'patch'  %'PATCH'  %'delete'  %'DELETE'
        ==
      =/  has-body=?
        ?|  =(req-method %'POST')
            =(req-method %'PUT')
            =(req-method %'PATCH')
        ==
      =/  body=(unit octs)
        ?.  has-body  ~
        `(as-octs:mimes:html (en:json:html (get-request-body-json args)))
      =?  out-headers  has-body
        [['content-type' 'application/json'] out-headers]
      ::  store eyre-id and use behn to respond from on-arvo
      =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
      =/  client-rpc-id=json  (get-json-field jon 'id')
      =.  pending  (~(put by pending) wire-id eyre-id)
      =.  wrap-set  (~(put by wrap-set) wire-id client-rpc-id)
      =/  =request:http  [req-method api-url out-headers body]
      =?  retry-context  ?=(^ oauth-provider.u.srv)
        (~(put by retry-context) wire-id [u.oauth-provider.u.srv request])
      :_  this
      :~  [%pass /iris/proxy/[wire-id] %arvo %i %request request *outbound-config:iris]
      ==
    ::  proxy mode: forward as MCP request
    =/  new-params=json
      ?>  ?=(%o -.params)
      [%o (~(put by p.params) name-key s+real-name)]
    =/  new-body=@t
      %-  en:json:html
      ?>  ?=(%o -.jon)
      [%o (~(put by p.jon) 'params' new-params)]
    ::  rebuild headers with MCP Streamable HTTP requirements (the
    ::  shared block up top uses Accept: application/json which is
    ::  right for openapi, but MCP spec demands both json + sse)
    =/  mcp-headers=(list [key=@t value=@t])
      %+  weld
        :~  ['content-type' 'application/json']
            ['accept' 'application/json, text/event-stream']
            ['mcp-protocol-version' '2025-03-26']
            ['user-agent' 'urbit-mcp']
        ==
      headers.u.srv
    =/  session=(unit @t)  (~(get by mcp-sessions) `@tas`sid)
    =?  mcp-headers  ?=(^ session)
      (snoc mcp-headers ['mcp-session-id' u.session])
    =?  mcp-headers  ?=(^ oauth-hdr)
      (snoc mcp-headers u.oauth-hdr)
    =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
    =.  pending  (~(put by pending) wire-id eyre-id)
    =.  wire-server  (~(put by wire-server) wire-id `@tas`sid)
    =/  proxy-req=request:http
      [%'POST' url.u.srv mcp-headers `(as-octs:mimes:html new-body)]
    =?  retry-context  ?=(^ oauth-provider.u.srv)
      (~(put by retry-context) wire-id [u.oauth-provider.u.srv proxy-req])
    :_  this
    :~  [%pass /iris/proxy/[wire-id] %arvo %i %request proxy-req *outbound-config:iris]
    ==
  ::
  ::  single-server direct proxy (existing behavior)
  ::
  ++  handle-mcp
    |=  [eyre-id=@ta req=inbound-request:eyre site=(list @t)]
    ^-  (quip card _this)
    ?:  =(%'OPTIONS' method.request.req)
      :_  this
      %-  give-http  :^  eyre-id  204
      :~  cors
          ['access-control-allow-methods' 'GET, POST, DELETE, OPTIONS']
          ['access-control-allow-headers' 'Content-Type, Accept, Authorization, Mcp-Session-Id, X-Api-Key']
          ['access-control-expose-headers' 'Mcp-Session-Id']
          ['access-control-max-age' '86400']
      ==
      ~
    ::  require client-key
    ?~  client-key
      :_  this
      %-  give-http  :^  eyre-id  503
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"proxy not configured: set an x-api-key via the GUI"}'))
    ?.  (check-client-key req)
      :_  this
      %-  give-http  :^  eyre-id  401
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"missing or invalid x-api-key"}'))
    ?~  site
      :_  this
      %-  give-http  :^  eyre-id  400
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"missing server id"}'))
    =/  sid=server-id:mcp-proxy  i.site
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
    ?~  srv
      :_  this
      %-  give-http  :^  eyre-id  404
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"server not found"}'))
    ?.  enabled.u.srv
      :_  this
      %-  give-http  :^  eyre-id  503
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"server disabled"}'))
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        ~[['content-type' 'application/json'] ['accept' 'application/json, text/event-stream']]
      headers.u.srv
    =/  cookie=(unit @t)  (~(get by cookies) sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.u.srv our.bowl now.bowl)
    =?  out-headers  ?=(^ oauth-hdr)
      (snoc out-headers u.oauth-hdr)
    =/  session-id=(unit @t)
      =/  hdrs=(list [key=@t value=@t])  header-list.request.req
      |-
      ?~  hdrs  ~
      ?:  =(key.i.hdrs 'mcp-session-id')  `value.i.hdrs
      $(hdrs t.hdrs)
    =?  out-headers  ?=(^ session-id)
      (snoc out-headers ['mcp-session-id' u.session-id])
    =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
    =.  pending  (~(put by pending) wire-id eyre-id)
    :_  this
    :~  :*  %pass  /iris/proxy/[wire-id]
            %arvo  %i  %request
            [method.request.req url.u.srv out-headers body.request.req]
            *outbound-config:iris
        ==
    ==
  ::
  ++  build-servers-json
    |=  ~
    ^-  json
    =,  enjs:format
    %-  pairs
    :~  ['ship' s+(scot %p our.bowl)]
        :-  'servers'
        :-  %a
        %+  turn  server-order
        |=  sid=server-id:mcp-proxy
        =/  srv=mcp-server:mcp-proxy  (~(got by servers) sid)
        =/  has-cookie=?  (~(has by cookies) sid)
        %-  pairs
        :~  ['id' s+(scot %tas sid)]
            ['name' s+name.srv]
            ['url' s+url.srv]
            ['enabled' b+enabled.srv]
            ['authenticated' b+has-cookie]
            ['mode' s+?:(?=(%proxy mode.srv) 'proxy' 'openapi')]
            :-  'schemaUrl'
            ?~  schema-url.srv  ~
            s+u.schema-url.srv
            :-  'oauthProvider'
            ?~  oauth-provider.srv  ~
            s+(scot %tas u.oauth-provider.srv)
            ['hasCachedSpec' b+(~(has by spec-cache) sid)]
            :-  'toolFilter'
            =/  filt=(unit tool-filter:mcp-proxy)  (~(get by tool-filters) sid)
            ?~  filt  ~
            %-  pairs:enjs:format
            :~  ['mode' s+?:(?=(%allow mode.u.filt) 'allow' 'block')]
                ['tools' a+(turn ~(tap in tools.u.filt) |=(t=@t s+t))]
            ==
            :-  'headers'
            :-  %a
            %+  turn  headers.srv
            |=  h=header:mcp-proxy
            (pairs ~[['key' s+key.h] ['value' s+value.h]])
        ==
    ==
  ::
  ::  gather every available tool across every enabled upstream,
  ::  honoring per-server tool filters. each entry is a fully
  ::  prefixed tool json (i.e. name has the server-id prefix).
  ::
  ::  openapi/discovery upstreams synthesize from cached specs.
  ::  proxy upstreams come from proxy-tools-cache, populated as a
  ::  side effect of fan-out. if a proxy server hasn't been fanned
  ::  yet, its tools are simply absent from the catalog.
  ::
  ++  gather-all-tools
    ^-  (list [server-id:mcp-proxy (list json)])
    %+  murn
      %+  turn  server-order
      |=(sid=server-id:mcp-proxy [sid (~(got by servers) sid)])
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    ^-  (unit [server-id:mcp-proxy (list json)])
    ?.  enabled.srv  ~
    ?:  =(%openapi mode.srv)
      =/  spec=(unit json)  (~(get by spec-cache) sid)
      ?~  spec  ~
      =/  raw=(list json)  (spec-to-tools sid u.spec)
      =/  filtered=(list json)  (apply-tool-filter sid raw tool-filters)
      =/  prefixed=(list json)  (prefix-tool-names sid filtered)
      `[sid prefixed]
    ::  proxy mode: pull from cache if present
    =/  cached=(unit (list json))  (~(get by proxy-tools-cache) sid)
    ?~  cached  ~
    =/  filtered=(list json)  (apply-tool-filter sid u.cached tool-filters)
    =/  prefixed=(list json)  (prefix-tool-names sid filtered)
    `[sid prefixed]
  ::
  ::  prefix tool names with their server-id (e.g. "create_issue"
  ::  becomes "linear_create_issue") so they round-trip through
  ::  split-on-underscore in route-call. always unconditional: the
  ::  cache holds raw upstream names, so a tool whose native name
  ::  already begins with the sid (e.g. ref's "ref_search_documentation")
  ::  must still be prefixed — we'd otherwise strip the wrong piece on
  ::  the call path and ask the upstream for a tool it doesn't have.
  ::
  ++  prefix-tool-names
    |=  [sid=server-id:mcp-proxy tools=(list json)]
    ^-  (list json)
    %+  turn  tools
    |=  tool=json
    ^-  json
    ?.  ?=(%o -.tool)  tool
    =/  name=@t  (tool-name tool)
    ?:  =('' name)  tool
    =/  prefixed-name=@t
      (rap 3 ~[(scot %tas sid) '_' name])
    [%o (~(put by p.tool) 'name' s+prefixed-name)]
  ::
  ::  filter the catalog by query/server/limit, returning a slimmed
  ::  result set the LLM can use to pick something to call.
  ::
  ++  search-meta
    |=  [query=@t server-filter=@t limit=@ud]
    ^-  json
    =/  parsed  (parse-search-query query)
    =/  effective-server=@t
      ?:  =('' server.parsed)  server-filter
      server.parsed
    =/  keywords=@t  keywords.parsed
    =/  catalog=(list [server-id:mcp-proxy (list json)])  gather-all-tools
    ::  flatten + filter
    =/  matched=(list [@t @t @t])
      ::  list of [tool-name server-id description]
      %-  zing
      %+  turn  catalog
      |=  [sid=server-id:mcp-proxy tools=(list json)]
      ?:  ?&  !=('' effective-server)
              !=((scot %tas sid) effective-server)
          ==
        ~
      %+  murn  tools
      |=  tool=json
      ^-  (unit [@t @t @t])
      =/  nm=@t  (tool-name tool)
      =/  desc=@t  (tool-description tool)
      ?:  =('' nm)  ~
      ?:  &(!=('' keywords) !(contains-ci nm keywords) !(contains-ci desc keywords))
        ~
      `[nm (scot %tas sid) desc]
    =/  total=@ud  (lent matched)
    =/  capped=(list [@t @t @t])  (scag (min limit total) matched)
    =/  result-arr=(list json)
      %+  turn  capped
      |=  [nm=@t srv=@t desc=@t]
      ::  truncate description to 200 chars to keep results compact
      =/  short-desc=@t
        ?:  (lte (met 3 desc) 200)  desc
        (rap 3 ~[(crip (scag 200 (trip desc))) '...'])
      %-  pairs:enjs:format
      :~  ['name' s+nm]
          ['server' s+srv]
          ['description' s+short-desc]
      ==
    %-  pairs:enjs:format
    :~  ['total' (numb:enjs:format total)]
        ['returned' (numb:enjs:format (lent capped))]
        ['tools' a+result-arr]
    ==
  ::
  ::  return the full schema (description + inputSchema) for one tool
  ::
  ++  describe-meta
    |=  full-name=@t
    ^-  (unit json)
    =/  catalog=(list [server-id:mcp-proxy (list json)])  gather-all-tools
    |-
    ?~  catalog  ~
    =/  found=(unit json)
      =/  tools=(list json)  +.i.catalog
      |-
      ?~  tools  ~
      ?:  =(full-name (tool-name i.tools))  `i.tools
      $(tools t.tools)
    ?^  found  found
    $(catalog t.catalog)
  ::
  ::  meta tool: list_upstreams: return id/name/url for every
  ::  configured upstream so the agent can pick which one to search.
  ::
  ++  handle-meta-list-upstreams
    |=  [eyre-id=@ta req-id=json]
    ^-  (quip card _this)
    =/  list-arr=(list json)
      %+  turn  server-order
      |=  sid=server-id:mcp-proxy
      =/  srv=mcp-server:mcp-proxy  (~(got by servers) sid)
      %-  pairs:enjs:format
      :~  ['id' s+(scot %tas sid)]
          ['name' s+name.srv]
          ['url' s+url.srv]
          ['enabled' b+enabled.srv]
      ==
    =/  text=@t
      (en:json:html (pairs:enjs:format ~[['upstreams' a+list-arr]]))
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']  ['id' req-id]
          :-  'result'
          %-  pairs:enjs:format
          :~  :-  'content'
              :-  %a
              :~  (pairs:enjs:format ~[['type' s+'text'] ['text' s+text]])
              ==
              ['isError' b+%.n]
          ==
      ==
    :_  this
    (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
  ::
  ::  meta tool: search: run search-meta and wrap as MCP result
  ::
  ++  handle-meta-search
    |=  [eyre-id=@ta req-id=json params=json]
    ^-  (quip card _this)
    =/  args=json
      ?.  ?=(%o -.params)  ~
      (fall (~(get by p.params) 'arguments') ~)
    =/  query=@t  (get-json-string args 'query')
    =/  server-arg=@t  (get-json-string args 'server')
    =/  limit=@ud
      =/  l=@t  (get-json-string args 'limit')
      ?:  =('' l)  25
      =/  res  (mule |.((slav %ud l)))
      ?:(?=(%& -.res) (min p.res 200) 25)
    =/  search-result=json  (search-meta query server-arg limit)
    =/  text=@t  (en:json:html search-result)
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']  ['id' req-id]
          :-  'result'
          %-  pairs:enjs:format
          :~  :-  'content'
              :-  %a
              :~  (pairs:enjs:format ~[['type' s+'text'] ['text' s+text]])
              ==
              ['isError' b+%.n]
          ==
      ==
    :_  this
    (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
  ::
  ::  meta tool: describe: return one tool's full schema
  ::
  ++  handle-meta-describe
    |=  [eyre-id=@ta req-id=json params=json]
    ^-  (quip card _this)
    =/  args=json
      ?.  ?=(%o -.params)  ~
      (fall (~(get by p.params) 'arguments') ~)
    =/  full-name=@t  (get-json-string args 'name')
    =/  found=(unit json)  (describe-meta full-name)
    =/  text=@t
      ?~  found  (rap 3 ~['{"error":"tool not found: ' full-name '"}'])
      (en:json:html u.found)
    =/  is-error=?  ?=(~ found)
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']  ['id' req-id]
          :-  'result'
          %-  pairs:enjs:format
          :~  :-  'content'
              :-  %a
              :~  (pairs:enjs:format ~[['type' s+'text'] ['text' s+text]])
              ==
              ['isError' b+is-error]
          ==
      ==
    :_  this
    (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
  ::
  ::  meta tool: call: look up the underlying tool and route it
  ::  through the existing route-call by rewriting the params with
  ::  the inner name + arguments. this preserves all the existing
  ::  per-server auth, openapi, proxy, oauth header, response wrap
  ::  machinery without duplicating any of it.
  ::
  ++  handle-meta-call
    |=  [eyre-id=@ta req=inbound-request:eyre jon=json params=json]
    ^-  (quip card _this)
    =/  args=json
      ?.  ?=(%o -.params)  ~
      (fall (~(get by p.params) 'arguments') ~)
    =/  inner-name=@t  (get-json-string args 'name')
    =/  inner-args=json
      ?.  ?=(%o -.args)  [%o ~]
      (fall (~(get by p.args) 'arguments') [%o ~])
    ?:  =('' inner-name)
      :_  this
      %-  give-http  :^  eyre-id  400
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"call: missing name"}'))
    ::  rewrite the params object so it looks like a direct
    ::  tools/call invocation: {name: <inner>, arguments: <inner>}
    =/  rewritten-params=json
      %-  pairs:enjs:format
      :~  ['name' s+inner-name]
          ['arguments' inner-args]
      ==
    =/  rewritten-jon=json
      ?>  ?=(%o -.jon)
      [%o (~(put by p.jon) 'params' rewritten-params)]
    (route-call eyre-id req rewritten-jon %'tools/call')
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%http-response @ ~]
    `this
  ==
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
      [%eyre *]
    ?:  ?=(%bound +<.sign)
      ~?  !accepted.sign  [%mcp-proxy %binding-rejected binding.sign]
      `this
    `this
  ::
  ::  retry-timeout: a 401 was deferred ~30s ago and no refresh
  ::  fact arrived. Finish the deferred response with a 401 so the
  ::  client doesn't hang.
  ::
      [%retry-timeout @ ~]
    =/  wire-id=@t  i.t.wire
    ?.  ?=([%behn %wake *] sign)  `this
    =/  ctx=(unit [pid=@tas request=request:http])
      (~(get by retry-context) wire-id)
    ?~  ctx  `this
    =/  eid=(unit @ta)  (~(get by pending) wire-id)
    ?~  eid
      =.  retry-context  (~(del by retry-context) wire-id)
      `this
    ~&  >>  [%mcp-proxy %retry-timeout wire-id pid.u.ctx]
    =.  retry-context  (~(del by retry-context) wire-id)
    =.  pending  (~(del by pending) wire-id)
    =.  wrap-set  (~(del by wrap-set) wire-id)
    =/  body=(unit octs)
      `(as-octs:mimes:html '{"error":"upstream returned 401 and refresh did not complete in time"}')
    =/  =path  /http-response/[u.eid]
    :_  this
    :~  [%give %fact ~[path] %http-response-header !>(`response-header:http`[401 ~[cors ['content-type' 'application/json']]])]
        [%give %fact ~[path] %http-response-data !>(body)]
        [%give %kick ~[path] ~]
    ==
  ::
  ::  prime-oauth: deferred post-load prime for one oauth-linked
  ::  proxy upstream, with the bearer token attached (safe to scry
  ::  %oauth now that the desk is fully live). fire-and-forget like
  ::  the boot prime; the response lands on /iris/init as usual.
  ::
      [%prime-oauth @ ~]
    ?.  ?=([%behn %wake *] sign)  `this
    =/  sid=server-id:mcp-proxy  `@tas`i.t.wire
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
    ?~  srv  `this
    =/  c=(unit card)
      %-  prime-one-proxy-card
      [sid u.srv (~(get by cookies) sid) our.bowl now.bowl]
    ?~  c  `this
    :_  this  ~[u.c]
  ::
      [%iris %init @ ~]
    ::  MCP initialize response. Capture the assigned Mcp-Session-Id
    ::  (if any), fire-and-forget the notifications/initialized post,
    ::  then schedule the actual tools/list which lands on the
    ::  /iris/prime/<sid> handler below.
    ::
    =/  sid=server-id:mcp-proxy  i.t.t.wire
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
    ?~  srv  `this
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%mcp-proxy %init-failed sid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%mcp-proxy %init-failed sid %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ~&  >>>  [%mcp-proxy %init-failed sid %status status-code.response-header.resp]
      `this
    ::  pull Mcp-Session-Id from the response headers. If absent, the
    ::  server doesn't enforce sessions; we still proceed without one.
    ::
    =/  session=(unit @t)
      (extract-session-id headers.response-header.resp)
    =?  mcp-sessions  ?=(^ session)
      (~(put by mcp-sessions) sid u.session)
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.u.srv our.bowl now.bowl)
    =/  cookie=(unit @t)  (~(get by cookies) sid)
    =/  initialized-card=card:agent:gall
      %+  build-mcp-iris-card  /iris/initialized/[sid]
      :*  url.u.srv  headers.u.srv  cookie  session  oauth-hdr
          build-initialized-body
      ==
    =/  prime-card=card:agent:gall
      %+  build-mcp-iris-card  /iris/prime/[sid]
      :*  url.u.srv  headers.u.srv  cookie  session  oauth-hdr
          build-tools-list-body
      ==
    :_  this
    ~[initialized-card prime-card]
  ::
  ::  notifications/initialized response — discard. The server may
  ::  reply 202 Accepted or 200 with empty body; either way nothing
  ::  to do.
  ::
      [%iris %initialized @ ~]
    `this
  ::
      [%iris %prime @ ~]
    ::  proxy upstream tools/list prime response — mirrors the
    ::  spec-fetch path but stores into proxy-tools-cache instead
    ::  of spec-cache. fire-and-forget; no client is waiting on
    ::  this so failures just leave the cache empty until the
    ::  next fan-out repopulates it.
    ::
    =/  sid=server-id:mcp-proxy  i.t.t.wire
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%mcp-proxy %prime-failed sid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%mcp-proxy %prime-failed sid %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ~&  >>>  [%mcp-proxy %prime-failed sid %status status-code.response-header.resp]
      `this
    ?~  full-file.resp
      ~&  >>>  [%mcp-proxy %prime-failed sid %no-body]
      `this
    =/  body=@t  `@t`q.data.u.full-file.resp
    =/  clean=@t  (strip-sse body)
    =/  jon=(unit json)  (de:json:html clean)
    ?~  jon
      ~&  >>>  [%mcp-proxy %prime-failed sid %bad-json]
      `this
    =/  result=json  (get-json-field u.jon 'result')
    ?~  result
      ~&  >>>  [%mcp-proxy %prime-failed sid %no-result]
      `this
    =/  tl=json  (get-json-field result 'tools')
    ?~  tl  `this
    ?.  ?=(%a -.tl)  `this
    ::  capture rotated Mcp-Session-Id from the tools/list response —
    ::  some servers (Supabase, Ref) issue a new session id on each
    ::  response and reject subsequent requests carrying the stale one.
    ::
    =/  rotated=(unit @t)
      (extract-session-id headers.response-header.resp)
    =?  mcp-sessions  ?=(^ rotated)
      (~(put by mcp-sessions) sid u.rotated)
    `this(proxy-tools-cache (~(put by proxy-tools-cache) sid p.tl))
  ::
      [%iris %spec @ ~]
    ::  OpenAPI spec fetch response
    ::
    =/  sid=server-id:mcp-proxy  i.t.t.wire
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%mcp-proxy %spec-fetch-failed sid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%mcp-proxy %spec-fetch-failed sid %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ~&  >>>  [%mcp-proxy %spec-fetch-failed sid %status status-code.response-header.resp]
      `this
    ?~  full-file.resp
      ~&  >>>  [%mcp-proxy %spec-fetch-failed sid %no-body]
      `this
    =/  body=@t  `@t`q.data.u.full-file.resp
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      ~&  >>>  [%mcp-proxy %spec-fetch-failed sid %bad-json]
      `this
    `this(spec-cache (~(put by spec-cache) sid u.jon))
  ::
      [%iris %toolsapi @ @ ~]
    ::  tools API response: parse MCP response and extract tools list
    =/  sid=server-id:mcp-proxy  i.t.t.wire
    =/  wire-id=@t  i.t.t.t.wire
    =/  eid=(unit @ta)  (~(get by pending) wire-id)
    ?~  eid  `this
    =.  pending  (~(del by pending) wire-id)
    ?.  ?=([%iris %http-response *] sign)
      :_  this
      (give-http u.eid 502 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html '{"tools":[]}')))
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      :_  this
      (give-http u.eid 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html '{"tools":[]}')))
    =/  body=@t
      ?~  full-file.resp  ''
      `@t`q.data.u.full-file.resp
    ::  strip SSE prefix if present
    =/  clean=@t  (strip-sse body)
    =/  jon=(unit json)  (de:json:html clean)
    =/  tools=(list json)
      ?~  jon  ~
      ::  MCP response: {"result":{"tools":[...]}}
      ::  MCP error:    {"error":{"code":..., "message":...}}
      =/  result=json  (get-json-field u.jon 'result')
      ?~  result
        =/  err=json  (get-json-field u.jon 'error')
        ?~  err  ~
        ~&  >>>  [%mcp-proxy %toolsapi-error wire-id err]
        ~
      =/  tl=json  (get-json-field result 'tools')
      ?~  tl  ~
      ?.  ?=(%a -.tl)  ~
      p.tl
    ::  cache for code-mode meta tools
    =?  proxy-tools-cache  ?=(^ tools)
      (~(put by proxy-tools-cache) sid tools)
    =/  resp-body=@t  (en:json:html (pairs:enjs:format ~[['tools' a+tools]]))
    :_  this
    (give-http u.eid 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html resp-body)))
  ::
      [%iris %login @ ~]
    =/  sid=server-id:mcp-proxy  i.t.t.wire
    ?.  ?=([%iris %http-response *] sign)
      ~&  >>>  [%mcp-proxy %login-failed sid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  >>>  [%mcp-proxy %login-failed sid %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ~&  >>>  [%mcp-proxy %login-failed sid %status status-code.response-header.resp]
      `this
    =/  cookie=(unit @t)
      =/  hdrs=(list [key=@t value=@t])  headers.response-header.resp
      |-
      ?~  hdrs  ~
      ?:  =(key.i.hdrs 'set-cookie')
        =/  val=tape  (trip value.i.hdrs)
        =/  semi=(unit @ud)  (find ";" val)
        ?~  semi  `value.i.hdrs
        `(crip (scag u.semi val))
      $(hdrs t.hdrs)
    ?~  cookie
      ~&  >>>  [%mcp-proxy %login-failed sid %no-cookie]
      `this
    `this(cookies (~(put by cookies) sid u.cookie))
  ::
  ::
      [%iris %proxy @ ~]
    =/  wire-id=@t  i.t.t.wire
    =/  eid=(unit @ta)  (~(get by pending) wire-id)
    ?~  eid
      ~&  >>  [%mcp-proxy %no-pending wire-id]
      `this
    ::  if iris failed before producing a response, fall through to
    ::  the existing 502 path. Otherwise read status; on 401 with a
    ::  retry-eligible wire we defer the response and trigger
    ::  %force-refresh on %oauth.
    ::
    =/  retry-ctx=(unit [pid=@tas request=request:http])
      (~(get by retry-context) wire-id)
    =/  is-retry=?  (~(has in retried-wires) wire-id)
    =/  status=@ud
      ?.  ?=([%iris %http-response *] sign)  0
      ?.  ?=(%finished -.client-response.sign)  0
      status-code.response-header.client-response.sign
    ?:  ?&  =(401 status)
            ?=(^ retry-ctx)
            !is-retry
        ==
      ::  defer: don't send terminal cards. fire force-refresh +
      ::  giveup timer; the on-agent grants handler will replay or
      ::  fail this stash when the refresh resolves.
      ::
      ~&  >  [%mcp-proxy %defer-401 wire-id pid.u.retry-ctx]
      :_  this
      :~  [%pass /oauth-refresh/[pid.u.retry-ctx] %agent [our.bowl %oauth] %poke %oauth-action !>(`action:oauth`[%force-refresh pid.u.retry-ctx])]
          [%pass /retry-timeout/[wire-id] %arvo %b %wait (add now.bowl ~s30)]
      ==
    ::  not deferring. clean up retry tracking and fall through.
    ::
    =.  retry-context  (~(del by retry-context) wire-id)
    =.  retried-wires  (~(del in retried-wires) wire-id)
    =.  pending  (~(del by pending) wire-id)
    =/  proxy-sid=(unit server-id:mcp-proxy)  (~(get by wire-server) wire-id)
    =.  wire-server  (~(del by wire-server) wire-id)
    =/  client-id=(unit json)  (~(get by wrap-set) wire-id)
    =/  needs-wrap=?  ?=(^ client-id)
    =?  wrap-set  needs-wrap  (~(del by wrap-set) wire-id)
    ?.  ?=([%iris %http-response *] sign)
      :_  this
      %-  give-http  :^  u.eid  502
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"unexpected iris response"}'))
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      :_  this
      %-  give-http  :^  u.eid  502
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"upstream in progress"}'))
    ::  capture rotated Mcp-Session-Id from this proxy-mode response
    ::  before we forward the body to the LLM client. servers that
    ::  rotate per request (Supabase, Ref) reject the next call if we
    ::  keep using the prior session id.
    ::
    =?  mcp-sessions  ?=(^ proxy-sid)
      =/  rotated=(unit @t)
        (extract-session-id headers.response-header.resp)
      ?~  rotated  mcp-sessions
      (~(put by mcp-sessions) u.proxy-sid u.rotated)
    ::  for openapi calls, wrap the REST response in MCP format.
    ::  401-driven token refresh is handled before this point via the
    ::  retry-context / on-agent /grants subscription, so by the time
    ::  we reach here we either (a) succeeded, (b) failed for some
    ::  non-401 reason, or (c) failed twice through 401 → finish.
    ::
    ?:  needs-wrap
      =/  body-text=@t
        ?~  full-file.resp  ''
        `@t`q.data.u.full-file.resp
      =/  is-error=?  (gte status-code.response-header.resp 400)
      =/  mcp-resp=@t
        %-  en:json:html
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']
            ['id' (fall client-id (numb:enjs:format 1))]
            :-  'result'
            %-  pairs:enjs:format
            :~  :-  'content'
                :-  %a
                :~  (pairs:enjs:format ~[['type' s+'text'] ['text' s+body-text]])
                ==
                ['isError' b+is-error]
            ==
        ==
      =/  resp-headers=(list [key=@t value=@t])
        ~[cors ['content-type' 'application/json'] ['cache-control' 'no-cache'] ['access-control-expose-headers' 'Mcp-Session-Id'] ['content-encoding' 'identity']]
      =/  bod=(unit octs)  `(as-octs:mimes:html mcp-resp)
      :_  this
      =/  =path  /http-response/[u.eid]
      :~  [%give %fact ~[path] %http-response-header !>(`response-header:http`[200 resp-headers])]
          [%give %fact ~[path] %http-response-data !>(bod)]
          [%give %kick ~[path] ~]
      ==
    ::  for proxy calls, forward upstream response as-is. drop hop-by-hop
    ::  framing headers, plus content-encoding and content-length:
    ::  iris transparently decompresses gzip/deflate responses, so the
    ::  upstream's content-encoding would tell our client to decode an
    ::  already-decoded body (resulting in empty output) and the upstream
    ::  content-length no longer matches the inflated body. eyre/the
    ::  give-simple-payload path computes the right content-length itself.
    ::
    =/  resp-headers=(list [key=@t value=@t])
      %+  weld  ~[cors ['access-control-expose-headers' 'Mcp-Session-Id']]
      %+  skip  headers.response-header.resp
      |=  [key=@t value=@t]
      ?|  =(key 'transfer-encoding')
          =(key 'connection')
          =(key 'content-encoding')
          =(key 'content-length')
      ==
    =/  bod=(unit octs)
      ?~  full-file.resp  ~
      `data.u.full-file.resp
    :_  this
    =/  =path  /http-response/[u.eid]
    :~  [%give %fact ~[path] %http-response-header !>(`response-header:http`[status-code.response-header.resp resp-headers])]
        [%give %fact ~[path] %http-response-data !>(bod)]
        [%give %kick ~[path] ~]
    ==
  ::
      [%iris %agg @ @ ~]
    ::  aggregate response: /iris/agg/{group-id}/{server-id}
    ::
    =/  group-id=@t  i.t.t.wire
    =/  sid=server-id:mcp-proxy  i.t.t.t.wire
    =/  req=(unit agg-request)  (~(get by agg-pending) group-id)
    ?~  req
      ~&  >>  [%mcp-proxy %agg-no-pending group-id sid]
      `this
    ::  parse the upstream response (handles both plain JSON and SSE format)
    =/  result-json=(unit json)
      ?.  ?=([%iris %http-response *] sign)
        ~&  >>>  [%mcp-proxy %agg-bad-sign sid]
        ~
      =/  resp=client-response:iris  client-response.sign
      ?.  ?=(%finished -.resp)
        ~&  >>>  [%mcp-proxy %agg-not-finished sid]
        ~
      ?.  =(200 status-code.response-header.resp)
        =/  body-preview=@t
          ?~  full-file.resp  'no body'
          =/  b=@t  `@t`q.data.u.full-file.resp
          ?:  (gth (met 3 b) 500)  (cat 3 (cut 3 [0 500] b) '...[truncated]')
          b
        ~&  >>>  [%mcp-proxy %agg-non-200 sid status-code.response-header.resp body-preview]
        ~
      ?~  full-file.resp
        ~&  >>>  [%mcp-proxy %agg-empty-body sid]
        ~
      =/  body=@t  `@t`q.data.u.full-file.resp
      ::  strip SSE "data: " prefix if present
      =/  clean=@t  (strip-sse body)
      (de:json:html clean)
    ::  cache the parsed proxy tools per server so code-mode can
    ::  search them without round-tripping back. only relevant for
    ::  the tools/list method; ignore other list types.
    =?  proxy-tools-cache  &(=(%'tools/list' method.u.req) ?=(^ result-json))
      =/  result=json  (get-json-field u.result-json 'result')
      ?~  result  proxy-tools-cache
      =/  tl=json  (get-json-field result 'tools')
      ?~  tl  proxy-tools-cache
      ?.  ?=(%a -.tl)  proxy-tools-cache
      (~(put by proxy-tools-cache) sid p.tl)
    ::  store result (~ if failed, which is ok)
    =/  new-results=(map server-id:mcp-proxy (unit json))
      (~(put by results.u.req) sid result-json)
    =/  received=@ud  ~(wyt by new-results)
    ::  not all in yet: update and wait
    ?.  =(received total.u.req)
      =.  agg-pending
        (~(put by agg-pending) group-id u.req(results new-results))
      `this
    ::  all responses in: combine and respond
    =.  agg-pending  (~(del by agg-pending) group-id)
    =/  result-key=@t
      ?+  method.u.req  'items'
        %'tools/list'      'tools'
        %'resources/list'  'resources'
        %'prompts/list'    'prompts'
      ==
    =/  name-key=@t
      ?+  method.u.req  'name'
        %'tools/list'      'name'
        %'resources/list'  'uri'
        %'prompts/list'    'name'
      ==
    ::  combine items from all servers, prefixing names
    =/  all-items=(list json)
      %-  zing
      %+  turn  ~(tap by new-results)
      |=  [s-id=server-id:mcp-proxy res=(unit json)]
      ?~  res  ~
      =/  result=json  (get-json-field u.res 'result')
      ?.  ?=(%o -.result)  ~
      =/  items-json=(unit json)  (~(get by p.result) result-key)
      ?~  items-json  ~
      ?.  ?=(%a -.u.items-json)  ~
      ::  prefix each item's name with server-id_
      %+  turn  p.u.items-json
      |=  item=json
      ?.  ?=(%o -.item)  item
      =/  orig-name=@t
        =/  n=(unit json)  (~(get by p.item) name-key)
        ?~  n  ''
        ?.  ?=(%s -.u.n)  ''
        p.u.n
      =/  prefixed=@t  (cat 3 (cat 3 (scot %tas s-id) '_') orig-name)
      [%o (~(put by p.item) name-key s+prefixed)]
    ::  build combined response
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']
          ['id' req-id.u.req]
          ['result' (pairs:enjs:format ~[[result-key a+all-items]])]
      ==
    :_  this
    (give-http eyre-id.u.req 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
  ==
::
++  on-leave  on-leave:def
::
::  on-agent: respond to %oauth-update facts on /oauth/grants. when a
::  grant is added or refreshed, drain retry-context for that provider
::  by reissuing each stashed iris request with the rotated bearer.
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  |^
  ?+    wire  (on-agent:def wire sign)
      [%oauth %grants ~]
    ?+  -.sign  (on-agent:def wire sign)
        %watch-ack
      ?~  p.sign  `this
      ~&  >>>  [%mcp-proxy %oauth-watch-nack u.p.sign]
      `this
    ::
        %kick
      ?:  (~(has by wex.bowl) /oauth/grants [our.bowl %oauth])
        `this
      :_  this
      ~[[%pass /oauth/grants %agent [our.bowl %oauth] %watch /grants]]
    ::
        %fact
      ?.  =(%oauth-update p.cage.sign)  `this
      =/  upd  !<(update:oauth q.cage.sign)
      ?+    -.upd  `this
          %grant-added       (drain-retries-for provider-id.upd)
          %grant-refreshed   (drain-retries-for provider-id.upd)
          %token-expired     (fail-retries-for provider-id.upd)
      ==
    ==
  ==
  ::
  ::  drain-retries-for: replay every stashed iris request whose pid
  ::  matches. Mints a fresh wire-id per retry, swaps the
  ::  authorization header for the new bearer, marks the new wire as
  ::  a retry so a second 401 finishes rather than loops.
  ::
  ++  drain-retries-for
    |=  pid=@tas
    ^-  (quip card _this)
    =/  matches=(list [@t [pid=@tas request=request:http]])
      %+  skim  ~(tap by retry-context)
      |=  [* ctx=[pid=@tas request=request:http]]
      =(pid pid.ctx)
    ?:  =(~ matches)  `this
    =/  fresh-hdr=(unit [key=@t value=@t])
      (get-oauth-header `pid our.bowl now.bowl)
    ?~  fresh-hdr
      (fail-retries-for pid)
    ::  thread (cards, retry-context, retried-wires, pending,
    ::  wrap-set, entropy) through each match. roll's accumulator is
    ::  the only thing that propagates between iterations, so bundle.
    ::
    =/  init=[cards=(list card) ctx=_retry-context retried=_retried-wires pend=_pending wrap=_wrap-set seed=@uv]
      [~ retry-context retried-wires pending wrap-set `@uv`eny.bowl]
    =/  acc=_init
      %+  roll  matches
      |=  $:  [old-wid=@t pair=[pid=@tas request=request:http]]
              a=_init
          ==
      ^-  _init
      =/  new-wid=@t  (scot %uv (mix seed.a (shax (cat 3 (jam old-wid) seed.a))))
      =/  new-headers=(list [key=@t value=@t])
        %+  snoc
          %+  skip  header-list.request.pair
          |=  [k=@t *]
          =((cass (trip k)) "authorization")
        u.fresh-hdr
      =/  new-req=request:http
        [method.request.pair url.request.pair new-headers body.request.pair]
      =/  eid=(unit @ta)  (~(get by pend.a) old-wid)
      ?~  eid  a
      =/  client-id=(unit json)  (~(get by wrap.a) old-wid)
      =/  pend2=_pending  (~(del by (~(put by pend.a) new-wid u.eid)) old-wid)
      =/  wrap2=_wrap-set
        ?~  client-id  wrap.a
        (~(del by (~(put by wrap.a) new-wid u.client-id)) old-wid)
      =/  ctx2=_retry-context  (~(del by ctx.a) old-wid)
      =/  retried2=_retried-wires  (~(put in retried.a) new-wid)
      :*  (snoc cards.a [%pass /iris/proxy/[new-wid] %arvo %i %request new-req *outbound-config:iris])
          ctx2  retried2  pend2  wrap2  +(seed.a)
      ==
    =.  retry-context  ctx.acc
    =.  retried-wires  retried.acc
    =.  pending        pend.acc
    =.  wrap-set       wrap.acc
    [cards.acc this]
  ::
  ::  fail-retries-for: drop stashed retries for pid and finish each
  ::  pending response with a 401 telling the LLM the auth is bad.
  ::
  ++  fail-retries-for
    |=  pid=@tas
    ^-  (quip card _this)
    =/  matches=(list [@t [pid=@tas request=request:http]])
      %+  skim  ~(tap by retry-context)
      |=  [* ctx=[pid=@tas request=request:http]]
      =(pid pid.ctx)
    ?:  =(~ matches)  `this
    =/  init=[cards=(list card) ctx=_retry-context pend=_pending wrap=_wrap-set]
      [~ retry-context pending wrap-set]
    =/  acc=_init
      %+  roll  matches
      |=  [[wid=@t *] a=_init]
      ^-  _init
      =/  eid=(unit @ta)  (~(get by pend.a) wid)
      ?~  eid  a
      =/  body=(unit octs)
        `(as-octs:mimes:html '{"error":"upstream returned 401 and refresh failed"}')
      =/  =path  /http-response/[u.eid]
      =/  new-cards=(list card)
        :~  [%give %fact ~[path] %http-response-header !>(`response-header:http`[401 ~[cors ['content-type' 'application/json']]])]
            [%give %fact ~[path] %http-response-data !>(body)]
            [%give %kick ~[path] ~]
        ==
      :*  (weld cards.a new-cards)
          (~(del by ctx.a) wid)
          (~(del by pend.a) wid)
          (~(del by wrap.a) wid)
      ==
    =.  retry-context  ctx.acc
    =.  pending        pend.acc
    =.  wrap-set       wrap.acc
    [cards.acc this]
  --
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %dbug %state ~]  ``noun+!>(state)
      [%x %client-key ~]
    =/  key=@t  ?~(client-key '' u.client-key)
    ``noun+!>(key)
  ==
::
++  on-fail  on-fail:def
--
::
::  helper core
::
|%
++  cors  ['access-control-allow-origin' '*']
::
::  generate a random token from entropy (base32 encoded sha)
::
++  gen-token
  |=  eny=@
  ^-  @t
  =/  hash=@  (shaz eny)
  ::  drop the ~0v prefix from (scot %uv ...)
  =/  raw=tape  (trip (scot %uv hash))
  (crip (slag 3 raw))
::
::  poke mcp-server with the shared API key so /mcp validates against same value
::  caller passes our.bowl since we're in the helper core
::
++  sync-server-key-card
  |=  [our=@p key=@t]
  ^-  card:agent:gall
  :*  %pass  /sync/auth-token
      %agent  [our %mcp-server]
      %poke   %set-auth-token
      !>(key)
  ==
::
::  derive the self-loopback URL by scrying eyre for the bound port
::
++  build-self-url
  |=  [our=@p now=@da]
  ^-  @t
  =/  res=(unit [insecure=@ud secure=(unit @ud)])
    =/  m  (mule |.(.^([insecure=@ud secure=(unit @ud)] %e /(scot %p our)/ports/(scot %da now))))
    ?:(?=(%& -.m) `p.m ~)
  ?~  res  'http://localhost/mcp'
  =/  port=@ud  insecure.u.res
  (rap 3 ~['http://localhost:' (crip (a-co:co port)) '/mcp'])
::
::  derive the self upstream id from the ship name (no leading tilde)
::
++  self-id
  |=  our=@p
  ^-  @tas
  `@tas`(crip (slag 1 (trip (scot %p our))))
::
++  http-methods  (silt ~['get' 'post' 'put' 'patch' 'delete'])
::
::  the meta-tools exposed when code-mode is enabled. these
::  collapse the entire upstream tool catalog (which can be hundreds
::  of operations across many servers) into a discovery interface
::  the LLM can use without paying token cost for the full list.
::
::  inspired by cloudflare's "code mode" approach but adapted to a
::  no-sandbox environment: the LLM uses keyword search rather than
::  writing JS against the spec.
::
++  meta-tools
  ^-  (list json)
  =/  list-upstreams-tool=json
    %-  pairs:enjs:format
    :~  ['name' s+'list_upstreams']
        :-  'description'
        s+'List all configured upstream servers (id, display name, url, enabled state). Use this first to discover which upstreams exist, then call search with "server:<id>" (or pass the server arg) to enumerate the tools on that upstream, describe to get a tool schema, and call to invoke it.'
        :-  'inputSchema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            ['properties' [%o ~]]
            ['required' a+~]
        ==
    ==
  =/  search-tool=json
    %-  pairs:enjs:format
    :~  ['name' s+'search']
        :-  'description'
        s+'Search across all configured upstream servers for available tools. Returns matching tool names with brief descriptions. Use this to discover what tools exist before calling describe for the full schema of a specific tool, then call to invoke. Query syntax: plain keywords match against tool name and description; "server:<id>" filters to one upstream (e.g. "server:linear", "server:google issue"). Combine: "server:linear create" finds linear creation tools.'
        :-  'inputSchema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            :-  'properties'
            %-  pairs:enjs:format
            :~  :-  'query'
                %-  pairs:enjs:format
                :~  ['type' s+'string']
                    ['description' s+'Search query (supports server:id filter inline). Empty string lists everything.']
                ==
                :-  'server'
                %-  pairs:enjs:format
                :~  ['type' s+'string']
                    ['description' s+'Optional filter to a single upstream id.']
                ==
                :-  'limit'
                %-  pairs:enjs:format
                :~  ['type' s+'integer']
                    ['description' s+'Max results (default 25, max 200).']
                ==
            ==
            ['required' a+~]
        ==
    ==
  =/  describe-tool=json
    %-  pairs:enjs:format
    :~  ['name' s+'describe']
        :-  'description'
        s+'Return the full schema (description + inputSchema) for a specific tool by its full prefixed name (e.g. "linear_create_issue"). Use after search to get the details needed to construct a call.'
        :-  'inputSchema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            :-  'properties'
            %-  pairs:enjs:format
            :~  :-  'name'
                %-  pairs:enjs:format
                :~  ['type' s+'string']
                    ['description' s+'Full tool name including server prefix, e.g. "linear_create_issue".']
                ==
            ==
            ['required' a+~[s+'name']]
        ==
    ==
  =/  call-tool=json
    %-  pairs:enjs:format
    :~  ['name' s+'call']
        :-  'description'
        s+'Invoke any tool from any configured upstream by its full prefixed name. Equivalent to calling the tool directly but the LLM does not need it to appear in the flat tools list; useful when code-mode collapses the catalog. Pass arguments matching the inputSchema of the tool (use describe to discover this).'
        :-  'inputSchema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            :-  'properties'
            %-  pairs:enjs:format
            :~  :-  'name'
                %-  pairs:enjs:format
                :~  ['type' s+'string']
                    ['description' s+'Full tool name including server prefix.']
                ==
                :-  'arguments'
                %-  pairs:enjs:format
                :~  ['type' s+'object']
                    ['description' s+'Arguments matching the tool inputSchema. Pass an empty object {} if the tool takes no arguments.']
                ==
            ==
            ['required' a+~[s+'name' s+'arguments']]
        ==
    ==
  ~[list-upstreams-tool search-tool describe-tool call-tool]
::
::  pull the 'name' field out of an MCP tool JSON object
::
++  tool-name
  |=  tool=json
  ^-  @t
  ?.  ?=(%o -.tool)  ''
  =/  v=(unit json)  (~(get by p.tool) 'name')
  ?~  v  ''
  ?.  ?=(%s -.u.v)  ''
  p.u.v
::
::  pull the 'description' field out of an MCP tool JSON object
::
++  tool-description
  |=  tool=json
  ^-  @t
  ?.  ?=(%o -.tool)  ''
  =/  v=(unit json)  (~(get by p.tool) 'description')
  ?~  v  ''
  ?.  ?=(%s -.u.v)  ''
  p.u.v
::
::  case-insensitive substring match
::
++  contains-ci
  |=  [haystack=@t needle=@t]
  ^-  ?
  ?:  =('' needle)  %.y
  =/  h=tape  (cass (trip haystack))
  =/  n=tape  (cass (trip needle))
  !=(~ (find n h))
::
::  parse a search query string of the form "[server:foo] [keyword keyword]"
::  returns the explicit server filter (or '') and the remaining keyword
::
++  parse-search-query
  |=  raw=@t
  ^-  [server=@t keywords=@t]
  =/  t=tape  (trip raw)
  =/  prefix=tape  "server:"
  =/  idx=(unit @ud)  (find prefix t)
  ?~  idx  ['' raw]
  =/  after-prefix=tape  (slag (add u.idx (lent prefix)) t)
  =/  end=(unit @ud)  (find " " after-prefix)
  =/  server-tape=tape
    ?~  end  after-prefix
    (scag u.end after-prefix)
  =/  rest-tape=tape
    ?~  end  ""
    (slag +(u.end) after-prefix)
  =/  before=tape  (scag u.idx t)
  =/  combined=tape  (weld before rest-tape)
  =/  trimmed=tape  (trim-spaces combined)
  [(crip server-tape) (crip trimmed)]
::
::  drop leading and trailing ASCII spaces
::
++  trim-spaces
  |=  t=tape
  ^-  tape
  =/  front=tape
    |-
    ?~  t  ~
    ?.  =(' ' i.t)  t
    $(t t.t)
  =/  back=tape  (flop front)
  =/  trimmed=tape
    |-
    ?~  back  ~
    ?.  =(' ' i.back)  back
    $(back t.back)
  (flop trimmed)
::
::  convert an OpenAPI spec to a list of MCP tool JSON objects
::
++  spec-to-tools
  |=  [sid=server-id:mcp-proxy spec=json]
  ^-  (list json)
  ::  detect format: Google Discovery vs OpenAPI
  =/  kind=@t  (get-json-string spec 'kind')
  ?:  =(kind 'discovery#restDescription')
    (discovery-to-tools spec)
  (openapi-to-tools spec)
::
::  convert Google Discovery Document to MCP tools
::
++  discovery-to-tools
  |=  spec=json
  ^-  (list json)
  =/  resources=json  (get-json-field spec 'resources')
  ?.  ?=(%o -.resources)  ~
  =/  res  (mule |.((walk-discovery-resources resources)))
  ?:(?=(%& -.res) p.res ~)
::
++  walk-discovery-resources
  |=  resources=json
  ^-  (list json)
  ?~  resources  ~
  ?.  ?=(%o -.resources)  ~
  %-  zing
  %+  turn  ~(tap by p.resources)
  |=  [rname=@t robj=json]
  ?~  robj  ~
  ?.  ?=(%o -.robj)  ~
  =/  methods=json  (get-json-field robj 'methods')
  =/  method-tools=(list json)
    ?~  methods  ~
    ?.  ?=(%o -.methods)  ~
    %+  murn  ~(tap by p.methods)
    |=  [mname=@t mobj=json]
    ^-  (unit json)
    ?~  mobj  ~
    ?.  ?=(%o -.mobj)  ~
    =/  op-id=@t  (get-json-string mobj 'id')
    ?:  =('' op-id)  ~
    =/  desc=@t  (get-json-string mobj 'description')
    =/  params-obj=json  (get-json-field mobj 'parameters')
    =/  props=(map @t json)  ~
    =/  reqs=(list json)  ~
    =?  props  &(?=(^ params-obj) ?=(%o -.params-obj))
      %-  ~(gas by props)
      %+  murn  ~(tap by p.params-obj)
      |=  [pname=@t pobj=json]
      ^-  (unit [@t json])
      ?~  pobj  ~
      ?.  ?=(%o -.pobj)  ~
      =/  ptype=@t  (get-json-string pobj 'type')
      =/  pdesc=@t  (get-json-string pobj 'description')
      =/  prop=(map @t json)
        (~(put by *(map @t json)) 'type' s+?:(=('' ptype) 'string' ptype))
      =?  prop  !=('' pdesc)
        (~(put by prop) 'description' s+pdesc)
      `[pname [%o prop]]
    =?  reqs  &(?=(^ params-obj) ?=(%o -.params-obj))
      %+  murn  ~(tap by p.params-obj)
      |=  [pname=@t pobj=json]
      ?~  pobj  ~
      ?.  ?=(%o -.pobj)  ~
      ?.  =([~ %b %.y] (~(get by p.pobj) 'required'))  ~
      `s+pname
    =/  has-req=?  (~(has by p.mobj) 'request')
    =?  props  has-req
      (~(put by props) 'body' [%o (~(put by *(map @t json)) 'type' s+'string')])
    %-  some
    %-  pairs:enjs:format
    :~  ['name' s+op-id]
        ['description' s+desc]
        :-  'inputSchema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            ['properties' [%o props]]
            ['required' [%a reqs]]
        ==
    ==
  =/  sub-resources=json  (get-json-field robj 'resources')
  =/  sub-tools=(list json)
    ?~  sub-resources  ~
    ?.  ?=(%o -.sub-resources)  ~
    (walk-discovery-resources sub-resources)
  (weld method-tools sub-tools)
::
::  convert OpenAPI spec to MCP tools
::
++  openapi-to-tools
  |=  spec=json
  ^-  (list json)
  =/  paths=json  (get-json-field spec 'paths')
  ?.  ?=(%o -.paths)  ~
  =/  result=(list json)  ~
  =/  items=(list [@t json])  ~(tap by p.paths)
  |-
  ?~  items  (flop result)
  =/  [path-str=@t path-item=json]  i.items
  ?.  ?=(%o -.path-item)  $(items t.items)
  =/  meths=(list [@t json])  ~(tap by p.path-item)
  =/  path-tools=(list json)
    =/  ml=(list [@t json])  meths
    |-
    ?~  ml  ~
    =/  [meth=@t op=json]  i.ml
    ?.  (~(has in http-methods) meth)  $(ml t.ml)
    ?.  ?=(%o -.op)  $(ml t.ml)
    =/  op-id=@t  (get-json-string op 'operationId')
    ?:  =('' op-id)  $(ml t.ml)
    =/  desc=@t  (get-json-string op 'summary')
    =?  desc  =('' desc)  (get-json-string op 'description')
    ::  skip streaming/webhook by tag
    =/  skip=?
      =/  tags=(unit json)  (~(get by p.op) 'tags')
      ?~  tags  %.n
      ?.  ?=(%a -.u.tags)  %.n
      %+  lien  p.u.tags
      |=  tag=json
      ?.  ?=(%s -.tag)  %.n
      =/  lo=tape  (cass (trip p.tag))
      ?|  !=(~ (find "stream" lo))
          !=(~ (find "webhook" lo))
      ==
    ?:  skip  $(ml t.ml)
    ::  build a tool schema from path/query parameters and requestBody
    =/  tool=json
      %-  pairs:enjs:format
      :~  ['name' s+op-id]
          ['description' s+desc]
          ['inputSchema' (operation-input-schema spec path-str path-item op)]
      ==
    [tool $(ml t.ml)]
  $(items t.items, result (weld path-tools result))
::
::  find an OpenAPI operation by operationId and return [path method operation]
::
++  find-operation
  |=  [spec=json op-id=@t]
  ^-  (unit [path=@t method=@t operation=json])
  =/  kind=@t  (get-json-string spec 'kind')
  ?:  =(kind 'discovery#restDescription')
    (find-discovery-operation spec op-id)
  =/  paths=json  (get-json-field spec 'paths')
  ?.  ?=(%o -.paths)  ~
  =/  items=(list [@t json])  ~(tap by p.paths)
  |-
  ?~  items  ~
  =/  [path-str=@t path-item=json]  i.items
  ?.  ?=(%o -.path-item)
    $(items t.items)
  =/  methods=(list [@t json])  ~(tap by p.path-item)
  =/  found=(unit [path=@t method=@t operation=json])
    =/  ml=(list [@t json])  methods
    |-
    ?~  ml  ~
    =/  [m=@t op=json]  i.ml
    ?.  (~(has in http-methods) m)  $(ml t.ml)
    ?.  ?=(%o -.op)  $(ml t.ml)
    =/  this-id=@t  (get-json-string op 'operationId')
    ?:  =(this-id op-id)  `[path-str m op]
    $(ml t.ml)
  ?^  found  found
  $(items t.items)
::
::  build an HTTP request URL from an OpenAPI path template + args
::
++  find-discovery-operation
  |=  [spec=json op-id=@t]
  ^-  (unit [path=@t method=@t operation=json])
  =/  resources=json  (get-json-field spec 'resources')
  ?~  resources  ~
  ?.  ?=(%o -.resources)  ~
  (search-discovery-resources resources op-id)
::
++  search-discovery-resources
  |=  [resources=json op-id=@t]
  ^-  (unit [path=@t method=@t operation=json])
  ?~  resources  ~
  ?.  ?=(%o -.resources)  ~
  =/  items=(list [@t json])  ~(tap by p.resources)
  |-
  ?~  items  ~
  =/  [rname=@t robj=json]  i.items
  ?~  robj  $(items t.items)
  ?.  ?=(%o -.robj)  $(items t.items)
  ::  check methods
  =/  methods=json  (get-json-field robj 'methods')
  =/  found=(unit [path=@t method=@t operation=json])
    ?~  methods  ~
    ?.  ?=(%o -.methods)  ~
    =/  ml=(list [@t json])  ~(tap by p.methods)
    |-
    ?~  ml  ~
    =/  [mname=@t mobj=json]  i.ml
    ?~  mobj  $(ml t.ml)
    ?.  ?=(%o -.mobj)  $(ml t.ml)
    =/  mid=@t  (get-json-string mobj 'id')
    ?.  =(mid op-id)  $(ml t.ml)
    =/  http-method=@t  (get-json-string mobj 'httpMethod')
    =/  mpath=@t
      =/  fp=@t  (get-json-string mobj 'flatPath')
      ?:(=('' fp) (get-json-string mobj 'path') fp)
    `[mpath http-method mobj]
  ?^  found  found
  ::  recurse sub-resources
  =/  sub=json  (get-json-field robj 'resources')
  =/  sub-found=(unit [path=@t method=@t operation=json])
    ?~  sub  ~
    ?.  ?=(%o -.sub)  ~
    (search-discovery-resources sub op-id)
  ?^  sub-found  sub-found
  $(items t.items)
::
++  build-api-url
  |=  [base=@t path-template=@t args=json]
  ^-  @t
  ::  substitute {param} in the path with values from args
  =/  base-t=tape  (trip base)
  ::  strip trailing / from base
  =?  base-t  &(!=(~ base-t) =('/' (rear base-t)))
    (snip base-t)
  =/  path-t=tape  (trip path-template)
  ::  ensure a '/' separator between base and path. discovery spec
  ::  paths (e.g. "users/{userId}/profile") omit the leading slash.
  =?  path-t  &(!=(~ path-t) !=('/' -.path-t))
    ['/' path-t]
  =/  result=tape  base-t
  =/  i=@ud  0
  |-
  ?:  (gte i (lent path-t))
    (crip result)
  =/  c=@  (snag i path-t)
  ?.  =(c '{')
    $(result (snoc result c), i +(i))
  ::  find closing }
  =/  rest=tape  (slag +(i) path-t)
  =/  close=(unit @ud)  (find "}" rest)
  ?~  close
    $(result (snoc result c), i +(i))
  =/  param-name=@t  (crip (scag u.close rest))
  =/  param-val=@t  (get-json-string args param-name)
  =/  val-tape=tape  (trip (percent-encode param-val))
  $(result (weld result val-tape), i (add i (add 2 u.close)))
::
::  build query string from OpenAPI params + args
::
++  build-query-string
  |=  [params=(list json) args=json]
  ^-  @t
  ?.  ?=(%o -.args)  ''
  =/  query-parts=(list @t)
    %+  murn  params
    |=  param=json
    ^-  (unit @t)
    ?~  param  ~
    ?.  ?=(%o -.param)  ~
    =/  pin=@t  (get-json-string param 'in')
    ?.  =(pin 'query')  ~
    =/  pname=@t  (get-json-string param 'name')
    =/  val=(unit json)  (~(get by p.args) pname)
    ?~  val  ~
    =/  v=@t  (json-query-value u.val)
    ?:  =('' v)  ~
    =/  part=@t
      %+  rap  3
      :~  (percent-encode pname)  '='  (percent-encode v)
      ==
    `part
  ?~  query-parts  ''
  =/  result=@t  i.query-parts
  =/  rest=(list @t)  t.query-parts
  |-
  ?~  rest  (cat 3 '?' result)
  $(result (cat 3 result (cat 3 '&' i.rest)), rest t.rest)
::
++  get-spec-base-url
  |=  spec=json
  ^-  @t
  =/  kind=@t  (get-json-string spec 'kind')
  ?:  =(kind 'discovery#restDescription')
    ::  Google Discovery: use baseUrl or rootUrl
    =/  base=@t  (get-json-string spec 'baseUrl')
    ?:(=('' base) (get-json-string spec 'rootUrl') base)
  ::  Swagger 2.0: compose scheme+host+basePath when available;
  ::  fall back to just basePath (a path the caller will append to
  ::  the operator-supplied upstream URL).
  ::
  =/  swagger-version=@t  (get-json-string spec 'swagger')
  ?:  !=('' swagger-version)
    =/  base-path=@t   (get-json-string spec 'basePath')
    =/  host=@t        (get-json-string spec 'host')
    ?:  =('' host)  base-path
    =/  schemes=json   (get-json-field spec 'schemes')
    =/  scheme=@t
      ?.  ?=(%a -.schemes)  'https'
      ?~  p.schemes        'https'
      ::  pull out the first scheme as the default; then walk t.p.schemes
      ::  (which keeps its full list type including the empty case) to
      ::  see if any element prefers 'https' — if so, use it.
      ::
      =/  first-scheme=@t
        ?:  ?=(%s -.i.p.schemes)  p.i.p.schemes
        'https'
      ?:  =('https' first-scheme)  'https'
      =/  has-https=?
        =/  rest  t.p.schemes
        |-  ^-  ?
        ?~  rest  %.n
        ?:  ?=(%s -.i.rest)
          ?:  =('https' p.i.rest)  %.y
          $(rest t.rest)
        $(rest t.rest)
      ?:  has-https  'https'
      first-scheme
    %+  rap  3
    :~  scheme  '://'  host  base-path
    ==
  ::  OpenAPI 3.0: use servers[0].url
  =/  servers=json  (get-json-field spec 'servers')
  ?.  ?=(%a -.servers)  ''
  ?~  p.servers  ''
  (get-json-string i.p.servers 'url')
::
++  apply-tool-filter
  |=  [sid=server-id:mcp-proxy tools=(list json) filters=(map server-id:mcp-proxy tool-filter:mcp-proxy)]
  ^-  (list json)
  =/  filt=(unit tool-filter:mcp-proxy)  (~(get by filters) sid)
  ?~  filt  tools
  %+  skim  tools
  |=  tool=json
  =/  tool-name=@t  (get-json-string tool 'name')
  ?-  mode.u.filt
    %allow  (~(has in tools.u.filt) tool-name)
    %block  !(~(has in tools.u.filt) tool-name)
  ==
::
++  extract-path-params
  |=  path-template=@t
  ^-  (set @t)
  =/  t=tape  (trip path-template)
  =/  result=(set @t)  ~
  |-
  ?~  t  result
  ?.  =(i.t '{')  $(t t.t)
  =/  rest=tape  t.t
  =/  close=(unit @ud)  (find "}" rest)
  ?~  close  result
  =/  param=@t  (crip (scag u.close rest))
  $(t (slag +(u.close) rest), result (~(put in result) param))
::
++  build-all-args-query
  |=  [args=json exclude=(set @t)]
  ^-  @t
  ?.  ?=(%o -.args)  ''
  =/  items=(list [@t json])  ~(tap by p.args)
  =/  parts=(list @t)
    %+  murn  items
    |=  [key=@t val=json]
    ^-  (unit @t)
    ?:  (~(has in exclude) key)  ~
    ::  skip null values — json `~` is the atom 0 and crashes -.val
    ?~  val  ~
    =/  v=@t  (json-query-value val)
    ?:  =('' v)  ~
    =/  part=@t
      %+  rap  3
      :~  (percent-encode key)  '='  (percent-encode v)
      ==
    `part
  ?~  parts  ''
  =/  result=@t  i.parts
  =/  rest=(list @t)  t.parts
  |-
  ?~  rest  (cat 3 '?' result)
  $(result (cat 3 result (cat 3 '&' i.rest)), rest t.rest)
::
++  get-request-body-json
  |=  args=json
  ^-  json
  ?.  ?=(%o -.args)  [%o ~]
  =/  body=(unit json)  (~(get by p.args) 'body')
  ?~  body  args
  u.body
::
++  operation-input-schema
  |=  [spec=json path-template=@t path-item=json op=json]
  ^-  json
  =/  params=(list json)
    %+  weld
      (get-json-array path-item 'parameters')
    (get-json-array op 'parameters')
  =/  props=(map @t json)
    %-  ~(gas by *(map @t json))
    %+  murn  params
    |=  param=json
    (parameter-property spec param)
  =/  reqs=(list json)
    %+  murn  params
    |=  param=json
    (parameter-required spec param)
  =/  fallback-paths=(list @t)
    %+  skim  ~(tap in (extract-path-params path-template))
    |=  pname=@t
    !(~(has by props) pname)
  =?  props  ?=(^ fallback-paths)
    %-  ~(gas by props)
    %+  turn  fallback-paths
    |=  pname=@t
    ^-  [@t json]
    [pname (simple-schema-property 'string' 'Path parameter.')]
  =?  reqs  ?=(^ fallback-paths)
    %+  weld  reqs
    %+  turn  fallback-paths
    |=  pname=@t
    ^-  json
    s+pname
  =/  body-prop=(unit [name=@t prop=json])
    (request-body-property spec op)
  =?  props  ?=(^ body-prop)
    =/  [body-name=@t body-json=json]  u.body-prop
    (~(put by props) body-name body-json)
  =?  reqs  ?&(?=(^ body-prop) (request-body-required spec op))
    (snoc reqs s+'body')
  %-  pairs:enjs:format
  :~  ['type' s+'object']
      ['properties' [%o props]]
      ['required' a+reqs]
  ==
::
++  get-json-array
  |=  [jon=json key=@t]
  ^-  (list json)
  =/  val=json  (get-json-field jon key)
  ?~  val  ~
  ?.  ?=(%a -.val)  ~
  p.val
::
++  resolve-openapi-ref
  |=  [spec=json jon=json]
  ^-  json
  (resolve-openapi-ref-depth spec jon 8)
::
++  resolve-openapi-ref-depth
  |=  [spec=json jon=json depth=@ud]
  ^-  json
  ?:  =(0 depth)  jon
  ?~  jon  ~
  ?.  ?=(%o -.jon)  jon
  =/  ref=@t  (get-json-string jon '$ref')
  ?:  =('' ref)  jon
  =/  target=(unit json)  (json-pointer-get spec ref)
  ?~  target  jon
  (resolve-openapi-ref-depth spec u.target (sub depth 1))
::
++  json-pointer-get
  |=  [jon=json ref=@t]
  ^-  (unit json)
  =/  chars=tape  (trip ref)
  ?~  chars  ~
  ?.  =('#' i.chars)  ~
  =/  rest=tape  t.chars
  ?~  rest  ~
  ?.  =('/' i.rest)  ~
  (json-pointer-walk jon (split-json-pointer t.rest))
::
++  json-pointer-walk
  |=  [jon=json parts=(list @t)]
  ^-  (unit json)
  ?~  parts  `jon
  ?~  jon  ~
  ?.  ?=(%o -.jon)  ~
  =/  next=(unit json)  (~(get by p.jon) i.parts)
  ?~  next  ~
  $(jon u.next, parts t.parts)
::
++  split-json-pointer
  |=  chars=tape
  ^-  (list @t)
  =/  res=(list @t)  ~
  =/  seg=tape  ~
  |-
  ?~  chars
    (flop [(json-pointer-unescape (crip seg)) res])
  ?:  =('/' i.chars)
    $(chars `tape`t.chars, res [(json-pointer-unescape (crip seg)) res], seg ~)
  $(chars `tape`t.chars, seg (snoc seg i.chars))
::
++  json-pointer-unescape
  |=  raw=@t
  ^-  @t
  =/  chars=tape  (trip raw)
  =/  out=tape  ~
  |-
  ?~  chars
    (crip out)
  =/  c=@tD  i.chars
  ?.  =(c '~')
    $(chars t.chars, out (snoc out c))
  ?~  t.chars
    $(chars t.chars, out (snoc out c))
  =/  n=@tD  i.t.chars
  ?:  =(n '1')
    $(chars t.t.chars, out (snoc out '/'))
  ?:  =(n '0')
    $(chars t.t.chars, out (snoc out '~'))
  $(chars t.chars, out (snoc out c))
::
++  parameter-property
  |=  [spec=json param=json]
  ^-  (unit [@t json])
  =/  param=json  (resolve-openapi-ref spec param)
  ?~  param  ~
  ?.  ?=(%o -.param)  ~
  =/  pin=@t  (get-json-string param 'in')
  ?.  ?|(=(pin 'path') =(pin 'query'))  ~
  =/  pname=@t  (get-json-string param 'name')
  ?:  =('' pname)  ~
  =/  desc=@t  (get-json-string param 'description')
  =/  schema=json  (get-json-field param 'schema')
  =/  typ=@t  (get-json-string param 'type')
  =/  prop=json
    ?~  schema
      (simple-schema-property ?:(=('' typ) 'string' typ) desc)
    ?.  ?=(%o -.schema)
      (simple-schema-property ?:(=('' typ) 'string' typ) desc)
    (schema-with-description spec schema desc)
  `[pname prop]
::
++  parameter-required
  |=  [spec=json param=json]
  ^-  (unit json)
  =/  param=json  (resolve-openapi-ref spec param)
  ?~  param  ~
  ?.  ?=(%o -.param)  ~
  =/  pin=@t  (get-json-string param 'in')
  ?.  ?|(=(pin 'path') =(pin 'query'))  ~
  =/  pname=@t  (get-json-string param 'name')
  ?:  =('' pname)  ~
  ?:  =(pin 'path')  `s+pname
  =/  req=json  (get-json-field param 'required')
  ?~  req  ~
  ?.  ?=(%b -.req)  ~
  ?.  p.req  ~
  `s+pname
::
++  request-body-property
  |=  [spec=json op=json]
  ^-  (unit [name=@t prop=json])
  =/  body=json  (resolve-openapi-ref spec (get-json-field op 'requestBody'))
  ?~  body  ~
  ?.  ?=(%o -.body)  ~
  =/  desc=@t  (get-json-string body 'description')
  =/  schema=json  (request-body-schema spec body)
  =/  prop=json
    ?~  schema
      (simple-schema-property 'object' desc)
    ?.  ?=(%o -.schema)
      (simple-schema-property 'object' desc)
    (schema-with-description spec schema desc)
  `['body' prop]
::
++  request-body-required
  |=  [spec=json op=json]
  ^-  ?
  =/  body=json  (resolve-openapi-ref spec (get-json-field op 'requestBody'))
  ?~  body  %.n
  ?.  ?=(%o -.body)  %.n
  =/  req=json  (get-json-field body 'required')
  ?~  req  %.n
  ?.  ?=(%b -.req)  %.n
  p.req
::
++  request-body-schema
  |=  [spec=json body=json]
  ^-  json
  ?~  body  ~
  ?.  ?=(%o -.body)  ~
  =/  content=json  (get-json-field body 'content')
  ?~  content  ~
  ?.  ?=(%o -.content)  ~
  =/  media=(unit json)  (~(get by p.content) 'application/json')
  ?~  media  ~
  (resolve-openapi-ref spec (get-json-field u.media 'schema'))
::
++  schema-with-description
  |=  [spec=json schema=json desc=@t]
  ^-  json
  =/  schema=json  (resolve-openapi-ref spec schema)
  ?~  schema  ~
  ?.  ?=(%o -.schema)  schema
  =/  prop=(map @t json)  p.schema
  =?  prop  ?&(!=('' desc) !(~(has by prop) 'description'))
    (~(put by prop) 'description' s+desc)
  [%o prop]
::
++  simple-schema-property
  |=  [typ=@t desc=@t]
  ^-  json
  =/  fields=(list [@t json])
    :~  ['type' s+typ]
    ==
  =?  fields  !=('' desc)
    (snoc fields ['description' s+desc])
  [%o (malt fields)]
::
++  json-query-value
  |=  val=json
  ^-  @t
  ?~  val  ''
  ?+  -.val  (en:json:html val)
    %s  p.val
    %n  p.val
    %b  ?:(p.val 'true' 'false')
  ==
::
++  percent-encode
  |=  raw=@t
  ^-  @t
  =/  chars=tape  (trip raw)
  =/  out=tape  ~
  |-
  ?~  chars
    (crip out)
  =/  c=@tD  i.chars
  ?:  (url-unreserved c)
    $(chars t.chars, out (snoc out c))
  $(chars t.chars, out (weld out (percent-byte c)))
::
++  url-unreserved
  |=  c=@
  ^-  ?
  ?|  ?&((gte c 'a') (lte c 'z'))
      ?&((gte c 'A') (lte c 'Z'))
      ?&((gte c '0') (lte c '9'))
      =(c '-')
      =(c '.')
      =(c '_')
      =(c '~')
  ==
::
++  percent-byte
  |=  c=@
  ^-  tape
  :~  '%'
      (hex-char (div c 16))
      (hex-char (mod c 16))
  ==
::
++  hex-char
  |=  n=@ud
  ^-  @tD
  ?:  (lth n 10)
    `@tD`(add '0' n)
  `@tD`(add 'A' (sub n 10))
::
++  get-optional-string
  |=  [jon=json key=@t]
  ^-  (unit @t)
  ?.  ?=(%o -.jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  ?.  ?=(%s -.u.v)  ~
  ?:  =('' p.u.v)  ~
  `p.u.v
::
++  get-optional-tas
  |=  [jon=json key=@t]
  ^-  (unit @tas)
  ?.  ?=(%o -.jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  ?.  ?=(%s -.u.v)  ~
  ?:  =('' p.u.v)  ~
  ``@tas`p.u.v
::
++  get-oauth-header
  |=  [oauth-prov=(unit @tas) our=@p now=@da]
  ^-  (unit [key=@t value=@t])
  ?~  oauth-prov  ~
  ::  use the auth-header scry which checks expiry
  =/  hdr=@t
    =/  res  (mule |.(.^(@t %gx /(scot %p our)/oauth/(scot %da now)/auth-header/[u.oauth-prov]/noun)))
    ?:(?=(%& -.res) p.res '')
  ?:  =('' hdr)  ~
  `['authorization' hdr]
::
::  build iris cards that POST tools/list to every enabled %proxy
::  upstream so proxy-tools-cache can be primed without waiting for
::  the next fan-out. mirrors the openapi spec-fetch in on-load —
::  fire-and-forget; the response is handled by the [%iris %prime]
::  arm in on-arvo. The built-in self upstream points at the native
::  /mcp server, not /apps/mcp/mcp, so it is safe and necessary to
::  prime it for code-mode search.
::
++  prime-proxy-cards
  |=  $:  servers=(map server-id:mcp-proxy mcp-server:mcp-proxy)
          server-order=(list server-id:mcp-proxy)
          cookies=(map server-id:mcp-proxy @t)
          our=@p
          now=@da
      ==
  ^-  (list card:agent:gall)
  ::  Two-stage handshake: initialize first; the [%iris %init @ ~]
  ::  arvo handler captures the assigned Mcp-Session-Id and queues
  ::  the actual tools/list. Servers that don't enforce sessions
  ::  (e.g. Linear) are unaffected — they just don't return the
  ::  Mcp-Session-Id header and we fall through to a session-less
  ::  tools/list.
  ::
  =/  init-body=@t  build-init-body
  %+  murn  server-order
  |=  sid=server-id:mcp-proxy
  ^-  (unit card:agent:gall)
  =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
  ?~  srv  ~
  ?.  enabled.u.srv  ~
  ?.  =(%proxy mode.u.srv)  ~
  %-  some
  %+  build-mcp-iris-card  /iris/init/[sid]
  :*  url.u.srv
      headers.u.srv
      (~(get by cookies) sid)
      ~
      ::  Do not scry %oauth while Gall is reviving this desk. During
      ::  install/unsuspend, %oauth may not be live yet, and a failed
      ::  cross-agent peek suspends the whole desk. Runtime calls and
      ::  action-driven priming still attach OAuth headers.
      ~
      init-body
  ==
::
::  build a single iris card that POSTs initialize to one upstream
::  (used by add-server / refresh-spec to prime just the affected
::  upstream rather than every one). The actual tools/list fires
::  from the [%iris %init @ ~] handler once the session is known.
::
++  prime-one-proxy-card
  |=  $:  sid=server-id:mcp-proxy
          srv=mcp-server:mcp-proxy
          cookie=(unit @t)
          our=@p
          now=@da
      ==
  ^-  (unit card:agent:gall)
  ?.  enabled.srv  ~
  ?.  =(%proxy mode.srv)  ~
  %-  some
  %+  build-mcp-iris-card  /iris/init/[sid]
  :*  url.srv
      headers.srv
      cookie
      ~
      (get-oauth-header oauth-provider.srv our now)
      build-init-body
  ==
::
::  body for the initial MCP handshake. Sent on /iris/init/<sid>.
::
::  extract Mcp-Session-Id from a response-headers list (case-insensitive
::  per HTTP spec). Per MCP Streamable HTTP §2025-06-18, clients SHOULD
::  update their cached session id whenever a server returns one — not
::  just on initialize. Some servers (Supabase, Ref) rotate the session
::  id mid-flight; clients that only capture from initialize end up
::  sending a stale id and getting empty/200 in return.
::
++  extract-session-id
  |=  hs=(list [key=@t value=@t])
  ^-  (unit @t)
  ?~  hs  ~
  ?:  =((cass (trip key.i.hs)) "mcp-session-id")
    `value.i.hs
  $(hs t.hs)
::
++  build-init-body
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['jsonrpc' s+'2.0']
      ['method' s+'initialize']
      ['id' (numb:enjs:format 0)]
      :-  'params'
      %-  pairs:enjs:format
      :~  ['protocolVersion' s+'2025-03-26']
          ['capabilities' (pairs:enjs:format ~)]
          :-  'clientInfo'
          %-  pairs:enjs:format
          :~  ['name' s+'urbit-mcp']
              ['version' s+'0.1']
          ==
      ==
  ==
::
::  body for tools/list. Sent on /iris/prime/<sid> after init.
::
++  build-tools-list-body
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['jsonrpc' s+'2.0']
      ['method' s+'tools/list']
      ['id' (numb:enjs:format 1)]
      ['params' (pairs:enjs:format ~)]
  ==
::
::  body for the notifications/initialized notification, fired
::  fire-and-forget after init. Per MCP spec a client must send
::  this before any request other than initialize.
::
++  build-initialized-body
  ^-  @t
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['jsonrpc' s+'2.0']
      ['method' s+'notifications/initialized']
      ['params' (pairs:enjs:format ~)]
  ==
::
::  consolidate the standard MCP request-card construction. wraps
::  url + per-server headers + cookie + session-id + oauth bearer
::  + body into a single iris %request card on the given wire.
::
++  build-mcp-iris-card
  |=  $:  =wire
          url=@t
          extra-headers=(list [key=@t value=@t])
          cookie=(unit @t)
          session=(unit @t)
          oauth-hdr=(unit [key=@t value=@t])
          body=@t
      ==
  ^-  card:agent:gall
  =/  out-headers=(list [key=@t value=@t])
    %+  weld
      :~  ['content-type' 'application/json']
          ['accept' 'application/json, text/event-stream']
          ['mcp-protocol-version' '2025-03-26']
          ['user-agent' 'urbit-mcp']
      ==
    extra-headers
  =?  out-headers  ?=(^ cookie)
    (snoc out-headers ['cookie' u.cookie])
  =?  out-headers  ?=(^ session)
    (snoc out-headers ['mcp-session-id' u.session])
  =?  out-headers  ?=(^ oauth-hdr)
    (snoc out-headers u.oauth-hdr)
  :*  %pass  wire
      %arvo  %i  %request
      [%'POST' url out-headers `(as-octs:mimes:html body)]
      *outbound-config:iris
  ==
::
::  extract the JSON payload from a Server-Sent Events response.
::  an MCP server may return either:
::    application/json           → body is the raw JSON, return as-is
::    text/event-stream          → body is e.g. "event: message\ndata: {...}\n\n"
::  for the SSE case we find the first "data: " marker (which may be
::  preceded by "event: message" or other SSE fields), skip it, and
::  take everything up to the next newline.
::
++  strip-sse
  |=  body=@t
  ^-  @t
  =/  t=tape  (trip body)
  =/  len=@ud  (lent t)
  ::  only unwrap when the body actually is an SSE stream: after any
  ::  leading whitespace it must begin with an SSE field or comment
  ::  line. plain JSON bodies can contain "data: " inside string
  ::  content (posthog tool descriptions do) and must not be sliced.
  =/  lead=tape
    |-  ^-  tape
    ?~  t  ~
    ?:  ?|(=(10 i.t) =(13 i.t) =(32 i.t))  $(t t.t)
    t
  =/  is-sse=?
    ?~  lead  %.n
    ?|  =("data:" (scag 5 lead))
        =("event:" (scag 6 lead))
        =("id:" (scag 3 lead))
        =("retry:" (scag 6 lead))
        =(':' i.lead)
    ==
  ?.  is-sse  body
  ::  find "data: " (with space)
  =/  idx=(unit @ud)  (find "data: " t)
  =/  data-start=(unit @ud)
    ?^  idx  `(add u.idx 6)
    ::  try "data:" without space
    =/  idx2=(unit @ud)  (find "data:" t)
    ?~  idx2  ~
    `(add u.idx2 5)
  ?~  data-start  body
  =/  after=tape  (slag u.data-start t)
  ::  truncate at the first newline (end of the data field)
  =/  nl=(unit @ud)  (find ~[10] after)
  =/  extracted=tape
    ?~  nl  after
    (scag u.nl after)
  ::  trim leading whitespace (SSE spec allows a space after "data:")
  |-  ^-  @t
  ?~  extracted  (crip extracted)
  ?:  ?|(=(10 i.extracted) =(13 i.extracted) =(32 i.extracted))
    $(extracted t.extracted)
  (crip extracted)
::
++  get-base-url
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  =/  scheme-mark=(unit @ud)  (find "://" t)
  ?~  scheme-mark  url
  =/  after-scheme=@ud  (add 3 u.scheme-mark)
  =/  rest=tape  (slag after-scheme t)
  =/  path-start=(unit @ud)  (find "/" rest)
  ?~  path-start  url
  (crip (scag (add after-scheme u.path-start) t))
::
++  get-json-field
  |=  [jon=json key=@t]
  ^-  json
  ?~  jon  ~
  ?.  ?=(%o -.jon)  ~
  (fall (~(get by p.jon) key) ~)
::
++  get-json-string
  |=  [jon=json key=@t]
  ^-  @t
  =/  v=json  (get-json-field jon key)
  ?~  v  ''
  ?:  ?=(%s -.v)  p.v
  ?:  ?=(%n -.v)  p.v
  ?:  ?=(%b -.v)  ?:(p.v 'true' 'false')
  ''
::
++  split-on-underscore
  |=  name=@t
  ^-  [@t @t]
  =/  t=tape  (trip name)
  =/  idx=(unit @ud)  (find "_" t)
  ?~  idx  [name '']
  [(crip (scag u.idx t)) (crip (slag +(u.idx) t))]
::
++  parse-json-action
  |=  jon=json
  ^-  (unit action:mcp-proxy)
  =/  res  (mule |.((parse-json-action-raw jon)))
  ?:  ?=(%& -.res)  `p.res
  ~
::
++  parse-json-action-raw
  |=  jon=json
  ^-  action:mcp-proxy
  =,  dejs:format
  =/  typ=@t  ((ot ~[action+so]) jon)
  ?+  typ  !!
      %'add-server'
    =/  f
      %-  ot
      :~  id+so  name+so  url+so
          headers+(ar (ot ~[key+so value+so]))
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy)]  (f jon)
    =/  oprov=(unit @tas)  (get-optional-tas jon 'oauth-provider')
    =/  surl=(unit @t)  (get-optional-string jon 'schema-url')
    =/  md=server-mode:mcp-proxy
      =/  m=@t  (get-json-string jon 'mode')
      ?:(=('openapi' m) %openapi %proxy)
    [%add-server `@tas`id [name url headers %.y oprov md surl]]
      %'config-oauth-server'
    =/  f
      %-  ot
      :~  id+so  name+so  url+so
          headers+(ar (ot ~[key+so value+so]))
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy)]  (f jon)
    =/  oprov=(unit @tas)  (get-optional-tas jon 'oauth-provider')
    =/  surl=(unit @t)  (get-optional-string jon 'schema-url')
    =/  md=server-mode:mcp-proxy
      =/  m=@t  (get-json-string jon 'mode')
      ?:(=('openapi' m) %openapi %proxy)
    [%config-oauth-server `@tas`id [name url headers %.y oprov md surl]]
      %'remove-server'
    [%remove-server `@tas`((ot ~[id+so]) jon)]
      %'update-server'
    =/  f
      %-  ot
      :~  id+so  name+so  url+so
          headers+(ar (ot ~[key+so value+so]))
          enabled+bo
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy) enabled=?]  (f jon)
    =/  oprov=(unit @tas)  (get-optional-tas jon 'oauth-provider')
    =/  surl=(unit @t)  (get-optional-string jon 'schema-url')
    =/  md=server-mode:mcp-proxy
      =/  m=@t  (get-json-string jon 'mode')
      ?:(=('openapi' m) %openapi %proxy)
    [%update-server `@tas`id [name url headers enabled oprov md surl]]
      %'toggle-server'
    [%toggle-server `@tas`((ot ~[id+so]) jon)]
      %'refresh-spec'
    [%refresh-spec `@tas`((ot ~[id+so]) jon)]
      %'set-tool-filter'
    =/  id=@t  (get-json-string jon 'id')
    =/  fmode=@t  (get-json-string jon 'mode')
    =/  tool-list=(list json)
      =/  v=json  (get-json-field jon 'tools')
      ?.  ?=(%a -.v)  ~
      p.v
    =/  tool-set=(set @t)
      %-  silt
      %+  murn  tool-list
      |=(j=json ?.(?=(%s -.j) ~ `p.j))
    [%set-tool-filter `@tas`id [?:(?=(%'allow' fmode) %allow %block) tool-set]]
      %'clear-tool-filter'
    [%clear-tool-filter `@tas`((ot ~[id+so]) jon)]
      %'login-server'
    [%login-server `@tas`((ot ~[id+so]) jon)]
      %'set-client-key'
    [%set-client-key (get-json-string jon 'key')]
      %'regenerate-client-key'
    [%regenerate-client-key ~]
      %'clear-client-key'
    [%clear-client-key ~]
      %'set-code-mode'
    =/  v=json  (get-json-field jon 'on')
    ?.  ?=(%b -.v)  [%set-code-mode %.n]
    [%set-code-mode p.v]
  ==
::
++  server-to-json
  |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['id' s+(scot %tas sid)]
      ['name' s+name.srv]
      ['url' s+url.srv]
      ['enabled' b+enabled.srv]
      :-  'headers'  :-  %a
      %+  turn  headers.srv
      |=  h=header:mcp-proxy
      (pairs ~[['key' s+key.h] ['value' s+value.h]])
  ==
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
--