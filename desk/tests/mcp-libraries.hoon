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
