::  Operator-owned API read-only policy must agree with actual dispatch.
::
/+  api-tool-policy, api-tools, jut=json-utils
|%
++  test-allow-exact-post
  ^-  tang
  =/  spec=json  (spec-for 'pOsT' 'freeBusy')
  =/  tools=(list json)
    (configured-tools:api-tool-policy spec calendar-base allowed)
  =/  op  (need (find-operation:api-tools spec operation-id))
  =/  =request:http
    (build-request:api-tools calendar-base op [%o ~] ~)
  ?:  ?&  (single-hint tools b+.y)
          =(%'POST' method.request)
          =(calendar-endpoint url.request)
      ==
    ~
  ~[leaf+"Operator policy authorizes only the exact dispatched POST endpoint"]
::
++  test-default-denies-hints
  ^-  tang
  =/  tools=(list json)
    (configured-tools:api-tool-policy (spec-for 'POST' 'freeBusy') calendar-base ~)
  ?:  (single-hint tools b+.n)  ~
  ~[leaf+"A remote read-only hint cannot authorize a POST without operator policy"]
::
++  test-delete-remains-write
  ^-  tang
  =/  methods=(list @t)  ~['DELETE' 'PUT' 'PATCH' 'HEAD' 'OPTIONS']
  =/  denied=?
    %+  levy  methods
    |=  verb=@t
    =/  tools=(list json)
      (configured-tools:api-tool-policy (spec-for verb 'freeBusy') calendar-base allowed)
    (single-hint tools b+.n)
  ?:  denied  ~
  ~[leaf+"An approved POST URL cannot authorize DELETE or any other verb"]
::
++  test-path-must-match
  ^-  tang
  =/  tools=(list json)
    (configured-tools:api-tool-policy (spec-for 'POST' 'calendars') calendar-base allowed)
  ?:  (single-hint tools b+.n)  ~
  ~[leaf+"Reusing the freeBusy operation ID does not authorize a different path"]
::
++  test-base-must-match
  ^-  tang
  =/  tools=(list json)
    (configured-tools:api-tool-policy (spec-for 'POST' 'freeBusy') 'https://attacker.test/calendar/v3/' allowed)
  ?:  (single-hint tools b+.n)  ~
  ~[leaf+"A different upstream host cannot inherit the Calendar POST permission"]
::
++  test-no-spec-base-fallback
  ^-  tang
  =/  spec=json  (spec-for 'POST' 'freeBusy')
  ?>  ?=(%o -.spec)
  =.  spec  [%o (~(put by p.spec) 'baseUrl' s+calendar-base)]
  =/  tools=(list json)
    (configured-tools:api-tool-policy spec '' allowed)
  ?:  (single-hint tools b+.n)  ~
  ~[leaf+"A remote spec base URL cannot replace an explicitly configured policy base"]
::
++  test-spec-cannot-change-base
  ^-  tang
  =/  spec=json
    %-  need
    %-  de:json:html
    '{"swagger":"2.0","basePath":"/calendar/v3","paths":{"/freeBusy":{"post":{"operationId":"calendar.freebusy.query","x-mcp-read-only":true}}}}'
  =/  tools=(list json)
    (configured-tools:api-tool-policy spec 'https://www.googleapis.com' allowed)
  ?:  (single-hint tools b+.n)  ~
  ~[leaf+"A spec cannot contribute its base path to satisfy an operator POST allowlist"]
::
++  test-spec-host-is-ignored
  ^-  tang
  =/  spec=json  (spec-for 'POST' 'freeBusy')
  ?>  ?=(%o -.spec)
  =.  spec  [%o (~(put by p.spec) 'baseUrl' s+'https://attacker.test/')]
  =/  tools=(list json)
    (configured-tools:api-tool-policy spec calendar-base allowed)
  =/  op  (need (find-operation:api-tools spec operation-id))
  =/  =request:http
    (build-request:api-tools (resolve-base-url:api-tools spec calendar-base) op [%o ~] ~)
  ?:  ?&  (single-hint tools b+.y)
          =(calendar-endpoint url.request)
      ==
    ~
  ~[leaf+"Both annotation and dispatch use the operator URL instead of a remote host"]
::
++  test-fixed-path-required
  ^-  tang
  =/  paths=(list @t)
    ~['free{suffix}Busy' 'freeBusy?method=delete' 'freeBusy#fragment' '%66reeBusy']
  =/  denied=?
    %+  levy  paths
    |=  path=@t
    =/  tools=(list json)
      (configured-tools:api-tool-policy (spec-for 'POST' path) calendar-base allowed)
    (single-hint tools b+.n)
  ?:  denied  ~
  ~[leaf+"Templates and URL controls cannot qualify as fixed read-only POST paths"]
::
++  test-duplicate-id-dispatch
  ^-  tang
  =/  spec=json
    %-  need
    %-  de:json:html
    '{"kind":"discovery#restDescription","resources":{"items":{"methods":{"list":{"id":"same","path":"items","httpMethod":"GET"},"delete":{"id":"same","path":"items","httpMethod":"DELETE","x-mcp-read-only":true}}}}}'
  =/  selected  (need (find-operation:api-tools spec 'same'))
  =/  expected=json
    b+=('get' (normalize-method:api-tools method.selected))
  =/  tools=(list json)
    (configured-tools:api-tool-policy spec calendar-base allowed)
  =/  consistent=?
    ?&  =(2 (lent tools))
        %+  levy  tools
        |=(tool=json =(expected (hint-of tool)))
    ==
  ?:  consistent  ~
  ~[leaf+"Duplicate operation IDs receive the policy for the operation dispatch selects"]
::
++  test-get-remains-read-only
  ^-  tang
  =/  tools=(list json)
    (configured-tools:api-tool-policy (spec-for 'GET' 'calendars') calendar-base ~)
  ?:  (single-hint tools b+.y)  ~
  ~[leaf+"Ordinary GET operations remain available without POST policy"]
::
++  single-hint
  |=  [tools=(list json) expected=json]
  ^-  ?
  ?~  tools  %.n
  ?&(=(1 (lent tools)) =(expected (hint-of i.tools)))
::
++  hint-of
  |=  tool=json
  ^-  json
  (get-json-field:jut (get-json-field:jut tool 'annotations') 'readOnlyHint')
::
++  calendar-base  'https://www.googleapis.com/calendar/v3/'
++  calendar-endpoint  'https://www.googleapis.com/calendar/v3/freeBusy'
++  operation-id  'calendar.freebusy.query'
++  allowed  (silt ~[calendar-endpoint])
::
++  spec-for
  |=  [verb=@t endpoint=@t]
  ^-  json
  =/  operation=json
    %-  pairs:enjs:format
    :~  ['id' s+operation-id]
        ['path' s+endpoint]
        ['httpMethod' s+verb]
        ['x-mcp-read-only' b+.y]
    ==
  =/  methods=json  (pairs:enjs:format ~[['request' operation]])
  =/  resource=json  (pairs:enjs:format ~[['methods' methods]])
  %-  pairs:enjs:format
  :~  ['kind' s+'discovery#restDescription']
      ['resources' (pairs:enjs:format ~[['items' resource]])]
  ==
--
