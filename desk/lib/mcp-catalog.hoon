::  mcp-catalog: discovery tool schemas and keyword search
::
|%
++  meta-tools
  ^-  (list json)
  ~[list-upstreams-tool search-tool describe-tool call-tool]
::
++  list-upstreams-tool
  ^-  json
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
::
++  search-tool
  ^-  json
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
::
++  describe-tool
  ^-  json
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
::
++  call-tool
  ^-  json
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
                  ['additionalProperties' b+%.y]
              ==
          ==
          ['required' a+~[s+'name' s+'arguments']]
      ==
  ==
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
++  tool-description
  |=  tool=json
  ^-  @t
  ?.  ?=(%o -.tool)  ''
  =/  v=(unit json)  (~(get by p.tool) 'description')
  ?~  v  ''
  ?.  ?=(%s -.u.v)  ''
  p.u.v
::
++  contains-ci
  |=  [haystack=@t needle=@t]
  ^-  ?
  ?:  =('' needle)  %.y
  =/  h=tape  (cass (trip haystack))
  =/  n=tape  (cass (trip needle))
  !=(~ (find n h))
::
++  search-tokens
  |=  raw=@t
  ^-  (list @t)
  =/  t=tape  (trim-spaces (trip raw))
  |-
  ?:  =(0 (lent t))  ~
  =/  sep=(unit @ud)  (find " " t)
  =/  head=tape
    ?~  sep  t
    (scag u.sep t)
  =/  rest=tape
    ?~  sep  ""
    (trim-spaces (slag +(u.sep) t))
  =/  token=@t  (crip head)
  ?:  =('' token)
    $(t rest)
  [token $(t rest)]
::
++  matches-search
  |=  [name=@t desc=@t keywords=@t]
  ^-  ?
  =/  tokens=(list @t)  (search-tokens keywords)
  |-
  ?~  tokens  %.y
  ?:  ?|  (contains-ci name i.tokens)
          (contains-ci desc i.tokens)
      ==
    $(tokens t.tokens)
  %.n
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
--
