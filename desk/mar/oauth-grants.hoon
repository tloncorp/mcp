::  oauth-grants: compatibility mark
::
::    %oauth now returns /x/grants as %json directly. Keep this noun-only
::    mark so older live desks that still contain %oauth-grants can survive
::    Clay/Kelvin mark prebuilds without resolving OAuth state molds.
::
|_  val=*
++  grad  %noun
++  grow
  |%
  ++  noun  val
  --
++  grab
  |%
  ++  noun  *
  --
--
