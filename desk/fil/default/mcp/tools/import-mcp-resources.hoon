/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'urbit/mcp/import-mcp-resources'
    'Import MCP Resources from a desk.'
    %-  my
    :~  ['desk' [%string 'Desk to import MCP Resources from.']]
    ==
    ~['desk']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  dek=(unit argument:tool:mcp)  (~(get by args) 'desk')
    ?~  dek
      (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string *] u.dek)
    ;<  =bowl:rand  bind:m  get-bowl:io
    ;<  ~  bind:m
      %-  send-raw-card:io
      :*  %pass   ~
          %agent  [our.bowl %mcp-server]
          %poke   %import-resources  !>(p.u.dek)
      ==
    ;<  ~  bind:m  (take-poke-ack:io ~)
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %unstructured
    :~  [%text (crip "Poked %mcp-server to import resources from %{(trip p.u.dek)}")]
    ==
==
