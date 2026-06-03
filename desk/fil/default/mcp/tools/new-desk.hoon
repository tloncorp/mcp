/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'dojo/new-desk'
    '''
    Create a new desk with some default provisions.
    Will return Dojo prompt >= if successful.
    '''
    %-  my
    :~  :-  'desk'
        :-  %string
        '''
        Name of the desk to create (e.g. 'my-app').
        '''
    ==
    ~['desk']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  desk-arg=(unit argument:tool:mcp)  (~(get by args) 'desk')
    ?~  desk-arg
      ~|(%missing-desk !!)
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
      ?.  =(name.tool 'dojo/command')
        ~
      `tool
    ?~  dojo-tools
      ~|(%missing-dojo-command-tool !!)
    ?:  (gth 1 (lent dojo-tools))
      ~|(%multiple-dojo-command-tools !!)
    %-  thread-builder.i.dojo-tools
    %-  ~(gas by *(map name:parameter:tool:mcp argument:tool:mcp))
    :~  ['command' [%string (crip "|new-desk {<dek>}")]]
    ==
==
