/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'urbit/dojo/mount-desk'
    '''
    Mount a desk on this ship.
    '''
    %-  my
    :~  :-  'desk'
        :-  %string
        '''
        Desk to mount (e.g. 'base' to mount %base).
        Will return Dojo prompt >= if successful.
        '''
    ==
    ~['desk']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  desk-arg=(unit argument:tool:mcp)  (~(get by args) 'desk')
    ?~  desk-arg  (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string @t] u.desk-arg)
    =/  dek=@tas  (@tas p.u.desk-arg)
    ;<  =bowl:rand  bind:m  get-bowl:io
    =/  tools=(list tool:mcp)
      .^  (list tool:mcp)
          %gx
          /(scot %p our.bowl)/mcp-server/(scot %da now.bowl)/mcp/tools/noun
      ==
    =/  dojo-tools=(list tool:mcp)
      %+  murn  tools
      |=  =tool:mcp
      ^-  (unit tool:mcp)
      ?.  =(name.tool 'urbit/dojo/command')
        ~
      `tool
    ?~  dojo-tools
      (pure:m !>([%error %dojo-command-tool-not-in-mcp-server ~]))
    %-  thread-builder.i.dojo-tools
    %-  ~(gas by *(map name:parameter:tool:mcp argument:tool:mcp))
    :~  ['command' [%string (crip "|mount {<dek>}")]]
    ==
==
