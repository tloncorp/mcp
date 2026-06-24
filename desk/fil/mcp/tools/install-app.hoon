/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/install-app'
    '''
    Install a desk (local or remote).
    '''
    %-  my
    :~  :-  'ship'
        :-  %string
        '''
        Urbit ship from which to install this desk.
        If you create a new desk, you must install it to run it on your ship.
        (Default: our own ship.)
        '''
        :-  'desk'
        :-  %string
        '''
        App (desk) to install (e.g. 'mcp' to install %mcp).
        '''
    ==
    ~['ship' 'desk']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  desk-arg=(unit argument:tool:mcp)
      (~(get by args) 'desk')
    ?~  desk-arg
      (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string @t] u.desk-arg)
    =/  dek=@tas  (@tas p.u.desk-arg)
    ;<  our=@p  bind:m  get-our:io
    =/  ship-arg=(unit argument:tool:mcp)
      (~(get by args) 'ship')
    ?~  ship-arg
      (pure:m !>([%error %missing-ship ~]))
    ?>  ?=([%string @t] u.ship-arg)
    ;<  ~  bind:m
      %:  poke-our:io
          %hood
          %kiln-install
          !>([dek (@p (slav %p p.u.ship-arg)) dek])
      ==
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %unstructured
    :~  [%text (crip "Installing %{(trip dek)} from {(trip p.u.ship-arg)}.")]
    ==
==
