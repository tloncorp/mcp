::  behavior checks for shared MCP and API helpers
::
/-  mcp, oauth
/+  api-tools, http-utils, mcp-json, oauth-client, oauth-json, url-utils
/+  jut=json-utils
|%
++  test-api-key
  ^-  tang
  =/  headers=(list [@t @t])
    ~[['host' 'localhost'] ['X-API-KEY' 'secret']]
  ?:  =(`'secret' (api-key:http-utils headers))  ~
  ~[leaf+"API keys accept mixed-case header names"]
::
++  test-url-encoding
  ^-  tang
  ?:  =('a%20b%2Fc%3F%26' (percent-encode:url-utils 'a b/c?&'))  ~
  ~[leaf+"URL parameters escape reserved bytes"]
::
++  test-api-request
  ^-  tang
  =/  args=json  (need (de:json:html '{"id":"a/b","q":"two words"}'))
  =/  =request:http
    (build-request:api-tools 'https://example.test/' ['/items/{id}' 'get' ~] args ~)
  ?:  &(=(%'GET' method.request) =('https://example.test/items/a%2Fb?q=two%20words' url.request))
    ~
  ~[leaf+"Path parameters are excluded from the query and escaped"]
::
++  test-api-body
  ^-  tang
  =/  args=json  (need (de:json:html '{"body":{"title":"hello"}}'))
  =/  =request:http
    (build-request:api-tools 'https://example.test' ['/items' 'post' ~] args ~)
  ?:  ?&  =(%'POST' method.request)
          =('https://example.test/items' url.request)
          =(`(as-octs:mimes:html '{"title":"hello"}') body.request)
          =(~[['content-type' 'application/json']] header-list.request)
      ==
    ~
  ~[leaf+"Body arguments become JSON payloads"]
::
++  test-openapi-tools
  ^-  tang
  =/  spec=json
    %-  need
    %-  de:json:html
    '{"paths":{"/items":{"get":{"operationId":"listItems","summary":"List items"}}}}'
  =/  tools=(list json)  (spec-to-tools:api-tools spec)
  ?~  tools  ~[leaf+"OpenAPI operations produce tools"]
  ?:  &(=(1 (lent tools)) =('listItems' (get-json-string:jut i.tools 'name')))
    ~
  ~[leaf+"OpenAPI operation IDs name the generated tools"]
::
++  test-discovery-tools
  ^-  tang
  =/  spec=json
    %-  need
    %-  de:json:html
    '{"kind":"discovery#restDescription","resources":{"items":{"methods":{"list":{"id":"items.list","path":"items","httpMethod":"GET"}}}}}'
  =/  tools=(list json)  (spec-to-tools:api-tools spec)
  ?~  tools  ~[leaf+"Discovery methods produce tools"]
  ?:  =('items.list' (get-json-string:jut i.tools 'name'))  ~
  ~[leaf+"Discovery IDs name the generated tools"]
::
++  test-calendar-event-schema
  ^-  tang
  =/  tools=(list json)  (spec-to-tools:api-tools calendar-spec)
  =/  tool=json  (tool-named tools 'calendar.events.insert')
  =/  input=json  (get-json-field:jut tool 'inputSchema')
  =/  props=json  (get-json-field:jut input 'properties')
  =/  body=json  (get-json-field:jut props 'body')
  =/  fields=json  (get-json-field:jut body 'properties')
  =/  start=json  (get-json-field:jut fields 'start')
  =/  dates=json  (get-json-field:jut start 'properties')
  =/  attendees=json  (get-json-field:jut fields 'attendees')
  =/  attendee=json  (get-json-field:jut attendees 'items')
  ?:  ?&  =('object' (get-json-string:jut body 'type'))
          =('string' (get-json-string:jut (get-json-field:jut dates 'dateTime') 'type'))
          =('object' (get-json-string:jut attendee 'type'))
          =('string' (get-json-string:jut (get-json-field:jut (get-json-field:jut attendee 'properties') 'email') 'type'))
          (lien (get-json-array:jut input 'required') |=(j=json =(s+'body' j)))
      ==
    ~
  ~[leaf+"Calendar creation exposes nested event times and attendee objects"]
::
++  test-calendar-query-schema
  ^-  tang
  =/  tools=(list json)  (spec-to-tools:api-tools calendar-spec)
  =/  tool=json  (tool-named tools 'calendar.events.list')
  =/  props=json  (get-json-field:jut (get-json-field:jut tool 'inputSchema') 'properties')
  =/  limit=json  (get-json-field:jut props 'maxResults')
  =/  kinds=json  (get-json-field:jut props 'eventTypes')
  ?:  ?&  =(n+'1' (get-json-field:jut limit 'minimum'))
          =('array' (get-json-string:jut kinds 'type'))
          =('string' (get-json-string:jut (get-json-field:jut kinds 'items') 'type'))
      ==
    ~
  ~[leaf+"Calendar query bounds are numeric and repeated parameters are arrays"]
::
++  test-calendar-write-request
  ^-  tang
  =/  args=json
    %-  need
    %-  de:json:html
    '{"calendarId":"primary","sendUpdates":"none","body":{"summary":"Meeting","start":{"dateTime":"2026-10-13T10:00:00-04:00","timeZone":"America/New_York"},"end":{"dateTime":"2026-10-13T10:30:00-04:00","timeZone":"America/New_York"}}}'
  =/  op  (need (find-operation:api-tools calendar-spec 'calendar.events.insert'))
  =/  =request:http  (build-request:api-tools 'https://www.googleapis.com/calendar/v3/' op args ~)
  ?~  body.request  ~[leaf+"Calendar POST carries an event body"]
  =/  sent=json  (need (de:json:html `@t`q.u.body.request))
  ?:  ?&  =(%'POST' method.request)
          =('https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=none' url.request)
          =((get-json-field:jut args 'body') sent)
      ==
    ~
  ~[leaf+"Discovery POST retains nested event JSON, the HTTP verb, and sendUpdates"]
::
++  test-calendar-patch-request
  ^-  tang
  =/  args=json  (need (de:json:html '{"calendarId":"a/b","eventId":"event","body":{"summary":"Changed"}}'))
  =/  op  (need (find-operation:api-tools calendar-spec 'calendar.events.patch'))
  =/  =request:http  (build-request:api-tools 'https://www.googleapis.com/calendar/v3/' op args ~)
  ?:  ?&  =(%'PATCH' method.request)
          =('https://www.googleapis.com/calendar/v3/calendars/a%2Fb/events/event' url.request)
          =(`(as-octs:mimes:html '{"summary":"Changed"}') body.request)
      ==
    ~
  ~[leaf+"Discovery PATCH edits the requested event and escapes calendar IDs"]
::
++  test-calendar-repeated-query
  ^-  tang
  =/  args=json  (need (de:json:html '{"calendarId":"primary","eventTypes":["default","outOfOffice"]}'))
  =/  op  (need (find-operation:api-tools calendar-spec 'calendar.events.list'))
  =/  =request:http  (build-request:api-tools 'https://www.googleapis.com/calendar/v3/' op args ~)
  ?:  =('https://www.googleapis.com/calendar/v3/calendars/primary/events?eventTypes=default&eventTypes=outOfOffice' url.request)
    ~
  ~[leaf+"Google repeated parameters become repeated query keys"]
::
++  test-calendar-read-only
  ^-  tang
  =/  tools=(list json)  (spec-to-tools:api-tools calendar-spec)
  =/  read=json  (get-json-field:jut (tool-named tools 'calendar.events.list') 'annotations')
  =/  write=json  (get-json-field:jut (tool-named tools 'calendar.events.insert') 'annotations')
  =/  busy=json  (method-annotations:api-tools 'POST' (need (de:json:html '{"x-mcp-read-only":true}')))
  =/  override=json  (method-annotations:api-tools 'GET' (need (de:json:html '{"x-mcp-read-only":false}')))
  ?:  ?&  =(b+.y (get-json-field:jut read 'readOnlyHint'))
          =(b+.n (get-json-field:jut write 'readOnlyHint'))
          =(b+.y (get-json-field:jut busy 'readOnlyHint'))
          =(b+.n (get-json-field:jut override 'readOnlyHint'))
      ==
    ~
  ~[leaf+"Scheduled reads distinguish Calendar GETs and freebusy from event writes"]
::
++  test-discovery-recursive-schema
  ^-  tang
  =/  spec=json  (need (de:json:html '{"schemas":{"Node":{"type":"object","properties":{"next":{"$ref":"Node"}}}}}'))
  =/  ref=json  (need (de:json:html '{"$ref":"Node"}'))
  =/  result=json  (discovery-schema:api-tools spec ref 2)
  =/  next=json  (get-json-field:jut (get-json-field:jut result 'properties') 'next')
  ?:  =([%o ~] next)  ~
  ~[leaf+"Recursive Discovery schemas stop at the expansion limit"]
::
++  tool-named
  |=  [tools=(list json) name=@t]
  ^-  json
  ?~  tools  [%o ~]
  ?:  =(name (get-json-string:jut i.tools 'name'))  i.tools
  $(tools t.tools)
::
++  calendar-spec
  ^-  json
  %-  need
  %-  de:json:html
  '''
  {"kind":"discovery#restDescription","resources":{"events":{"methods":{
    "list":{"id":"calendar.events.list","path":"calendars/{calendarId}/events","httpMethod":"GET","parameters":{"calendarId":{"type":"string","required":true},"maxResults":{"type":"integer","minimum":"1"},"eventTypes":{"type":"string","repeated":true}}},
    "insert":{"id":"calendar.events.insert","path":"calendars/{calendarId}/events","httpMethod":"POST","request":{"$ref":"Event"}},
    "patch":{"id":"calendar.events.patch","path":"calendars/{calendarId}/events/{eventId}","httpMethod":"PATCH","request":{"$ref":"Event"}}
  }}},"schemas":{
    "Event":{"type":"object","properties":{"start":{"$ref":"EventDateTime"},"end":{"$ref":"EventDateTime"},"attendees":{"type":"array","items":{"$ref":"Attendee"}}}},
    "EventDateTime":{"type":"object","properties":{"dateTime":{"type":"string"},"date":{"type":"string"},"timeZone":{"type":"string"}}},
    "Attendee":{"type":"object","properties":{"email":{"type":"string"}}}
  }}
  '''
::
++  test-pkce-challenge
  ^-  tang
  =/  verifier=@t  'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'
  =/  expected=@t  'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'
  ?:  =(expected (make-challenge:oauth-client verifier))  ~
  ~[leaf+"PKCE uses unpadded base64url SHA-256"]
::
++  test-provider-defaults
  ^-  tang
  =/  jon=json
    %-  need
    %-  de:json:html
    '{"id":"example","auth-url":"https://example.test/auth","token-url":"https://example.test/token","revoke-url":null,"client-id":"id","client-secret":"secret","redirect-uri":"https://ship.test/callback","scopes":"read"}'
  =/  parsed  (parse-provider-config:oauth-json jon)
  ?:  &(=(%basic token-auth.config.parsed) =(~ token-resource.config.parsed))  ~
  ~[leaf+"Provider defaults use Basic authentication without a resource"]
::
++  test-structured-result
  ^-  tang
  =/  result=json  (tool-result:mcp-json [%result %structured s+'hello'])
  =/  structured=json  (get-json-field:jut result 'structuredContent')
  ?:  ?&  =(s+'hello' (get-json-field:jut structured 'data'))
          =(b+.n (get-json-field:jut result 'isError'))
      ==
    ~
  ~[leaf+"Scalar structured results are wrapped in an object"]
::
++  test-error-result
  ^-  tang
  =/  result=json  (tool-result:mcp-json [%error 'failure' `s+'detail'])
  =/  structured=json  (get-json-field:jut result 'structuredContent')
  ?:  ?&  =(s+'detail' (get-json-field:jut structured 'data'))
          =(b+.y (get-json-field:jut result 'isError'))
      ==
    ~
  ~[leaf+"Error results retain their structured details"]
--
