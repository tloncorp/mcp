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
      =/  result=(each * (list tank))
        %-  mule
        |.  .^((list resource:mcp) %gx /(scot %p our.bowl)/[dude]/(scot %da now.bowl)/mcp/resources/noun)
      ?.  -.result
        ~
      ?~  ;;((list resource:mcp) p.result)
        ~
      `dude
    ;<  ~  bind:m
      %-  send-raw-cards:io
      %+  turn  agents
      |=  =dude:gall
      ^-  card:agent:gall
      [%pass /import-resources %agent [our.bowl %mcp-server] %poke %import-resources !>(dude)]
    =/  take-acks
      |=  remaining=(list dude:gall)
      =/  am  (strand:spider ,~)
      ^-  form:am
      ?~  remaining
        (pure:am ~)
      ;<  ~  bind:am  (take-poke-ack:io /import-resources)
      $(remaining t.remaining)
    ;<  ~  bind:m  (take-acks agents)
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
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %structured
    %-  frond:enjs:format
    [%imported-resources a+(turn added |=(=resource:mcp s+uri.resource))]
==
