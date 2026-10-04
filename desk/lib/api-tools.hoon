::  api-tools: MCP tools and HTTP requests from OpenAPI and Discovery schemas
::
/+  jut=json-utils, url-utils
|%
++  http-methods  (silt ~['get' 'post' 'put' 'patch' 'delete'])
::
++  spec-to-tools
  |=  spec=json
  ^-  (list json)
  ::  detect format: Google Discovery vs OpenAPI
  =/  kind=@t  (get-json-string:jut spec 'kind')
  ?:  =(kind 'discovery#restDescription')
    (discovery-to-tools spec)
  (openapi-to-tools spec)
::
++  discovery-to-tools
  |=  spec=json
  ^-  (list json)
  =/  resources=json  (get-json-field:jut spec 'resources')
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
  =/  methods=json  (get-json-field:jut robj 'methods')
  =/  method-tools=(list json)
    ?~  methods  ~
    ?.  ?=(%o -.methods)  ~
    %+  murn  ~(tap by p.methods)
    |=  [mname=@t mobj=json]
    ^-  (unit json)
    ?~  mobj  ~
    ?.  ?=(%o -.mobj)  ~
    =/  op-id=@t  (get-json-string:jut mobj 'id')
    ?:  =('' op-id)  ~
    =/  desc=@t  (get-json-string:jut mobj 'description')
    =/  params-obj=json  (get-json-field:jut mobj 'parameters')
    =/  props=(map @t json)  ~
    =/  reqs=(list json)  ~
    =?  props  &(?=(^ params-obj) ?=(%o -.params-obj))
      %-  ~(gas by props)
      %+  murn  ~(tap by p.params-obj)
      |=  [pname=@t pobj=json]
      ^-  (unit [@t json])
      ?~  pobj  ~
      ?.  ?=(%o -.pobj)  ~
      =/  ptype=@t  (get-json-string:jut pobj 'type')
      =/  pdesc=@t  (get-json-string:jut pobj 'description')
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
  =/  sub-resources=json  (get-json-field:jut robj 'resources')
  =/  sub-tools=(list json)
    ?~  sub-resources  ~
    ?.  ?=(%o -.sub-resources)  ~
    (walk-discovery-resources sub-resources)
  (weld method-tools sub-tools)
::
++  openapi-to-tools
  |=  spec=json
  ^-  (list json)
  =/  paths=json  (get-json-field:jut spec 'paths')
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
    =/  op-id=@t  (get-json-string:jut op 'operationId')
    ?:  =('' op-id)  $(ml t.ml)
    =/  desc=@t  (get-json-string:jut op 'summary')
    =?  desc  =('' desc)  (get-json-string:jut op 'description')
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
++  find-operation
  |=  [spec=json op-id=@t]
  ^-  (unit [path=@t method=@t operation=json])
  =/  kind=@t  (get-json-string:jut spec 'kind')
  ?:  =(kind 'discovery#restDescription')
    (find-discovery-operation spec op-id)
  =/  paths=json  (get-json-field:jut spec 'paths')
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
    =/  this-id=@t  (get-json-string:jut op 'operationId')
    ?:  =(this-id op-id)  `[path-str m op]
    $(ml t.ml)
  ?^  found  found
  $(items t.items)
::
++  find-discovery-operation
  |=  [spec=json op-id=@t]
  ^-  (unit [path=@t method=@t operation=json])
  =/  resources=json  (get-json-field:jut spec 'resources')
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
  =/  methods=json  (get-json-field:jut robj 'methods')
  =/  found=(unit [path=@t method=@t operation=json])
    ?~  methods  ~
    ?.  ?=(%o -.methods)  ~
    =/  ml=(list [@t json])  ~(tap by p.methods)
    |-
    ?~  ml  ~
    =/  [mname=@t mobj=json]  i.ml
    ?~  mobj  $(ml t.ml)
    ?.  ?=(%o -.mobj)  $(ml t.ml)
    =/  mid=@t  (get-json-string:jut mobj 'id')
    ?.  =(mid op-id)  $(ml t.ml)
    =/  http-method=@t  (get-json-string:jut mobj 'httpMethod')
    =/  mpath=@t
      =/  fp=@t  (get-json-string:jut mobj 'flatPath')
      ?:(=('' fp) (get-json-string:jut mobj 'path') fp)
    `[mpath http-method mobj]
  ?^  found  found
  ::  recurse sub-resources
  =/  sub=json  (get-json-field:jut robj 'resources')
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
  =/  param-val=@t  (get-json-string:jut args param-name)
  =/  val-tape=tape  (trip (percent-encode:url-utils param-val))
  $(result (weld result val-tape), i (add i (add 2 u.close)))
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
    =/  pin=@t  (get-json-string:jut param 'in')
    ?.  =(pin 'query')  ~
    =/  pname=@t  (get-json-string:jut param 'name')
    =/  val=(unit json)  (~(get by p.args) pname)
    ?~  val  ~
    =/  v=@t  (json-query-value u.val)
    ?:  =('' v)  ~
    =/  part=@t
      %+  rap  3
      :~  (percent-encode:url-utils pname)  '='  (percent-encode:url-utils v)
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
  =/  kind=@t  (get-json-string:jut spec 'kind')
  ?:  =(kind 'discovery#restDescription')
    ::  Google Discovery: use baseUrl or rootUrl
    =/  base=@t  (get-json-string:jut spec 'baseUrl')
    ?:(=('' base) (get-json-string:jut spec 'rootUrl') base)
  ::  Swagger 2.0: compose scheme+host+basePath when available;
  ::  fall back to just basePath (a path the caller will append to
  ::  the operator-supplied upstream URL).
  ::
  =/  swagger-version=@t  (get-json-string:jut spec 'swagger')
  ?:  !=('' swagger-version)
    =/  base-path=@t  (get-json-string:jut spec 'basePath')
    =/  host=@t  (get-json-string:jut spec 'host')
    ?:  =('' host)  base-path
    =/  schemes=json  (get-json-field:jut spec 'schemes')
    =/  scheme=@t
      ?.  ?=(%a -.schemes)  'https'
      ?~  p.schemes  'https'
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
  =/  servers=json  (get-json-field:jut spec 'servers')
  ?.  ?=(%a -.servers)  ''
  ?~  p.servers  ''
  (get-json-string:jut i.p.servers 'url')
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
      :~  (percent-encode:url-utils key)  '='  (percent-encode:url-utils v)
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
      (get-json-array:jut path-item 'parameters')
    (get-json-array:jut op 'parameters')
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
  =?  reqs  &(?=(^ body-prop) (request-body-required spec op))
    (snoc reqs s+'body')
  %-  pairs:enjs:format
  :~  ['type' s+'object']
      ['properties' [%o props]]
      ['required' a+reqs]
  ==
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
  =/  ref=@t  (get-json-string:jut jon '$ref')
  ?:  =('' ref)  jon
  =/  target=(unit json)  (json-pointer-get:jut spec ref)
  ?~  target  jon
  (resolve-openapi-ref-depth spec u.target (sub depth 1))
::
++  parameter-property
  |=  [spec=json param=json]
  ^-  (unit [@t json])
  =/  param=json  (resolve-openapi-ref spec param)
  ?~  param  ~
  ?.  ?=(%o -.param)  ~
  =/  pin=@t  (get-json-string:jut param 'in')
  ?.  |(=(pin 'path') =(pin 'query'))  ~
  =/  pname=@t  (get-json-string:jut param 'name')
  ?:  =('' pname)  ~
  =/  desc=@t  (get-json-string:jut param 'description')
  =/  schema=json  (get-json-field:jut param 'schema')
  =/  typ=@t  (get-json-string:jut param 'type')
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
  =/  pin=@t  (get-json-string:jut param 'in')
  ?.  |(=(pin 'path') =(pin 'query'))  ~
  =/  pname=@t  (get-json-string:jut param 'name')
  ?:  =('' pname)  ~
  ?:  =(pin 'path')  `s+pname
  =/  req=json  (get-json-field:jut param 'required')
  ?~  req  ~
  ?.  ?=(%b -.req)  ~
  ?.  p.req  ~
  `s+pname
::
++  request-body-property
  |=  [spec=json op=json]
  ^-  (unit [name=@t prop=json])
  =/  body=json  (resolve-openapi-ref spec (get-json-field:jut op 'requestBody'))
  ?~  body  ~
  ?.  ?=(%o -.body)  ~
  =/  desc=@t  (get-json-string:jut body 'description')
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
  =/  body=json  (resolve-openapi-ref spec (get-json-field:jut op 'requestBody'))
  ?~  body  %.n
  ?.  ?=(%o -.body)  %.n
  =/  req=json  (get-json-field:jut body 'required')
  ?~  req  %.n
  ?.  ?=(%b -.req)  %.n
  p.req
::
++  request-body-schema
  |=  [spec=json body=json]
  ^-  json
  ?~  body  ~
  ?.  ?=(%o -.body)  ~
  =/  content=json  (get-json-field:jut body 'content')
  ?~  content  ~
  ?.  ?=(%o -.content)  ~
  =/  media=(unit json)  (~(get by p.content) 'application/json')
  ?~  media  ~
  (resolve-openapi-ref spec (get-json-field:jut u.media 'schema'))
::
++  schema-with-description
  |=  [spec=json schema=json desc=@t]
  ^-  json
  =/  schema=json  (resolve-openapi-ref spec schema)
  ?~  schema  ~
  ?.  ?=(%o -.schema)  schema
  =/  prop=(map @t json)  p.schema
  =?  prop  &(!=('' desc) !(~(has by prop) 'description'))
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
++  resolve-base-url
  |=  [spec=json override=@t]
  ^-  @t
  =/  spec-base=@t  (get-spec-base-url spec)
  ::  if the spec only declares a relative path (Swagger 2.0
  ::  basePath without a host), append it to the operator's
  ::  upstream URL. Otherwise prefer the operator override; fall
  ::  back to the spec's full URL.
  ::
  =/  spec-base-t=tape  (trip spec-base)
  =/  spec-is-relative=?
    ?~  spec-base-t  %.n
    =('/' i.spec-base-t)
  ?:  &(!=('' override) spec-is-relative)
    =/  override-t=tape  (trip override)
    =?  override-t  &(!=(~ override-t) =('/' (rear override-t)))
      (snip override-t)
    (cat 3 (crip override-t) spec-base)
  ?:  !=('' override)  override
  spec-base
::
++  build-request
  |=  $:  base-url=@t
          op=[path=@t method=@t operation=json]
          args=json
          out-headers=(list [key=@t value=@t])
      ==
  ^-  request:http
  =/  path-params=(set @t)  (extract-path-params path.op)
  =/  api-url=@t
    =/  base-with-path=@t  (build-api-url base-url path.op args)
    =/  excluded=(set @t)  (~(put in path-params) 'body')
    =/  qs=@t  (build-all-args-query args excluded)
    (cat 3 base-with-path qs)
  ::  build body for POST/PUT/PATCH
  =/  req-method=method:http
    ?+  method.op  %'GET'
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
  [req-method api-url out-headers body]
--
