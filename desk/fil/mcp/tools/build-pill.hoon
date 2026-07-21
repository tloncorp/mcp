/-  mcp, spider
/+  io=strandio
/=  dojo-command  /fil/mcp/tools/dojo-command
^-  tool:mcp
:*  'dojo/build-pill'
    '''
    Build a brass pill from a list of desks, primed and cached, and save
    it to the pier's Unix filesystem at .urb/put/<name>.pill.
    '''
    %-  my
    :~  :-  'desks'
        :-  %array
        '''
        Non-base userspace desks to include in the pill, as an array of
        desk names (e.g. ["mcp", "landscape"]). The base desk is always
        included and need not be listed.
        '''
        :-  'base'
        :-  %string
        '''
        Optional desk to use as the pill's base desk (e.g. "base-2").
        Defaults to "base".
        '''
        :-  'name'
        :-  %string
        '''
        Filename for the new pill: "foo" produces foo.pill in the pier's
        .urb/put/ directory.
        '''
    ==
    ~['desks' 'name']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  dez=(unit argument:tool:mcp)  (~(get by args) 'desks')
    ?~  dez
      (pure:m !>([%error %missing-desks ~]))
    ?>  ?=([%array *] u.dez)
    =/  nam=(unit argument:tool:mcp)  (~(get by args) 'name')
    ?~  nam
      (pure:m !>([%error %missing-name ~]))
    ?>  ?=([%string @t] u.nam)
    =/  bas=@tas
      =/  arg=(unit argument:tool:mcp)  (~(get by args) 'base')
      ?~  arg
        %base
      ?>  ?=([%string @t] u.arg)
      (@tas p.u.arg)
    =/  pil=@tas  (@tas p.u.nam)
    ?.  &(((sane %tas) bas) ((sane %tas) pil))
      (pure:m !>([%error %invalid-desk-or-name ~]))
    ::  base always leads the list; drop it (and duplicates) from desks
    ::
    =/  rest=(list @tas)
      =|  out=(list @tas)
      |-
      ?~  p.u.dez
        (flop out)
      ?>  ?=([%string @t] i.p.u.dez)
      =/  dek=@tas  (@tas p.i.p.u.dez)
      ?:  |(=(dek bas) ?=(^ (find ~[dek] out)))
        $(p.u.dez t.p.u.dez)
      $(p.u.dez t.p.u.dez, out [dek out])
    ?.  (levy rest (sane %tas))
      (pure:m !>([%error %invalid-desk-name ~]))
    =/  desk-text=tape
      %+  roll  rest
      |=  [dek=@tas out=tape]
      "{out} %{(trip dek)}"
    =/  cmd=tape
      ".{(trip pil)}/pill +pill/brass %{(trip bas)}{desk-text}, =prime .y, =cache .y"
    %-  thread-builder.dojo-command
    %-  ~(gas by *(map name:parameter:tool:mcp argument:tool:mcp))
    :~  ['command' [%string (crip cmd)]]
        ['timeout-seconds' [%number 600]]
    ==
==
