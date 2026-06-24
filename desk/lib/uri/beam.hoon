|%
++  parse
  |=  [=beak =cord]
  ^-  (unit beam)
  ::  we don't need to validate the scheme here,
  ::  but a canonical beam:// URI parser should
  =/  stub-count
    %+  roll
      (trip cord)
    |=  [a=@tD b=@ud]
    ?:  =(a '=')
      +(b)
    b
  ?.  (gte 3 stub-count)
    ::  fail; a beam:// can have no more than three stubs
    ~
  ?:  =(0 stub-count)
    ::  skip dereferencing
    (de-beam (stab cord))
  |^  %.  %+  turn
            %+  split
              "/"
            ::  normalise e.g. /===/ to /=/=/=/
            ::  works for any combination of values and =
            %^    replace
                "=="
              "=/="
            ::  remove beam:/, leaving / prefix on the tape
            (oust [0 7] (trip cord))
          crip
      ::  replace = path segments with default values
      |=  =(pole @t)
      ^-  (unit beam)
      ?+  pole  ~
          [her=@t dek=@t cas=@t und=*]
        %-  de-beam
        %-  stab
        %-  crip
        ;:  welp
            "/"
            ?.  =('=' her.pole)  (trip her.pole)  "{<p.beak>}"
            "/"
            ?.  =('=' dek.pole)  (trip dek.pole)  "base"
            "/"
            ?.  =('=' cas.pole)  (trip cas.pole)  "{<p.r.beak>}"
            "/"
            (zing (turn (join '/' und.pole) trip))
        ==
      ==
  ::
  :: ~lagrev-nocfep/yard/~2026.2.5/lib/string/hoon
  ++  replace
    |=  [bit=tape bot=tape =tape]
    ^-  ^tape
    |-
    =/  off  (find bit tape)
    ?~  off  tape
    =/  clr  (oust [(need off) (lent bit)] tape)
    $(tape :(weld (scag (need off) clr) bot (slag (need off) clr)))
  ::
  ++  split
    |=  [sep=tape =tape]
    ^-  (list ^tape)
    =|  res=(list ^tape)
    |-
    ?~  tape  (flop res)
    =/  off  (find sep tape)
    ?~  off  (flop [`^tape`tape `(list ^tape)`res])
    %=  $
      res   [(scag `@ud`(need off) `^tape`tape) res]
      tape  (slag +(`@ud`(need off)) `^tape`tape)
    ==
  --
--
