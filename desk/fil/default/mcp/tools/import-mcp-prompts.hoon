/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'import-mcp-prompts'
    'Import MCP Prompts from a desk.'
    %-  my
    :~  ['desk' [%string 'Desk to import MCP Prompts from.']]
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
    =/  prompts=(list prompt:mcp)
      %-  zing
      %+  murn
        %~  tap  in
        .^  (set [dude:gall ?])
            %ge
            /(scot %p our.bowl)/[p.u.dek]/(scot %da now.bowl)/$
        ==
      |=  [=dude:gall live=?]
      ^-  (unit (list prompt:mcp))
      ?.  live
        ~
      =/  mule-result=(each * (list tank))
        %-  mule
        |.
        .^  (list prompt:mcp)
            %gx
            /(scot %p our.bowl)/[dude]/(scot %da now.bowl)/mcp/prompts/noun
        ==
      ?.  -.mule-result
        ~
      =/  prompt-list  ;;((list prompt:mcp) p.mule-result)
      ?~  prompt-list
        ~
      `prompt-list
    ?~  prompts
      %-  pure:m
      !>  ^-  json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          ['text' s+(crip "No MCP Prompts found in {(trip p.u.dek)}")]
      ==
    ;<  ~  bind:m
      %-  send-raw-cards:io
      %+  turn
        prompts
      |=  =prompt:mcp
      ^-  card:agent:gall
      :*  %pass   ~
          %agent  [our.bowl %mcp-server]
          %poke   %add-prompt  !>(prompt)
      ==
    =/  prompt-names
      %+  turn
        prompts
      |=  =prompt:mcp
      name.prompt
    %-  pure:m
    !>  ^-  json
    %-  pairs:enjs:format
    :~  ['type' s+'text']
        ['text' s+(crip "Imported MCP Prompts into %mcp-server: {<(of-wain:format prompt-names)>}")]
    ==
==
