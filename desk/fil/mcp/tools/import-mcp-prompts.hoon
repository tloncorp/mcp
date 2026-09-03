/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/import-mcp-prompts'
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
    ?~  dek
      (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string *] u.dek)
    ;<  =bowl:rand  bind:m  get-bowl:io
    ;<  before=(list prompt:mcp)  bind:m
      (scry:io (list prompt:mcp) %gx /mcp-server/mcp/prompts/noun)
    =/  agents=(list dude:gall)
      %+  murn
        ~(tap in .^((set [dude:gall ?]) %ge /(scot %p our.bowl)/[p.u.dek]/(scot %da now.bowl)/$))
      |=  [=dude:gall live=?]
      ^-  (unit dude:gall)
      ?.  live
        ~
      `dude
    ::  A failed Gall scry cannot be softened with +mule. Ask
    ::  %mcp-server to try each live agent and ignore poke nacks from
    ::  agents that do not expose MCP prompts.
    =/  import-all
      |=  remaining=(list dude:gall)
      =/  am  (strand:spider ,~)
      ^-  form:am
      ?~  remaining
        (pure:am ~)
      ;<  ~  bind:am
        %:  raw-poke:io
            [our.bowl %mcp-server]
            [%import-prompts !>(i.remaining)]
        ==
      $(remaining t.remaining)
    ;<  ~  bind:m  (import-all agents)
    ;<  after=(list prompt:mcp)  bind:m
      (scry:io (list prompt:mcp) %gx /mcp-server/mcp/prompts/noun)
    =/  added=(list prompt:mcp)
      %+  murn  after
      |=  new=prompt:mcp
      ^-  (unit prompt:mcp)
      ?:  %+  lien  before
          |=  old=prompt:mcp
          =(name.new name.old)
        ~
      `new
    ::
    ::  refreshed: same name as before, but the entry changed
    =/  refreshed=(list prompt:mcp)
      %+  murn  after
      |=  new=prompt:mcp
      ^-  (unit prompt:mcp)
      ?.  %+  lien  before
          |=  old=prompt:mcp
          &(=(name.new name.old) !=(new old))
        ~
      `new
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %structured
    %-  pairs:enjs:format
    %-  zing
    :~  :~  [%imported-prompts a+(turn added |=(=prompt:mcp s+name.prompt))]
        ==
        ?~  refreshed  ~
        :~  [%refreshed-prompts a+(turn refreshed |=(=prompt:mcp s+name.prompt))]
    ==  ==
==
