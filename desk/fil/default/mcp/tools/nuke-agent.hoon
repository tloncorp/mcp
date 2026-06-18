/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'urbit/dojo/nuke-agent'
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
    :~  ['command' [%string (crip "|nuke {<agt>}, =hard &")]]
    ==
==
