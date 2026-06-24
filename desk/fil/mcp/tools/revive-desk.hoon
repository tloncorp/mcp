/-  mcp, spider
/=  dojo-command  /fil/mcp/tools/dojo-command
^-  tool:mcp
:*  'dojo/revive-desk'
    '''
    Boot the agents on a nuked / suspended desk.
    '''
    %-  my
    :~  :-  'desk'
        :-  %string
        '''
        Desk name to revive (e.g. 'hark' to revive %hark).
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
    :~  ['command' [%string (crip "|revive {<dek>}")]]
    ==
==
