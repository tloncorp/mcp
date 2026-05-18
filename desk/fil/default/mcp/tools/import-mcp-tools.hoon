/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'import-mcp-tools'
    'Import MCP Tools from a desk.'
    %-  my
    :~  ['desk' [%string 'Desk to import MCP Tools from.']]
    ==
    ~['desk']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  dek=(unit argument:tool:mcp)  (~(get by args) 'desk')
    ?~  dek  ~|(%missing-desk !!)
    ?>  ?=([%string *] u.dek)
    ;<    =bowl:rand
        bind:m
      get-bowl:io
    =/  tools=(list tool:mcp)
      %-  zing
      %+  murn
        %~  tap  in
        .^  (set [dude:gall ?])
            %ge
            /(scot %p our.bowl)/[p.u.dek]/(scot %da now.bowl)/$
        ==
      |=  [=dude:gall live=?]
      ^-  (unit (list tool:mcp))
      ?.  live
        ~
      =/  mule-result=(each * (list tank))
        %-  mule
        |.
        .^  (list tool:mcp)
            %gx
            /(scot %p our.bowl)/[dude]/(scot %da now.bowl)/mcp/tools/noun
        ==
      ?.  -.mule-result
        ~
      =/  tool-list  ;;((list tool:mcp) p.mule-result)
      ?~  tool-list
        ~
      `tool-list
    ?~  tools
      %-  pure:m
      !>  ^-  json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          ['text' s+(crip "No MCP Tools found in {(trip p.u.dek)}")]
      ==
    ;<  ~  bind:m
      %-  send-raw-cards:io
      %+  turn
        tools
      |=  =tool:mcp
      ^-  card:agent:gall
      :*  %pass   ~
          %agent  [our.bowl %mcp-server]
          %poke   %add-tool  !>(tool)
      ==
    =/  tool-names
      %+  turn
        tools
      |=  =tool:mcp
      name.tool
    %-  pure:m
    !>  ^-  json
    %-  pairs:enjs:format
    :~  ['type' s+'text']
        ['text' s+(crip "Imported MCP Tools into %mcp-server: {<(of-wain:format tool-names)>}")]
    ==
==
