::  Uncached, diagnostic Hoon source builder.
::
::  Unlike Clay %a, this returns build errors to its caller.  Every source body
::  is guarded by a Clay %u existence scry and then fetched independently
::  through %x.  Failure-prone Ford operations are kept behind +mule so a bad
::  dependency is returned to the caller instead of taking down the agent.
::
=/  bud
  =/  zuse  !>(..zuse)
  :*  zuse=zuse
      nave=(slap zuse !,(*hoon nave:clay))
      same=(slap zuse !,(*hoon same))
  ==
|_  [our=@p =desk now=@da]
::  +build: build a /path/to/file/hoon and retain all compiler error tanks.
::
++  build
  |=  target=path
  ^-  (each vase tang)
  (build-file target ~)
::
::  +source-path: fully qualify a Clay source path.
::
++  source-path
  |=  local=path
  ^-  path
  (en-beam [our desk da+now] local)
::
::  +read-source: all actual file reads use the %x namespace.
::
++  read-source
  |=  local=path
  ^-  (unit @t)
  ?.  (exists local)  ~
  `[.^(@t %cx (source-path local))]
::
::  +exists: existence probes do not build or cache source.
::
++  exists
  |=  local=path
  ^-  ?
  .^(? %cu (source-path local))
::
::  +build-file: recursively build one source file with cycle detection.
::
++  build-file
  |=  [target=path active=(set path)]
  ^-  (each vase tang)
  ?:  (~(has in active) target)
    [%.n ~[leaf+"dependency cycle at {(spud target)}"]]
  =/  source=(unit @t)  (read-source target)
  ?~  source
    :-  %.n
    :~  leaf+"source file does not exist: {(spud target)}"
        leaf+"desk: {<desk>}, revision: {<now>}"
    ==
  =/  parsed=(each pile:clay tang)  (parse-pile target u.source)
  ?:  ?=(%| -.parsed)
    [%.n [leaf+"while parsing {(spud target)}" p.parsed]]
  =/  next=(set path)  (~(put in active) target)
  =/  subject=(each vase tang)  (run-prelude p.parsed next)
  ?:  ?=(%| -.subject)
    [%.n [leaf+"while building dependencies of {(spud target)}" p.subject]]
  =/  compiled  (mule |.((slub p.subject hoon.p.parsed)))
  ?-  -.compiled
    %|  [%.n [leaf+"while compiling {(spud target)}" p.compiled]]
    %&  compiled
  ==
::
::  +run-prelude: construct the compilation subject in Ford's order.
::
++  run-prelude
  |=  [parsed=pile:clay active=(set path)]
  ^-  (each vase tang)
  =/  subject=vase  !>(..zuse)
  =/  sur-result=(each vase tang)
    (run-tauts subject %sur sur.parsed active)
  ?:  ?=(%| -.sur-result)  sur-result
  =/  lib-result=(each vase tang)
    (run-tauts p.sur-result %lib lib.parsed active)
  ?:  ?=(%| -.lib-result)  lib-result
  =/  raw-result=(each vase tang)
    (run-raw p.lib-result raw.parsed active)
  ?:  ?=(%| -.raw-result)  raw-result
  =/  raz-result=(each vase tang)
    (run-raz p.raw-result raz.parsed active)
  ?:  ?=(%| -.raz-result)  raz-result
  =/  maz-result=(each vase tang)
    (run-maz p.raz-result maz.parsed active)
  ?:  ?=(%| -.maz-result)  maz-result
  =/  caz-result=(each vase tang)
    (run-caz p.maz-result caz.parsed active)
  ?:  ?=(%| -.caz-result)  caz-result
  (run-bar p.caz-result bar.parsed active)
::
::  +run-tauts: build /sur and /lib imports and compose their subjects.
::
++  run-tauts
  |=  $:  subject=vase
          kind=?(%lib %sur)
          imports=(list taut:clay)
          active=(set path)
      ==
  ^-  (each vase tang)
  ?~  imports  [%.y subject]
  =/  dependency=(unit path)  (fit-path kind pax.i.imports)
  ?~  dependency
    [%.n ~[leaf+"no files match /{(trip kind)}/{(trip pax.i.imports)}/hoon"]]
  =/  built=(each vase tang)  (build-file u.dependency active)
  ?:  ?=(%| -.built)  built
  =/  import=vase  p.built
  =?  p.import  ?=(^ face.i.imports)
    [%face u.face.i.imports p.import]
  =/  composed=(each vase tang)  (mule |.((slop import subject)))
  ?:  ?=(%| -.composed)
    [%.n [leaf+"while composing {(spud u.dependency)}" p.composed]]
  $(subject p.composed, imports t.imports)
::
::  +run-raw: build direct /= path dependencies.
::
++  run-raw
  |=  $:  subject=vase
          imports=(list [face=term =path])
          active=(set path)
      ==
  ^-  (each vase tang)
  ?~  imports  [%.y subject]
  =/  dependency=path  (snoc path.i.imports %hoon)
  =/  built=(each vase tang)  (build-file dependency active)
  ?:  ?=(%| -.built)  built
  =/  import=vase  p.built
  =.  p.import  [%face face.i.imports p.import]
  =/  composed=(each vase tang)  (mule |.((slop import subject)))
  ?:  ?=(%| -.composed)
    [%.n [leaf+"while composing {(spud dependency)}" p.composed]]
  $(subject p.composed, imports t.imports)
::
::  +run-raz: build a typed map of the Hoon files directly in a directory.
::
++  run-raz
  |=  $:  subject=vase
          imports=(list [face=term =spec =path])
          active=(set path)
      ==
  ^-  (each vase tang)
  ?~  imports  [%.y subject]
  =/  built=(each (map @ta vase) tang)
    (build-directory path.i.imports active)
  ?:  ?=(%| -.built)  built
  =/  expected=(each type tang)
    (mule |.((~(play ut p.subject) [%kttr spec.i.imports])))
  ?:  ?=(%| -.expected)
    [%.n [leaf+"while evaluating /~ type for {(spud path.i.imports)}" p.expected]]
  =/  checked=(each (map @ta vase) tang)
    (check-directory path.i.imports p.expected p.built)
  ?:  ?=(%| -.checked)  checked
  =/  map-type=(each type tang)
    %-  mule
    |.
    %-  ~(play ut p.subject)
    [%kttr %make [%wing ~[%map]] ~[[%base %atom %ta] spec.i.imports]]
  ?:  ?=(%| -.map-type)
    [%.n [leaf+"while constructing /~ map type for {(spud path.i.imports)}" p.map-type]]
  =/  pin=vase  [p.map-type (map-nouns p.checked)]
  =.  p.pin  [%face face.i.imports p.pin]
  =/  composed=(each vase tang)  (mule |.((slop pin subject)))
  ?:  ?=(%| -.composed)
    [%.n [leaf+"while composing /~ {(spud path.i.imports)}" p.composed]]
  $(subject p.composed, imports t.imports)
::
::  +build-directory: build only immediate /name/hoon children.
::
++  build-directory
  |=  [directory=path active=(set path)]
  ^-  (each (map @ta vase) tang)
  =/  archive=arch  .^(arch %cy (source-path directory))
  =/  names=(list @ta)
    %+  murn  ~(tap by dir.archive)
    |=  [name=@ta ~]
    =/  hoon=arch
      .^(arch %cy (source-path (weld directory name %hoon ~)))
    ?~  fil.hoon  ~
    `name
  =|  result=(map @ta vase)
  |-
  ?~  names  [%.y result]
  =/  dependency=path  (weld directory i.names %hoon ~)
  =/  built=(each vase tang)  (build-file dependency active)
  ?:  ?=(%| -.built)
    [%.n [leaf+"while building directory entry {(spud dependency)}" p.built]]
  $(names t.names, result (~(put by result) i.names p.built))
::
++  check-directory
  |=  [directory=path expected=type files=(map @ta vase)]
  ^-  (each (map @ta vase) tang)
  =/  entries=(list [@ta vase])  ~(tap by files)
  |-
  ?~  entries  [%.y files]
  =/  [name=@ta value=vase]  i.entries
  =/  nested=(each ? tang)
    (mule |.((~(nest ut expected) | p.value)))
  ?:  ?=(%| -.nested)
    [%.n [leaf+"while checking /~ entry {(trip name)}" p.nested]]
  ?.  p.nested
    [%.n ~[leaf+"/~ entry {(trip name)} in {(spud directory)} does not match its declared type"]]
  $(entries t.entries)
::
++  map-nouns
  |=  files=(map @ta vase)
  ^-  (map @ta *)
  %-  malt
  %+  turn  ~(tap by files)
  |=  [name=@ta value=vase]
  [name q.value]
::
::  +run-maz: import statically typed mark cores from /mar.
::
++  run-maz
  |=  $:  subject=vase
          imports=(list [face=term =mark])
          active=(set path)
      ==
  ^-  (each vase tang)
  ?~  imports  [%.y subject]
  =/  built=(each vase tang)
    (build-nave mark.i.imports active ~)
  ?:  ?=(%| -.built)  built
  =/  pin=vase  p.built
  =.  p.pin  [%face face.i.imports p.pin]
  =/  composed=(each vase tang)  (mule |.((slop pin subject)))
  ?:  ?=(%| -.composed)
    [%.n [leaf+"while composing /% {<mark.i.imports>}" p.composed]]
  $(subject p.composed, imports t.imports)
::
::  +run-caz: import a statically typed mark conversion gate.
::
++  run-caz
  |=  $:  subject=vase
          imports=(list [face=term mars=mars:clay])
          active=(set path)
      ==
  ^-  (each vase tang)
  ?~  imports  [%.y subject]
  =/  [from=mark to=mark]  mars.i.imports
  =/  built=(each vase tang)
    (build-cast from to active ~)
  ?:  ?=(%| -.built)  built
  =/  pin=vase  p.built
  =.  p.pin  [%face face.i.imports p.pin]
  =/  composed=(each vase tang)  (mule |.((slop pin subject)))
  ?:  ?=(%| -.composed)
    [%.n [leaf+"while composing /$ {<from>} to {<to>}" p.composed]]
  $(subject p.composed, imports t.imports)
::
::  +run-bar: read a marked file, validate it, and cast it to the target mark.
::
++  run-bar
  |=  $:  subject=vase
          imports=(list [face=term =mark =path])
          active=(set path)
      ==
  ^-  (each vase tang)
  ?~  imports  [%.y subject]
  =/  cage-result=(each cage tang)
    (cast-path path.i.imports mark.i.imports active)
  ?:  ?=(%| -.cage-result)  cage-result
  =/  pin=vase  q.p.cage-result
  =.  p.pin  [%face face.i.imports p.pin]
  =/  composed=(each vase tang)  (mule |.((slop pin subject)))
  ?:  ?=(%| -.composed)
    [%.n [leaf+"while composing /* {(spud path.i.imports)}" p.composed]]
  $(subject p.composed, imports t.imports)
::
++  with-face
  |=  [face=@tas value=vase]
  ^-  vase
  [[%face face p.value] q.value]
::
++  with-faces
  |=  values=(list [face=@tas value=vase])
  ^-  vase
  ?~  values  !>(~)
  =/  result=vase  (with-face i.values)
  |-
  ?~  t.values  result
  =/  next=vase  (with-face i.t.values)
  $(values t.values, result (slop next result))
::
::  +build-nave: reproduce Ford's two supported mark-definition styles.
::
++  build-nave
  |=  $:  mak=mark
          active=(set path)
          naves=(set mark)
      ==
  ^-  (each vase tang)
  ?:  (~(has in naves) mak)
    [%.n ~[leaf+"mark dependency cycle at %{(trip mak)}"]]
  =/  dependency=(unit path)  (fit-path %mar mak)
  ?~  dependency
    [%.n ~[leaf+"no files match /mar/{(trip mak)}/hoon"]]
  =/  built=(each vase tang)  (build-file u.dependency active)
  ?:  ?=(%| -.built)
    [%.n [leaf+"while building mark %{(trip mak)}" p.built]]
  =/  cor=vase  p.built
  =/  gad=(each vase tang)  (mule |.((slub cor limb/%grad)))
  ?:  ?=(%| -.gad)
    [%.n [leaf+"while reading +grad from mark %{(trip mak)}" p.gad]]
  ?@  q.p.gad
    =/  delegated=(each mark tang)  (mule |.(!<(mark p.gad)))
    ?:  ?=(%| -.delegated)
      [%.n [leaf+"invalid +grad in mark %{(trip mak)}" p.delegated]]
    =/  next=(set mark)  (~(put in naves) mak)
    =/  deg=(each vase tang)  (build-nave p.delegated active next)
    ?:  ?=(%| -.deg)  deg
    =/  tub=(each vase tang)  (build-cast mak p.delegated active ~)
    ?:  ?=(%| -.tub)  tub
    =/  but=(each vase tang)  (build-cast p.delegated mak active ~)
    ?:  ?=(%| -.but)  but
    =/  made=(each vase tang)
      %-  mule
      |.
      %+  slub
        %-  with-faces
        :~  [%deg p.deg]
            [%tub p.tub]
            [%but p.but]
            [%cor cor]
            [%nave nave.bud]
        ==
      !,  *hoon
      =/  typ  _+<.cor
      =/  dif  _*diff:deg
      ^-  (nave typ dif)
      |%
      ++  diff
        |=  [old=typ new=typ]
        ^-  dif
        (diff:deg (tub old) (tub new))
      ++  form  form:deg
      ++  join  join:deg
      ++  mash  mash:deg
      ++  pact
        |=  [v=typ d=dif]
        ^-  typ
        (but (pact:deg (tub v) d))
      ++  vale  noun:grab:cor
      --
    ?:  ?=(%| -.made)
      [%.n [leaf+"while constructing delegated mark %{(trip mak)}" p.made]]
    made
  =/  made=(each vase tang)
    %-  mule
    |.
    %+  slub  (slop (with-face [%cor cor]) !>(..zuse))
    !,  *hoon
    =/  typ  _+<.cor
    =/  dif  _*diff:grad:cor
    ^-  (nave:clay typ dif)
    |%
    ++  diff  |=([old=typ new=typ] (diff:~(grad cor old) new))
    ++  form  form:grad:cor
    ++  join
      |=  [a=dif b=dif]
      ^-  (unit (unit dif))
      ?:  =(a b)  ~
      `(join:grad:cor a b)
    ++  mash
      |=  [a=[=ship =desk =dif] b=[=ship =desk =dif]]
      ^-  (unit dif)
      ?:  =(dif.a dif.b)  ~
      `(mash:grad:cor a b)
    ++  pact  |=([v=typ d=dif] (pact:~(grad cor v) d))
    ++  vale  noun:grab:cor
    --
  ?:  ?=(%| -.made)
    [%.n [leaf+"while constructing mark %{(trip mak)}" p.made]]
  made
::
::  +build-cast: find and build direct or indirect mark converters.
::
++  build-cast
  |=  $:  a=mark
          b=mark
          active=(set path)
          casts=(set [mark mark])
      ==
  ^-  (each vase tang)
  =/  request=[mark mark]  [a b]
  ?:  (~(has in casts) request)
    [%.n ~[leaf+"mark conversion cycle from %{(trip a)} to %{(trip b)}"]]
  ?:  =(a b)  [%.y same.bud]
  ?:  =([%mime %hoon] [a b])
    =/  made=(each vase tang)
      %-  mule
      |.
      =>  ..zuse
      !>(|=(m=mime q.q.m))
    ?:  ?=(%| -.made)
      [%.n [leaf+"while constructing %mime to %hoon conversion" p.made]]
    made
  =/  old-path=(unit path)  (fit-path %mar a)
  ?~  old-path
    [%.n ~[leaf+"no files match /mar/{(trip a)}/hoon"]]
  =/  old-result=(each vase tang)  (build-file u.old-path active)
  ?:  ?=(%| -.old-result)  old-result
  =/  old=vase  p.old-result
  ?:  (has-arm %grow b old)
    =/  made=(each vase tang)
      %-  mule
      |.
      %+  slub  (with-faces ~[[%cor old]])
      ^-  hoon
      :+  %brcl  !,(*hoon v=+<.cor)
      :+  %sggr  [%spin %cltr [%sand %t (crip "grow-{<a>}->{<b>}")] ~]
      :+  %tsgl  limb/b
      !,(*hoon ~(grow cor v))
    ?:  ?=(%| -.made)
      [%.n [leaf+"while constructing +grow conversion from %{(trip a)} to %{(trip b)}" p.made]]
    made
  =/  new-path=(unit path)  (fit-path %mar b)
  ?~  new-path
    [%.n ~[leaf+"no files match /mar/{(trip b)}/hoon"]]
  =/  new-result=(each vase tang)  (build-file u.new-path active)
  ?:  ?=(%| -.new-result)  new-result
  =/  new=vase  p.new-result
  =/  arm=?  (has-arm %grab a new)
  =/  rab=(each vase tang)
    (mule |.((slap new tsgl/[limb/a limb/%grab])))
  ?:  &(arm ?=(%& -.rab) ?=(^ q.p.rab))
    rab
  =/  jum=(each vase tang)
    (mule |.((slub old tsgl/[limb/b limb/%jump])))
  ?:  &((has-arm %jump a old) ?=(%& -.jum))
    =/  via=(each mark tang)  (mule |.(!<(mark p.jum)))
    ?:  ?=(%| -.via)
      [%.n [leaf+"invalid +jump in mark %{(trip a)}" p.via]]
    (compose-casts a p.via b active (~(put in casts) request))
  ?:  &(arm ?=(%& -.rab))
    =/  via=(each mark tang)  (mule |.(!<(mark p.rab)))
    ?:  ?=(%| -.via)
      [%.n [leaf+"invalid +grab in mark %{(trip b)}" p.via]]
    (compose-casts a p.via b active (~(put in casts) request))
  ?:  =(%noun b)  [%.y same.bud]
  [%.n ~[leaf+"no cast from %{(trip a)} to %{(trip b)}"]]
::
++  compose-casts
  |=  $:  x=mark
          y=mark
          z=mark
          active=(set path)
          casts=(set [mark mark])
      ==
  ^-  (each vase tang)
  =/  uno=(each vase tang)  (build-cast x y active casts)
  ?:  ?=(%| -.uno)  uno
  =/  dos=(each vase tang)  (build-cast y z active casts)
  ?:  ?=(%| -.dos)  dos
  =/  made=(each vase tang)
    %-  mule
    |.
    %+  slub  (with-faces ~[[%uno p.uno] [%dos p.dos]])
    !,(*hoon |=(_+<.uno (dos (uno +<))))
  ?:  ?=(%| -.made)
    [%.n [leaf+"while composing casts %{(trip x)} to %{(trip y)} to %{(trip z)}" p.made]]
  made
::
++  has-arm
  |=  [arm=@tas mak=mark core=vase]
  ^-  ?
  =/  rib  (mule |.((slub core [%wing ~[arm]])))
  ?:  ?=(%| -.rib)  %.n
  =/  lab  (mule |.((slob mak p.p.rib)))
  ?:  ?=(%| -.lab)  %.n
  p.lab
::
++  cast-path
  |=  [target=path mak=mark active=(set path)]
  ^-  (each cage tang)
  ?.  (exists target)
    [%.n ~[leaf+"source file does not exist: {(spud target)}"]]
  =/  mok=mark  (head (flop target))
  =/  raw-result=(each * tang)
    (mule |.(.^(* %cx (source-path target))))
  ?:  ?=(%| -.raw-result)
    [%.n [leaf+"while reading marked file {(spud target)}" p.raw-result]]
  =/  nave-result=(each vase tang)  (build-nave mok active ~)
  ?:  ?=(%| -.nave-result)  nave-result
  =/  validated=(each vase tang)
    %-  mule
    |.
    =/  nav=vase  p.nave-result
    =/  noun  q:(slub nav !,(*hoon *vale))
    (slam (slub nav limb/%vale) noun/p.raw-result)
  ?:  ?=(%| -.validated)
    [%.n [leaf+"while validating {(spud target)} as %{(trip mok)}" p.validated]]
  ?:  =(mok mak)  [%.y mak+p.validated]
  =/  cast-result=(each vase tang)  (build-cast mok mak active ~)
  ?:  ?=(%| -.cast-result)  cast-result
  =/  converted=(each vase tang)
    (mule |.((slam p.cast-result p.validated)))
  ?:  ?=(%| -.converted)
    [%.n [leaf+"while casting {(spud target)} from %{(trip mok)} to %{(trip mak)}" p.converted]]
  [%.y mak+p.converted]
::
::  +fit-path: reproduce Clay's hyphen-to-path dependency search.
::
++  fit-path
  |=  [prefix=@tas name=@tas]
  ^-  (unit path)
  =/  candidates=(list path)  (segments name)
  |-
  ?~  candidates  ~
  =/  candidate=path  prefix^(snoc i.candidates %hoon)
  ?:  (exists candidate)  `candidate
  $(candidates t.candidates)
::
++  segments
  |=  suffix=@tas
  ^-  (list path)
  =/  parser
    (most hep (cook crip ;~(plug ;~(pose low nud) (star ;~(pose low nud)))))
  =/  torn=(list @tas)  (fall (rush suffix parser) ~[suffix])
  %-  flop
  |-  ^-  (list (list @tas))
  ?~  torn  ~
  ?:  ?=([@ ~] torn)
    ~[torn]
  %-  zing
  %+  turn  $(torn t.torn)
  |=  s=(list @tas)
  ^-  (list (list @tas))
  ?~  s  ~
  ~[[i.torn s] [(crip "{(trip i.torn)}-{(trip i.s)}") t.s]]
::
::  +parse-pile: Clay's prelude parser, copied without Ford/cache state.
::
++  parse-pile
  |=  [target=path source=@t]
  ^-  (each pile:clay tang)
  =/  [=hair result=(unit [parsed=pile:clay =nail])]
    %-  road  |.
    =>  [pile-rule=pile-rule target=target source=source trip=trip]
    ((pile-rule target) [1 1] (trip source))
  ?^  result  [%.y parsed.u.result]
  =/  line=@ud  p.hair
  =/  column=@ud  q.hair
  :-  %.n
  :~  leaf+"syntax error at [{<line>} {<column>}] in {<target>}"
    =/  lines=wain  (to-wain:format source)
    ?:  (gth line (lent lines))
      '<<end of file>>'
    (snag (dec line) lines)
    leaf+(runt [(dec column) '-'] "^")
  ==
::
++  pile-rule
  =>  ..lull
  =,  clay
  |=  pax=path
  %-  full
  %+  ifix
    :_  gay
    ::  parse optional /? and ignore
    ::
    ;~(plug gay (punt ;~(plug fas wut gap dem gap)))
  |^
  ;~  plug
    %+  cook  (bake zing (list (list taut)))
    %+  rune  hep
    (most ;~(plug com gaw) taut-rule)
  ::
    %+  cook  (bake zing (list (list taut)))
    %+  rune  lus
    (most ;~(plug com gaw) taut-rule)
  ::
    %+  rune  tis
    ;~(plug sym ;~(pfix gap stap))
  ::
    %+  rune  sig
    ;~((glue gap) sym wyde:vast stap)
  ::
    %+  rune  cen
    ;~(plug sym ;~(pfix gap ;~(pfix cen sym)))
  ::
    %+  rune  buc
    ;~  (glue gap)
      sym
      ;~(pfix cen sym)
      ;~(pfix cen sym)
    ==
  ::
    %+  rune  tar
    ;~  (glue gap)
      sym
      ;~(pfix cen sym)
      ;~(pfix stap)
    ==
  ::
    %+  stag  %tssg
    (most gap tall:(vang & pax))
  ==
  ::
  ++  pant
    |*  fel=^rule
    ;~(pose fel (easy ~))
  ::
  ++  mast
    |*  [bus=^rule fel=^rule]
    ;~(sfix (more bus fel) bus)
  ::
  ++  rune
    |*  [bus=^rule fel=^rule]
    %-  pant
    %+  mast  gap
    ;~(pfix fas bus gap fel)
  ::
  ++  taut-rule
    %+  cook  |=(taut +<)
    ;~  pose
      (stag ~ ;~(pfix tar sym))
      ;~(plug (stag ~ sym) ;~(pfix tis sym))
      (cook |=(a=term [`a a]) sym)
    ==
  --
--
