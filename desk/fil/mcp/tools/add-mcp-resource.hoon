/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/add-mcp-resource'
    '''
    Add a new MCP Resource to the %mcp-server agent state.
    '''
    %-  my
    :~  ['uri' [%string 'The URI of your MCP resource.']]
        ['name' [%string 'The name of your MCP resource.']]
        ['title' [%string 'The display title of your MCP resource (optional).']]
        ['desc' [%string 'The description of your MCP resource (optional).']]
        ['mime-type' [%string 'The MIME type of your MCP resource (optional).']]
        ['size' [%number 'The size of your MCP resource in bytes (optional).']]
        ['audience' [%array 'The audience list for your MCP resource (optional).']]
    ==
    ~['uri' 'name']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  uri=(unit argument:tool:mcp)   (~(get by args) 'uri')
    =/  nam=(unit argument:tool:mcp)   (~(get by args) 'name')
    =/  tit=(unit argument:tool:mcp)   (~(get by args) 'title')
    =/  des=(unit argument:tool:mcp)   (~(get by args) 'desc')
    =/  mime=(unit argument:tool:mcp)  (~(get by args) 'mime-type')
    =/  siz=(unit argument:tool:mcp)   (~(get by args) 'size')
    =/  aud=(unit argument:tool:mcp)   (~(get by args) 'audience')
    ?~  uri  (pure:m !>([%error %missing-resource-uri ~]))
    ?>  ?=([%string @t] u.uri)
    ?~  nam  (pure:m !>([%error %missing-resource-name ~]))
    ?>  ?=([%string @t] u.nam)
    =/  title=(unit @t)
      ?~  tit
        ~
      ?>  ?=([%string @t] u.tit)
      `p.u.tit
    =/  desc=(unit @t)
      ?~  des
        ~
      ?>  ?=([%string @t] u.des)
      `p.u.des
    =/  mime-type=(unit @t)
      ?~  mime
        ~
      ?>  ?=([%string @t] u.mime)
      `p.u.mime
    =/  size=(unit @ud)
      ?~  siz
        ~
      ?>  ?=([%number @ud] u.siz)
      `p.u.siz
    =/  audience=(list @t)
      ?~  aud
        ~
      ?>  ?=([%array *] u.aud)
      %+  turn  p.u.aud
      |=  =argument:tool:mcp
      ?>  ?=([%string @t] argument)
      p.argument
    =/  annotations=(unit annotations:resource:mcp)
      ?:  =(~ audience)
        ~
      `[audience ~ ~]
    ::
    ;<  our=ship  bind:m  get-our:io
    ;<  ~  bind:m
      %-  send-raw-card:io
      :*  %pass   /add-resource
          %agent  [our %mcp-server]
          %poke   %add-resource
          !>([p.u.uri p.u.nam title desc mime-type size annotations])
      ==
    ;<  ~  bind:m  (take-poke-ack:io /add-resource)
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %unstructured
    :~  [%text 'Resource added!']
    ==
==
