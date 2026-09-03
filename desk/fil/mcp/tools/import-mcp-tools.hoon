/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/import-mcp-tools'
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
    ?~  dek
      (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string *] u.dek)
    ;<  =bowl:rand  bind:m  get-bowl:io
    ;<  before=(list tool:mcp)  bind:m
      (scry:io (list tool:mcp) %gx /mcp-server/mcp/tools/noun)
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
    ::  agents that do not expose MCP tools.
    =/  import-all
      |=  remaining=(list dude:gall)
      =/  am  (strand:spider ,~)
      ^-  form:am
      ?~  remaining
        (pure:am ~)
      ;<  ~  bind:am
        %:  raw-poke:io
            [our.bowl %mcp-server]
            [%import-tools !>(i.remaining)]
        ==
      $(remaining t.remaining)
    ;<  ~  bind:m  (import-all agents)
    ;<  after=(list tool:mcp)  bind:m
      (scry:io (list tool:mcp) %gx /mcp-server/mcp/tools/noun)
    =/  added=(list tool:mcp)
      %+  murn  after
      |=  new=tool:mcp
      ^-  (unit tool:mcp)
      ?:  %+  lien  before
          |=  old=tool:mcp
          =(name.new name.old)
        ~
      `new
    ::
    ::  refreshed: same name as before, but the entry changed
    =/  refreshed=(list tool:mcp)
      %+  murn  after
      |=  new=tool:mcp
      ^-  (unit tool:mcp)
      ?.  %+  lien  before
          |=  old=tool:mcp
          &(=(name.new name.old) !=(new old))
        ~
      `new
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %structured
    %-  pairs:enjs:format
    %-  zing
    :~  :~  [%imported-tools a+(turn added |=(=tool:mcp s+name.tool))]
        ==
        ?~  refreshed  ~
        :~  [%refreshed-tools a+(turn refreshed |=(=tool:mcp s+name.tool))]
    ==  ==
==
