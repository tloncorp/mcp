/-  mcp, spider
/+  io=strandio
^-  tool:mcp
:*  'mcp/get-our-id'
  'Get the Urbit ID (@p) of this ship.'
  ~
  ~
  ^-  thread-builder:tool:mcp
  |=  *
  =/  m  (strand:spider ,vase)
  ^-  form:m
  ;<    =bowl:rand
      bind:m
    get-bowl:io
  %-  pure:m
  !>  ^-  response:tool:mcp
  :-  %result
  :-  %structured
  (frond:enjs:format %ship s+(scot %p our.bowl))
==
