/-  mcp, spider
/=  dojo-command  /fil/mcp/tools/dojo-command
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
    ?~  desk-arg  (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string @t] u.desk-arg)
    =/  dek=@tas  (@tas p.u.desk-arg)
    %-  thread-builder.dojo-command
    %-  ~(gas by *(map name:parameter:tool:mcp argument:tool:mcp))
    :~  ['command' [%string (crip "|new-desk {<dek>}")]]
    ==
==
