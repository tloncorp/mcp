/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/add-mcp-template'
    '''
    Add a new MCP Resource Template to the %mcp-server agent state.
    '''
    %-  my
    :~  ['uri-template' [%string 'The URI template of your MCP resource template.']]
        ['name' [%string 'The name of your MCP resource template.']]
        ['title' [%string 'The display title of your MCP resource template (optional).']]
        ['desc' [%string 'The description of your MCP resource template (optional).']]
        ['mime-type' [%string 'The MIME type of your MCP resource template (optional).']]
        ['size' [%number 'The size of your MCP resource template in bytes (optional).']]
        ['audience' [%array 'The audience list for your MCP resource template (optional).']]
    ==
    ~['uri-template' 'name']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  uri=(unit argument:tool:mcp)   (~(get by args) 'uri-template')
    =/  nam=(unit argument:tool:mcp)   (~(get by args) 'name')
    =/  tit=(unit argument:tool:mcp)   (~(get by args) 'title')
    =/  des=(unit argument:tool:mcp)   (~(get by args) 'desc')
    =/  mime=(unit argument:tool:mcp)  (~(get by args) 'mime-type')
    =/  siz=(unit argument:tool:mcp)   (~(get by args) 'size')
    =/  aud=(unit argument:tool:mcp)   (~(get by args) 'audience')
    ?~  uri  (pure:m !>([%error %missing-resource-template-uri ~]))
    ?>  ?=([%string @t] u.uri)
    ?~  nam  (pure:m !>([%error %missing-resource-template-name ~]))
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
      :*  %pass   /add-template
          %agent  [our %mcp-server]
          %poke   %add-template
          !>([p.u.uri p.u.nam title desc mime-type size annotations])
      ==
    ;<  ~  bind:m  (take-poke-ack:io /add-template)
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %unstructured
    :~  [%text 'Resource template added!']
    ==
==
