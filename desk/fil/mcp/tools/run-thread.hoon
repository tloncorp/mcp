/-  mcp, spider
/+  io=strandio
/=  dojo-command  /fil/mcp/tools/dojo-command
^-  tool:mcp
:*  'dojo/run-thread'
    '''
    Run a thread from a desk by its /ted path and return the Dojo output.
    Builds the Dojo command "-desk!thread-name arg" and runs it through
    dojo/command, so the thread's printed output comes back as text.
    '''
    %-  my
    :~  :-  'desk'
        :-  %string
        '''
        Desk the thread lives on (e.g. "base").
        '''
        :-  'path'
        :-  %string
        '''
        Path to the thread file, e.g. "/ted/foo/bar" or "/ted/foo/bar/hoon".
        '''
        :-  'arg'
        :-  %string
        '''
        Optional argument text appended to the Dojo command, e.g. "~zod" or
        "[%foo 42]".
        '''
    ==
    ~['desk' 'path']
    ^-  thread-builder:tool:mcp
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  desk-arg=(unit argument:tool:mcp)  (~(get by args) 'desk')
    ?~  desk-arg  (pure:m !>([%error %missing-desk ~]))
    ?>  ?=([%string @t] u.desk-arg)
    =/  path-arg=(unit argument:tool:mcp)  (~(get by args) 'path')
    ?~  path-arg  (pure:m !>([%error %missing-path ~]))
    ?>  ?=([%string @t] u.path-arg)
    =/  arg=(unit @t)
      =/  a=(unit argument:tool:mcp)  (~(get by args) 'arg')
      ?~  a  ~
      ?>  ?=([%string @t] u.a)
      `p.u.a
    =/  dek=@tas  (@tas p.u.desk-arg)
    =/  parsed=(each path tang)  (mule |.((stab p.u.path-arg)))
    ?:  ?=(%| -.parsed)
      (pure:m !>([%error %bad-path ~]))
    =/  pax=path  p.parsed
    ?~  pax  (pure:m !>([%error %empty-path ~]))
    ::  normalize away a trailing /hoon segment
    =/  pax=path  ?:(=(%hoon (rear pax)) (snip `path`pax) pax)
    ?~  pax  (pure:m !>([%error %empty-path ~]))
    ?.  =(%ted i.pax)
      (pure:m !>([%error %not-a-ted-path ~]))
    ?~  t.pax  (pure:m !>([%error %empty-thread-name ~]))
    ;<  =bowl:rand  bind:m  get-bowl:io
    =/  =beak  [our.bowl dek da+now.bowl]
    ;<  hav=?  bind:m  (check-for-file:io beak (snoc `path`pax %hoon))
    ::  second and last attempt: drop the final segment
    =/  pax2=path  (snip `path`pax)
    ;<  hav2=?  bind:m
      ?:  hav  (pure:(strand:spider ,?) &)
      ?:  (lth (lent pax2) 2)  (pure:(strand:spider ,?) |)
      (check-for-file:io beak (snoc pax2 %hoon))
    ?.  hav2
      (pure:m !>([%error %thread-not-found ~]))
    =/  found=path  ?:(hav pax pax2)
    ::  /ted/foo/bar -> "foo-bar"
    =/  name=tape
      %+  roll  `path`(slag 1 found)
      |=  [seg=@ta out=tape]
      ?~  out  (trip seg)
      :(weld out "-" (trip seg))
    =/  cmd=tape
      %+  weld  "-{(trip dek)}!{name}"
      ?~  arg  ""
      [' ' (trip u.arg)]
    %-  thread-builder.dojo-command
    %-  ~(gas by *(map name:parameter:tool:mcp argument:tool:mcp))
    :~  ['command' [%string (crip cmd)]]
    ==
==
