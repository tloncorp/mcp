/-  mcp, spider
/+  io=strandio, pf=pretty-file
=>
|%
++  print-tang-to-wain
  |=  =tang
  ^-  wain
  %-  zing
  %+  turn
    tang
  |=  =tank
  %+  turn
    (wash [0 80] tank)
  |=  =tape
  (crip tape)
--
::
^-  tool:mcp
:*  'mcp/get-file'
  '''
  Fetch a Clay file on the local ship
  '''
  %-  my
  :~  ['desk' [%string 'The desk this file is in.']]
      ['case' [%string 'The $case (revision number or datetime) at which to access this file.(Default: now.)']]
      ['path' [%string 'The remaining filepath. Must begin with a /.']]
  ==
  ~['desk' 'path']
  ^-  thread-builder:tool:mcp
  |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
  =/  m  (strand:spider ,vase)
  ^-  form:m
  ;<    =bowl:rand
      bind:m
    get-bowl:io
  =/  pax=(unit argument:tool:mcp)  (~(get by args) 'path')
  ?~  pax  (pure:m !>([%error %missing-path ~]))
  ?>  ?=([%string @t] u.pax)
  =/  =path
    ?:  =('/' (snag 0 (trip p.u.pax)))
      (stab p.u.pax)
    (stab (crip (slag 1 (trip p.u.pax))))
  =/  dek=(unit argument:tool:mcp)   (~(get by args) 'desk')
  ?~  dek  (pure:m !>([%error %missing-desk ~]))
  ?>  ?=([%string @t] u.dek)
  =/  cast=(unit argument:tool:mcp)  (~(get by args) 'case')
  =/  cuse=(unit case)
    ?~  cast
      `da+now.bowl
    ?>  ?=([%string @t] u.cast)
    ?+  (@tas -.p:(scan (trip p.u.cast) nuck:so))
      ~
    ::
        %da
      `[%da (@da +.p:(scan (trip p.u.cast) nuck:so))]
    ::
        %ud
      `[%ud (@ud +.p:(scan (trip p.u.cast) nuck:so))]
    ::
        %uv
      `[%uv (@uv +.p:(scan (trip p.u.cast) nuck:so))]
    ==
  ;<  =riot:clay  bind:m
    %:  warp:io
        our.bowl
        (@tas p.u.dek)
        ~
        %sing  %x
        (fall cuse da+now.bowl)
        path
    ==
  %-  pure:m
  !>  ^-  response:tool:mcp
  :-  %result
  :-  %unstructured
  :~  :-  %text
      ?~  riot
        'Failed to fetch file'
      %-  of-wain:format
      %-  print-tang-to-wain
      %-  pretty-file:pf
      !<(noun q.r.u.riot)
  ==
==
