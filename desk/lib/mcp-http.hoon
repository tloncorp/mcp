::  mcp-http: Streamable HTTP responses, SSE, and list notifications
::
/-  mcp
/+  server
|%
++  mcp-protocol-version  %'2025-11-25'
::
++  simple-response
  |=  [eyre-id=@ta status=@ud headers=(list [key=@t value=@t])]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server
    eyre-id
  ^-  simple-payload:http
  [[status headers] ~]
::
++  send-event
  |=  [eyre-id=@ta =json]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server
    eyre-id
  ^-  simple-payload:http
  :-  :-  200
      :~  ['content-type' 'application/json']
          ['cache-control' 'no-cache']
          ['MCP-Protocol-Version' mcp-protocol-version]
      ==
  %-  some
  %-  as-octt:mimes:html
  (trip (en:json:html json))
::
++  sse-data
  |=  =json
  ^-  octs
  %-  as-octt:mimes:html
  (trip (cat 3 'data: ' (cat 3 (en:json:html json) '\0a\0a')))
::
++  send-sse-start
  |=  eyre-id=@ta
  ^-  (list card:agent:gall)
  =/  =response-header:http
    :-  200
    :~  ['content-type' 'text/event-stream']
        ['cache-control' 'no-cache']
        ['connection' 'keep-alive']
        ['MCP-Protocol-Version' mcp-protocol-version]
    ==
  :~  :*  %give  %fact  ~[/http-response/[eyre-id]]
          [%http-response-header !>(response-header)]
      ==
      :*  %give  %fact  ~[/http-response/[eyre-id]]
          [%http-response-data !>(`(as-octt:mimes:html ":\0a\0a"))]
      ==
  ==
::
++  send-sse-json
  |=  [eyre-id=@ta =json]
  ^-  (list card:agent:gall)
  :~  :*  %give  %fact  ~[/http-response/[eyre-id]]
          [%http-response-data !>(`(sse-data json))]
      ==
  ==
::
++  send-sse-ping
  |=  eyre-id=@ta
  ^-  (list card:agent:gall)
  :~  :*  %give  %fact  ~[/http-response/[eyre-id]]
          [%http-response-data !>(`(as-octt:mimes:html ":\0a\0a"))]
      ==
  ==
::
++  close-sse
  |=  eyre-id=@ta
  ^-  (list card:agent:gall)
  ~[[%give %kick ~[/http-response/[eyre-id]] ~]]
::
++  keepalive-interval  ~s20
::
++  set-keepalive
  |=  [now=@da eyre-id=@ta]
  ^-  card:agent:gall
  [%pass /keepalive/[eyre-id] %arvo %b %wait (add now keepalive-interval)]
::
++  list-changed-notification
  |=  method=@t
  ^-  json
  %-  pairs:enjs:format
  :~  ['jsonrpc' s+'2.0']
      ['method' s+method]
  ==
::
++  broadcast-list-changed
  |=  [=bowl:gall sse-sessions=(map @ta session:mcp) method=@t]
  ^-  (list card:agent:gall)
  =/  notification=json  (list-changed-notification method)
  %-  zing
  %+  murn
    ~(tap by sse-sessions)
  |=  [eyre-id=@ta session:mcp]
  ^-  (unit (list card:agent:gall))
  =/  live=?
    %+  lien
      ~(tap by sup.bowl)
    |=  [=duct =ship pat=path]
    =(pat /http-response/[eyre-id])
  ?.  live
    ~
  `(send-sse-json eyre-id notification)
::
++  json-response
  |=  [eyre-id=@ta status=@ud =json]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server
    eyre-id
  ^-  simple-payload:http
  :-  :-  status
      :~  ['content-type' 'application/json']
          ['cache-control' 'no-cache']
          ['MCP-Protocol-Version' mcp-protocol-version]
      ==
  %-  some
  %-  as-octt:mimes:html
  (trip (en:json:html json))
::
::  Clients probe these endpoints before selecting the API-key flow.
++  discovery
  |=  [eyre-id=@ta host=@t url-tape=tape]
  ^-  (unit (list card:agent:gall))
  =/  base=@t  (rap 3 'http://' host ~)
  ::  RFC 9728 protected-resource metadata at the spec'd path.
  ::  Empty authorization_servers + bearer_methods=header tells
  ::  the client to use the auth header it already has.
  ::
  ?:  =("/.well-known/oauth-protected-resource" url-tape)
    =/  meta=json
      %-  pairs:enjs:format
      :~  ['resource' s+(cat 3 base '/mcp')]
          ['authorization_servers' a+~]
          ['bearer_methods_supported' a+~[s+'header']]
      ==
    %-  some
    (json-response eyre-id 200 meta)
  ::  RFC 8414 authorization-server metadata. We don't actually
  ::  speak OAuth, but a Zod-valid stub keeps the client out of
  ::  parse-error territory; the OAuth flow itself fails cleanly
  ::  at the /oauth/* endpoints below.
  ::
  ?:  =("/.well-known/oauth-authorization-server" url-tape)
    =/  meta=json
      %-  pairs:enjs:format
      :~  ['issuer' s+base]
          ['authorization_endpoint' s+(cat 3 base '/oauth/authorize')]
          ['token_endpoint' s+(cat 3 base '/oauth/token')]
          ['registration_endpoint' s+(cat 3 base '/oauth/register')]
          ['response_types_supported' a+~[s+'code']]
          ['grant_types_supported' a+~[s+'authorization_code']]
          ['code_challenge_methods_supported' a+~[s+'S256']]
          ['token_endpoint_auth_methods_supported' a+~[s+'none']]
      ==
    %-  some
    (json-response eyre-id 200 meta)
  ::  Any other /.well-known/* probe gets a JSON 404.
  ::
  ?:  ?&  (gte (lent url-tape) 12)
          =("/.well-known" (scag 12 url-tape))
      ==
    %-  some
    (json-response eyre-id 404 (pairs:enjs:format ~[['error' s+'not found']]))
  ~
--
