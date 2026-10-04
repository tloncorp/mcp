::  http-utils: request headers and Eyre response cards
::
/+  server
|%
++  api-key
  |=  headers=(list [key=@t value=@t])
  ^-  (unit @t)
  |-
  ?~  headers  ~
  ?:  =((cass (trip key.i.headers)) "x-api-key")  `value.i.headers
  $(headers t.headers)
::
++  give-http
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server  eyre-id
  [[status headers] body]
::
++  give-json
  |=  [eyre-id=@ta jon=json]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server  eyre-id
  (json-response:gen:server jon)
--
