::  API annotations derived from the dispatch operation and operator policy.
::
/+  api-tools, jut=json-utils
|%
++  configured-tools
  |=  [spec=json operator-url=@t allowed-posts=(set @t)]
  ^-  (list json)
  %+  turn  (spec-to-tools:api-tools spec)
  |=  tool=json
  ^-  json
  ?.  ?=(%o -.tool)  tool
  ::  Use the same lookup as dispatch, including for duplicate operation IDs.
  =/  op=(unit [path=@t method=@t operation=json])
    (find-operation:api-tools spec (get-json-string:jut tool 'name'))
  =/  read-only=?
    ?~  op  %.n
    ?:  =('get' (normalize-method:api-tools method.u.op))  %.y
    (allowed-post spec operator-url allowed-posts u.op)
  =/  annotations=json
    (pairs:enjs:format ~[['readOnlyHint' b+read-only]])
  [%o (~(put by p.tool) 'annotations' annotations)]
::
++  allowed-post
  |=  $:  spec=json
          operator-url=@t
          allowed-posts=(set @t)
          op=[path=@t method=@t operation=json]
      ==
  ^-  ?
  ?.  =('post' (normalize-method:api-tools method.op))  %.n
  ?:  =('' operator-url)  %.n
  ::  A spec must not add its own base path or choose a different host.
  ?.  =(operator-url (resolve-base-url:api-tools spec operator-url))  %.n
  ?.  (fixed-path path.op)  %.n
  =/  endpoint=@t  (build-api-url:api-tools operator-url path.op [%o ~])
  (~(has in allowed-posts) endpoint)
::
++  fixed-path
  |=  path=@t
  ^-  ?
  ?:  =('' path)  %.n
  =/  chars=tape  (trip path)
  ::  Exclude templates, escapes, queries, fragments and alternate origins.
  ::  The resulting fixed endpoint is compared byte-for-byte with policy.
  %+  levy  chars
  |=  char=@
  ?|  &((gte char 'a') (lte char 'z'))
      &((gte char 'A') (lte char 'Z'))
      &((gte char '0') (lte char '9'))
      =(char '/')
      =(char '-')
      =(char '_')
      =(char '.')
      =(char '~')
  ==
--
