/-  mcp, spider
/=  dojo-command  /fil/mcp/tools/dojo-command
^-  tool:mcp
:*  'dojo/nuke-agent'
    '''
    Permanently wipe the state of a Gall agent.
    You can also nuke an entire desk.
    '''
    %-  my
    :~  :-  'agent'
        :-  %string
        '''
        Gall agent to nuke (e.g. 'graph-store' to nuke %graph-store).
        '''
    ==
    ~['agent']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  agent=(unit argument:tool:mcp)  (~(get by args) 'agent')
    ?~  agent  (pure:m !>([%error %missing-agent ~]))
    ?>  ?=([%string @t] u.agent)
    =/  agt=@tas  (@tas p.u.agent)
    %-  thread-builder.dojo-command
    %-  ~(gas by *(map name:parameter:tool:mcp argument:tool:mcp))
    :~  ['command' [%string (crip "|nuke {<agt>}, =hard &")]]
    ==
==
