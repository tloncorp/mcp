/-  mcp, sole, spider
/+  io=strandio, libstrand=strand
=,  sole
=,  strand=strand:libstrand
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
::
++  join-wain
  |=  =wain
  ^-  @t
  =/  out=tape  ~
  |-
  ?~  wain
    (crip out)
  $(wain t.wain, out (weld out (weld (trip i.wain) ?~(t.wain "" "\0a"))))
::
++  effect-lines
  |=  fec=sole-effect
  ^-  wain
  ?+  -.fec  ~
    %mor
  %-  zing
  %+  turn
    p.fec
  effect-lines
::
    %txt  [(crip p.fec) ~]
    %tan  (print-tang-to-wain p.fec)
    %err  [(crip "dojo parse error at {<p.fec>}") ~]
    %url  [p.fec ~]
  ==
::
++  log-lines
  |=  log=told:dill
  ^-  wain
  ?-  -.log
      %crud
    %-  zing
    %+  turn
      ^-  wall
      (zing (turn (flop q.log) (cury wash [0 80])))
    |=  =tape
    [(crip tape) ~]
  ::
      %talk
    %-  zing
    %+  turn
      ^-  wall
      (zing (turn p.log (cury wash [0 80])))
    |=  =tape
    [(crip tape) ~]
  ::
      %text  [(crip p.log) ~]
  ==
::
++  is-pro
  |=  fec=sole-effect
  ^-  ?
  ?+  -.fec  |
    %pro  &
    %mor  (lien p.fec is-pro)
  ==
::
++  safe-set-timeout
  |*  computation-result=mold
  =/  m  (strand ,computation-result)
  |=  [time=@dr computation=form:m]
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when  (add now time)
  =/  =card:agent:gall
    [%pass /timeout/(scot %da when) %arvo %b %wait when]
  ;<  ~  bind:m  (send-raw-card:io card)
  |=  tin=strand-input:strand
  =*  loop  $
  ?:  ?&  ?=([~ %sign [%timeout @ ~] %behn %wake *] in.tin)
          =((scot %da when) i.t.wire.u.in.tin)
      ==
    `[%done ~]
  =/  c-res  (computation tin)
  ?:  ?=(%cont -.next.c-res)
    c-res(self.next ..loop(computation self.next.c-res))
  ?:  ?=(%done -.next.c-res)
    =/  =card:agent:gall
      [%pass /timeout/(scot %da when) %arvo %b %rest when]
    c-res(cards [card cards.c-res])
  c-res
::
++  take-sole-effect
  |=  =wire
  =/  m  (strand ,sole-effect)
  ^-  form:m
  |=  tin=strand-input:strand
  ?+  in.tin  `[%skip ~]
      ~  `[%wait ~]
      [~ %agent * %fact *]
    ?.  =(watch+wire wire.u.in.tin)
      `[%skip ~]
    ?.  =(%sole-effect p.cage.sign.u.in.tin)
      `[%skip ~]
    `[%done !<(sole-effect q.cage.sign.u.in.tin)]
  ==
::
++  take-output
  |=  =wire
  =/  m  (strand ,(each sole-effect told:dill))
  ^-  form:m
  |=  tin=strand-input:strand
  ?+  in.tin  `[%skip ~]
      ~  `[%wait ~]
      [~ %agent * %fact *]
    ?.  =(watch+wire wire.u.in.tin)
      `[%skip ~]
    ?.  =(%sole-effect p.cage.sign.u.in.tin)
      `[%skip ~]
    `[%done [%& !<(sole-effect q.cage.sign.u.in.tin)]]
  ::
      [~ %sign *]
    ?.  =(/dill-logs wire.u.in.tin)
      `[%skip ~]
    ?.  ?=([%dill %logs *] sign-arvo.u.in.tin)
      `[%skip ~]
    =/  [%dill %logs =told:dill]  sign-arvo.u.in.tin
    `[%done [%| told]]
  ==
::
++  collect-until-pro
  |=  [=wire limit=@dr]
  =/  m  (strand ,[(list cord) ?])
  =|  lines=(list cord)
  |-  ^-  form:m
  ;<  maybe=(unit sole-effect)  bind:m
    %+  (safe-set-timeout (unit sole-effect))  limit
    =/  m  (strand ,(unit sole-effect))
    ^-  form:m
    ;<  fec=sole-effect  bind:m  (take-sole-effect wire)
    (pure:m `fec)
  ?~  maybe
    (pure:m [lines |])
  =/  extra=wain  (effect-lines u.maybe)
  =/  done=?      (is-pro u.maybe)
  =.  lines       (weld lines extra)
  ?:  done
    (pure:m [lines &])
  $(lines lines)
::
++  collect-output-until-idle
  |=  [=wire first-timeout=@dr idle-timeout=@dr]
  =/  m  (strand ,(list cord))
  =|  lines=(list cord)
  =|  seen=?
  |-  ^-  form:m
  ;<  maybe=(unit (each sole-effect told:dill))  bind:m
    %+  (safe-set-timeout (unit (each sole-effect told:dill)))
      ?:(seen idle-timeout first-timeout)
    =/  m  (strand ,(unit (each sole-effect told:dill)))
    ^-  form:m
    ;<  out=(each sole-effect told:dill)  bind:m  (take-output wire)
    (pure:m `out)
  ?~  maybe
    (pure:m lines)
  =/  extra=wain
    ?-  -.u.maybe
      %&  (effect-lines p.u.maybe)
      %|  (log-lines p.u.maybe)
    ==
  $(lines (weld lines extra), seen &)
--
::
^-  tool:mcp
:*  'dojo/command'
  '''
  Run one string in Dojo through the %sole command-line protocol and return
  the text emitted before Dojo reports the next prompt.
  '''
  %-  my
  :~  :-  'command'
      :-  %string
      '''
      The Dojo input to run, e.g. "(add 2 2)" or "'hello world'".
      '''
      :-  'timeout-seconds'
      :-  %number
      '''
      Optional timeout in seconds while waiting for Dojo output.
      Defaults to 10.
      '''
  ==
  ~['command']
  ^-  thread-builder:tool:mcp
  |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
  ^-  shed:khan
  =/  m  (strand:spider ,vase)
  ^-  form:m
  =/  cmd=(unit argument:tool:mcp)  (~(get by args) 'command')
  ?~  cmd
    (pure:m !>([%error %missing-command ~]))
  ?>  ?=([%string @t] u.cmd)
  =/  timeout=@dr
    =/  arg=(unit argument:tool:mcp)  (~(get by args) 'timeout-seconds')
    ?~  arg
      ~s10
    ?>  ?=([%number @] u.arg)
    (mul ~s1 p.u.arg)
  ;<  bowl=bowl:rand  bind:m  get-bowl:io
  =/  ses=@ta  (scot %ta (cat 3 'mcp-dojo-' (scot %uv (sham eny.bowl))))
  =/  id=sole-id  [our.bowl ses]
  =/  wire=wire   /dojo-command/[ses]
  ;<  ~  bind:m  (watch-our:io wire %dojo /sole/(scot %p our.bowl)/[ses])
  ;<  *  bind:m  (collect-until-pro wire ~s5)
  ;<  ~  bind:m
    (send-raw-card:io [%pass /dill-logs %arvo %d %logs `~])
  ;<  ~  bind:m
    %+  poke-our:io  %dojo
    :-  %sole-action
    !>  ^-  sole-action
    [id %det [[0 0] 0v0 [%set (tuba (trip p.u.cmd))]]]
  ;<  ~  bind:m
    %+  poke-our:io  %dojo
    :-  %sole-action
    !>  ^-  sole-action
    [id %ret ~]
  ;<  result=(list cord)  bind:m  (collect-output-until-idle wire timeout ~s1)
  ;<  ~  bind:m
    (send-raw-card:io [%pass /dill-logs %arvo %d %logs ~])
  ;<  ~  bind:m  (leave-our:io wire %dojo)
  %-  pure:m
  !>  ^-  response:tool:mcp
  :-  %result
  :-  %structured
  %-  frond:enjs:format
  [%dojo-output s+(of-wain:format result)]
==
