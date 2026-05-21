/-  mcp, spider
/+  io=strandio, libstrand=strand
=,  strand=strand:libstrand
^-  tool:mcp
:*  'urbit-mcp/commit-desk'
    '''
    Commit code changes to a desk.
    '''
    (my ['desk' [%string (crip "desk name (e.g. 'base' to commit the %base desk)")]]~)
    ~['desk']
    ^-  thread-builder:tool:mcp
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
    ::  rough, heuristic, opinionated
    ::  filter on userspace errors
    ++  prune-err
      |=  =tang
      ^-  (list tank)
      %+  murn
        tang
      |=  tak=tank
      ^-  (unit tank)
      ?+  tak
        ::  just a cord
        `tak
      ::
          [%leaf *]  ?~(p.tak ~ `[%leaf p.tak])
      ::
          [%palm *]  ?~(q.tak ~ `[%palm p.tak (prune-err q.tak)])
      ::
          [%rose *]
        ?~  q.tak
          ~
        ?:  ?|  =(i.q.tak [%leaf "sys"])
                =(p.tak [":" "" ""])
            ==
          ~
        `[%rose p.tak (prune-err q.tak)]
      ==
    --
    |=  args=(map name:parameter:tool:mcp argument:tool:mcp)
    ^-  shed:khan
    =/  m  (strand:spider ,vase)
    ^-  form:m
    =/  dek=(unit argument:tool:mcp)  (~(get by args) 'desk')
    ?~  dek
      ~|(%missing-desk !!)
    ?>  ?=([%string *] u.dek)
    ;<  bo1=bowl:rand  bind:m  get-bowl:io
    =/  old-files=(list spur)
      .^  (list spur)
          %ct
          /(scot %p our.bo1)/[p.u.dek]/(scot %da now.bo1)
      ==
    =/  old-hashes=(map spur @uvI)
      %-  my
      %+  turn
        old-files
      |=  =spur
      ^-  (pair ^spur @uvI)
      :-  spur
      .^  @uvI
          %cz
          %+  welp
            /(scot %p our.bo1)/[p.u.dek]/(scot %da now.bo1)
          spur
      ==
    ;<  ~  bind:m
      %-  send-raw-card:io
      :*  %pass  /desk-update
          %arvo  %c
          %warp  [our.bo1 p.u.dek ~ %next %x da+now.bo1 /]
      ==
    ;<  ~  bind:m
      (send-raw-card:io [%pass /dill-logs %arvo %d %logs `~])
    ;<  ~  bind:m
      (poke-our:io %hood %kiln-commit !>([(@tas p.u.dek) %.n]))
    ::  XX must remove set-timeout
    ::     probably need to use sole just for this one use-case
    ;<  [wire dill-sign=sign-arvo]  bind:m
      ((set-timeout:io ,[wire sign-arvo]) ~s2 take-sign-arvo:io)
    ?>  ?=([%dill %logs *] dill-sign)
    ;<  ~  bind:m
      (send-raw-card:io [%pass /dill-logs %arvo %d %logs ~])
    =/  [%dill %logs =told:dill]  dill-sign
    ?-    told
        [%crud *]
      %-  pure:m
      !>  ^-  json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          :-  'text'
          :-  %s
          %-  crip
          "{<[%error p.told (print-tang-to-wain (prune-err q.told))]>}"
      ==
    ::
        [%talk *]
      %-  pure:m
      !>  ^-  json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          ['text' s+(crip "{<[%talk (print-tang-to-wain p.told)]>}")]
      ==
    ::
        [%text *]
      ;<  bo2=bowl:rand  bind:m  get-bowl:io
      ;<  =sign-arvo  bind:m
        =/  m  (strand ,sign-arvo)
        ^-  form:m
        |=  tin=strand-input:strand
        ?+    in.tin  `[%skip ~]
            ~
          `[%wait ~]
        ::
            [~ %sign *]
          ?.  =(/desk-update wire.u.in.tin)
            `[%skip ~]
          `[%done sign-arvo.u.in.tin]
        ==
      ?>  ?=([%clay %writ *] sign-arvo)
      =/  new-files=(list spur)
        .^  (list spur)
            %ct
            /(scot %p our.bo2)/[p.u.dek]/(scot %da now.bo2)
        ==
      =/  new-hashes=(map spur @uvI)
        %-  my
        %+  turn
          new-files
        |=  =spur
        ^-  (pair ^spur @uvI)
        :-  spur
        .^  @uvI
            %cz
            %+  welp
              /(scot %p our.bo2)/[p.u.dek]/(scot %da now.bo2)
            spur
        ==
      =/  modified=(list spur)
        %+  murn
          new-files
        |=  =spur
        ^-  (unit ^spur)
        ?:  ?=(~ (find ~[spur] old-files))
          ~
        ?:  =((~(got by old-hashes) spur) (~(got by new-hashes) spur))
          ~
        `spur
      =/  added=(list spur)
        %+  murn
          new-files
        |=  =spur
        ^-  (unit ^spur)
        ?:  ?=(~ (find ~[spur] old-files))
          `spur
        ~
      =/  deleted=(list spur)
        %+  murn
          old-files
        |=  =spur
        ^-  (unit ^spur)
        ?.  ?=(~ (find ~[spur] new-files))
          ~
        `spur
      %-  pure:m
      !>  ^-  json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          :-  'text'
          :-  %s
          %-  of-wain:format
          :-  'Commit successful!'
          %-  zing
          :~  ?~  added
                ~
              :-  'Added:'
              %+(turn added |=(=spur (spat spur)))
              ?~  deleted
                ~
              :-  'Deleted:'
              %+(turn deleted |=(=spur (spat spur)))
              ?~  modified
                ~
              :-  'Modified:'
              %+(turn modified |=(=spur (spat spur)))
          ==
      ==
    ==
==
