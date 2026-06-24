/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'dojo/exit'
    '''
    Enter |exit in the Dojo, gracefully shutting down the ship.
    '''
    ~
    ~
    ^-  thread-builder:tool:mcp
    |=  *
    =/  m  (strand:spider ,vase)
    ^-  form:m
    ;<  ~  bind:m
      (send-raw-card:io [%pass /dojo-exit %arvo %d %belt [%txt (tuba "|exit")]])
    ;<  ~  bind:m
      (send-raw-card:io [%pass /dojo-exit %arvo %d %belt [%ret ~]])
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %unstructured
    :~  [%text '|exit entered in the Dojo']
    ==
==
