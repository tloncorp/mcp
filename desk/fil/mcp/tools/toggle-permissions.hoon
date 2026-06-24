/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/toggle-permissions'
    '''
    Make a whole desk public or private.
    '''
    %-  my
    :~  :-  'desk'
        :-  %string
        '''
        Target desk.
        '''
        :-  'permissions'
        :-  %boolean
        '''
        True makes the whole desk public, and false makes it
        private to the host ship.
        '''
    ==
    ~['desk' 'permissions']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  dek=(unit argument:tool:mcp)  (~(get by args) 'desk')
    =/  per=(unit argument:tool:mcp)  (~(get by args) 'permissions')
    ?~  dek
      (pure:m !>([%error %missing-desk ~]))
    ?~  per
      (pure:m !>([%error %missing-permission-setting ~]))
    ?>  ?=([%string @t] u.dek)
    ?>  ?=([%boolean ?] u.per)
    ;<  ~  bind:m
      %:  poke-our:io
          %hood
          %kiln-permission
          !>([(@tas p.u.dek) / p.u.per])
      ==
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %result
    :-  %unstructured
    :~  :-  %text
        ?:  p.u.per
          (crip "Made {(trip p.u.dek)} public")
        (crip "Made {(trip p.u.dek)} private")
    ==
==
