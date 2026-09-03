/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/import-mcp-resources'
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
    ;<  before=(list resource:mcp)  bind:m
      (scry:io (list resource:mcp) %gx /mcp-server/mcp/resources/noun)
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
    ::  agents that do not expose MCP resources.
    =/  import-all
      |=  remaining=(list dude:gall)
      =/  am  (strand:spider ,~)
      ^-  form:am
      ?~  remaining
        (pure:am ~)
      ;<  ~  bind:am
        %:  raw-poke:io
            [our.bowl %mcp-server]
            [%import-resources !>(i.remaining)]
        ==
      $(remaining t.remaining)
    ;<  ~  bind:m  (import-all agents)
    ;<  after=(list resource:mcp)  bind:m
      (scry:io (list resource:mcp) %gx /mcp-server/mcp/resources/noun)
    =/  added=(list resource:mcp)
      %+  murn  after
      |=  new=resource:mcp
      ^-  (unit resource:mcp)
      ?:  %+  lien  before
          |=  old=resource:mcp
          =(uri.new uri.old)
        ~
      `new
    ::
    ::  refreshed: same uri as before, but the entry changed
    =/  refreshed=(list resource:mcp)
      %+  murn  after
      |=  new=resource:mcp
      ^-  (unit resource:mcp)
      ?.  %+  lien  before
          |=  old=resource:mcp
          &(=(uri.new uri.old) !=(new old))
        ~
      `new
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %structured
    %-  pairs:enjs:format
    %-  zing
    :~  :~  [%imported-resources a+(turn added |=(=resource:mcp s+uri.resource))]
        ==
        ?~  refreshed  ~
        :~  [%refreshed-resources a+(turn refreshed |=(=resource:mcp s+uri.resource))]
    ==  ==
==
