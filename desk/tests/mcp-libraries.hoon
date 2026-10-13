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
  =/  busy=json  (method-annotations:api-tools 'POST')
  ?:  ?&  =(b+.y (get-json-field:jut read 'readOnlyHint'))
          =(b+.n (get-json-field:jut write 'readOnlyHint'))
          =(b+.n (get-json-field:jut busy 'readOnlyHint'))
      ==
    ~
  ~[leaf+"Only GETs are read-only without an operator-approved POST endpoint"]
::
++  test-spec-cannot-authorize-write
  ^-  tang
  =/  specs=(list @t)
    :~  '{"paths":{"/items":{"delete":{"operationId":"deleteItem","x-mcp-read-only":true},"post":{"operationId":"createItem","x-mcp-read-only":true}}}}'
        '{"kind":"discovery#restDescription","resources":{"items":{"methods":{"delete":{"id":"deleteItem","path":"items","httpMethod":"DELETE","x-mcp-read-only":true},"create":{"id":"createItem","path":"items","httpMethod":"POST","x-mcp-read-only":true}}}}}'
    ==
  =/  safe=?
    %+  levy  specs
    |=  source=@t
    =/  tools=(list json)  (spec-to-tools:api-tools (need (de:json:html source)))
    ?&  =(2 (lent tools))
        %+  levy  tools
        |=  tool=json
        =(b+.n (get-json-field:jut (get-json-field:jut tool 'annotations') 'readOnlyHint'))
    ==
  ?:  safe  ~
  ~[leaf+"Neither OpenAPI nor Discovery can self-declare a write read-only"]
::
++  test-method-normalization
  ^-  tang
  =/  methods=(list [@t method:http])
    ~[['GET' %'GET'] ['pOsT' %'POST'] ['PUT' %'PUT'] ['PaTcH' %'PATCH'] ['DELETE' %'DELETE']]
  =/  consistent=?
    %+  levy  methods
    |=  [verb=@t expected=method:http]
    =/  =request:http  (build-request:api-tools 'https://example.test/' ['items' verb ~] [%o ~] ~)
    =/  hint=json  (method-annotations:api-tools verb)
    ?&  =(expected method.request)
        =(b+=(expected %'GET') (get-json-field:jut hint 'readOnlyHint'))
    ==
  ?:  consistent  ~
  ~[leaf+"Dispatch and annotations agree on mixed-case HTTP verbs"]
::
++  test-discovery-default-types
  ^-  tang
  =/  schema=json
    %-  need
    %-  de:json:html
    '{"type":"object","properties":{"limit":{"type":"integer","default":"250"},"flag":{"type":"boolean","default":"false"},"yes":{"type":"boolean","default":"true"},"ratio":{"type":"number","default":"1.5"},"negative":{"type":"integer","default":"-2"},"text":{"type":"string","default":"false"},"fraction":{"type":"integer","default":"1.5"},"invalid":{"type":"boolean","default":"no"},"typed":{"type":"boolean","default":false}}}'
  =/  normalized=json  (discovery-schema:api-tools [%o ~] schema 12)
  =/  fields=json  (get-json-field:jut normalized 'properties')
  ?:  ?&  =(n+'250' (get-json-field:jut (get-json-field:jut fields 'limit') 'default'))
          =(b+.n (get-json-field:jut (get-json-field:jut fields 'flag') 'default'))
          =(b+.y (get-json-field:jut (get-json-field:jut fields 'yes') 'default'))
          =(n+'1.5' (get-json-field:jut (get-json-field:jut fields 'ratio') 'default'))
          =(n+'-2' (get-json-field:jut (get-json-field:jut fields 'negative') 'default'))
          =(s+'false' (get-json-field:jut (get-json-field:jut fields 'text') 'default'))
          =(~ (get-json-field:jut (get-json-field:jut fields 'fraction') 'default'))
          =(~ (get-json-field:jut (get-json-field:jut fields 'invalid') 'default'))
          =(b+.n (get-json-field:jut (get-json-field:jut fields 'typed') 'default'))
      ==
    ~
  ~[leaf+"Discovery defaults have their declared type or are omitted"]
::
++  test-discovery-nested-required
  ^-  tang
  =/  schema=json
    %-  need
    %-  de:json:html
    '{"type":"object","required":["existing"],"properties":{"existing":{"type":"string","required":true},"optional":{"type":"string","required":false},"nested":{"type":"object","required":true,"properties":{"name":{"type":"string","required":true,"annotations":{"required":["example.insert"]}}}},"list":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string","required":true}}}},"map":{"type":"object","additionalProperties":{"type":"object","properties":{"id":{"type":"string","required":true}}}}}}'
  =/  normalized=json  (discovery-schema:api-tools [%o ~] schema 12)
  =/  fields=json  (get-json-field:jut normalized 'properties')
  =/  nested=json  (get-json-field:jut fields 'nested')
  =/  name=json  (get-json-field:jut (get-json-field:jut nested 'properties') 'name')
  =/  items=json  (get-json-field:jut (get-json-field:jut fields 'list') 'items')
  =/  extra=json  (get-json-field:jut (get-json-field:jut fields 'map') 'additionalProperties')
  ?:  ?&  =(~[s+'existing' s+'nested'] (get-json-array:jut normalized 'required'))
          =(~[s+'name'] (get-json-array:jut nested 'required'))
          =(~[s+'id'] (get-json-array:jut items 'required'))
          =(~[s+'id'] (get-json-array:jut extra 'required'))
          =(~ (get-json-field:jut (get-json-field:jut fields 'existing') 'required'))
          =(~ (get-json-field:jut (get-json-field:jut fields 'optional') 'required'))
          =(~ (get-json-field:jut name 'required'))
          =(~ (get-json-field:jut name 'annotations'))
      ==
    ~
  ~[leaf+"Boolean required flags become parent arrays at every object level"]
::
++  test-discovery-parameter-metadata
  ^-  tang
  =/  spec=json
    %-  need
    %-  de:json:html
    '{"kind":"discovery#restDescription","schemas":{"Object":{"type":"object"}},"resources":{"items":{"methods":{"list":{"id":"items.list","httpMethod":"GET","parameters":{"q":{"description":"Search"},"tags":{"type":"string","repeated":true,"description":"Filter tags","enum":["a","b"]},"any":{"type":"any"},"object":{"$ref":"Object"}}}}}}}'
  =/  tool=json  (tool-named (spec-to-tools:api-tools spec) 'items.list')
  =/  fields=json  (get-json-field:jut (get-json-field:jut tool 'inputSchema') 'properties')
  =/  tags=json  (get-json-field:jut fields 'tags')
  =/  items=json  (get-json-field:jut tags 'items')
  ?:  ?&  =('string' (get-json-string:jut (get-json-field:jut fields 'q') 'type'))
          =('array' (get-json-string:jut tags 'type'))
          =('Filter tags' (get-json-string:jut tags 'description'))
          =('string' (get-json-string:jut items 'type'))
          =(~[s+'a' s+'b'] (get-json-array:jut items 'enum'))
          =(~ (get-json-field:jut items 'description'))
          =(~ (get-json-field:jut (get-json-field:jut fields 'any') 'type'))
          =('object' (get-json-string:jut (get-json-field:jut fields 'object') 'type'))
      ==
    ~
  ~[leaf+"Parameter fallbacks preserve any/objects and arrays retain their descriptions"]
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
