/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/import-mcp-templates'
    'Import MCP Resource Templates from a desk.'
    %-  my
    :~  ['desk' [%string 'Desk to import MCP Resource Templates from.']]
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
    ;<  before=(list template:resource:mcp)  bind:m
      (scry:io (list template:resource:mcp) %gx /mcp-server/mcp/templates/noun)
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
    ::  agents that do not expose MCP templates.
    =/  import-all
      |=  remaining=(list dude:gall)
      =/  am  (strand:spider ,~)
      ^-  form:am
      ?~  remaining
        (pure:am ~)
      ;<  ~  bind:am
        %:  raw-poke:io
            [our.bowl %mcp-server]
            [%import-templates !>(i.remaining)]
        ==
      $(remaining t.remaining)
    ;<  ~  bind:m  (import-all agents)
    ;<  after=(list template:resource:mcp)  bind:m
      (scry:io (list template:resource:mcp) %gx /mcp-server/mcp/templates/noun)
    =/  added=(list template:resource:mcp)
      %+  murn  after
      |=  new=template:resource:mcp
      ^-  (unit template:resource:mcp)
      ?:  %+  lien  before
          |=  old=template:resource:mcp
          =(name.new name.old)
        ~
      `new
    ::
    ::  refreshed: same name as before, but the entry changed
    =/  refreshed=(list template:resource:mcp)
      %+  murn  after
      |=  new=template:resource:mcp
      ^-  (unit template:resource:mcp)
      ?.  %+  lien  before
          |=  old=template:resource:mcp
          &(=(name.new name.old) !=(new old))
        ~
      `new
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %structured
    %-  pairs:enjs:format
    %-  zing
    :~  :~  :-  %imported-resource-templates
            a+(turn added |=(=template:resource:mcp s+uri-template.template))
        ==
        ?~  refreshed  ~
        :~  :-  %refreshed-resource-templates
            a+(turn refreshed |=(=template:resource:mcp s+uri-template.template))
    ==  ==
==
