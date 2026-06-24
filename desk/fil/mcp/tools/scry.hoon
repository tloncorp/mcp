/-  mcp, spider
/+  io=strandio, libstrand=strand
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
:*  'mcp/scry-agent'
  '''
  Run a %gx scry (read) to retrieve data from a Gall agent.
  The endpoint must return JSON for this tool to work.
  '''
  %-  my
  :~  :-  'agent'
      :-  %string
      '''
      The Gall agent to scry.
      '''
      :-  'path'
      :-  %string
      '''
      The scry path (e.g. "/tools/json").
      '''
  ==
  ~['agent' 'path']
  ^-  thread-builder:tool:mcp
  |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
  ^-  shed:khan
  =/  m  (strand:spider ,vase)
  ^-  form:m
  =/  gen=(unit argument:tool:mcp)  (~(get by args) 'agent')
  ?~  gen  (pure:m !>([%error %missing-agent ~]))
  =/  pax=(unit argument:tool:mcp)  (~(get by args) 'path')
  ?~  pax  (pure:m !>([%error %missing-path ~]))
  ?>  ?=([%string @t] u.gen)
  ?>  ?=([%string @t] u.pax)
  ::  slap path to handle interpolation, +scot etc.
  =/  =path  !<(path (slap !>(.) (ream p.u.pax)))
  ?.  =(%json (rear path))
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %error
    :-  %scry-path-must-return-json
    `(frond:enjs:format %path s+p.u.pax)
  ;<  =bowl:spider  bind:m  get-bowl:io
  =/  mule-result
    %-  mule
    |.
    .^  *
        %gx
        (welp /(scot %p our.bowl)/[p.u.gen]/(scot %da now.bowl) path)
    ==
  ?>  ?=([? p=*] mule-result)
  ?.  -.mule-result
    %-  pure:m
    !>  ^-  response:tool:mcp
    :-  %error
    :-  %scry-failed
    %-  some
    %-  frond:enjs:format
    :-  %stack-trace
    s+(of-wain:format (print-tang-to-wain (tang p.mule-result)))
  %-  pure:m
  !>  ^-  response:tool:mcp
  :-  %result
  :-  %structured
  %-  frond:enjs:format
  :-  %result
  (json p.mule-result)
==
