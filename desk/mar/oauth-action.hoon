::  oauth-action: mark for oauth agent actions
::
/-  oauth
/+  oauth-json
|_  act=action:oauth
++  grow
  |%
  ++  noun  act
  --
++  grab
  |%
  ++  noun  action:oauth
  ++  json
    |=  jon=^json
    ^-  action:oauth
    =,  dejs:format
    =/  typ=@t  ((ot ~[action+so]) jon)
    ?>  ?=(%o -.jon)
    ?+  typ  !!
        %'add-provider'
      =/  parsed=[id=@t config=provider-config:oauth]
        (parse-provider-config:oauth-json jon)
      [%add-provider `@tas`id.parsed config.parsed]
    ::
        %'remove-provider'
      [%remove-provider `@tas`((ot ~[id+so]) jon)]
    ::
        %'update-provider'
      =/  parsed=[id=@t config=provider-config:oauth]
        (parse-provider-config:oauth-json jon)
      [%update-provider `@tas`id.parsed config.parsed]
    ::
        %'config-provider'
      =/  parsed=[id=@t config=provider-config:oauth]
        (parse-provider-config:oauth-json jon)
      [%config-provider `@tas`id.parsed config.parsed]
    ::
        %'connect'
      [%connect `@tas`((ot ~[id+so]) jon)]
    ::
        %'disconnect'
      [%disconnect `@tas`((ot ~[id+so]) jon)]
    ::
        %'revoke'
      [%revoke `@tas`((ot ~[id+so]) jon)]
    ::
        %'remote-connect'
      ?>  ?=(%o -.jon)
      =/  id-val=json  (~(got by p.jon) 'id')
      =/  rt-val=json  (~(got by p.jon) 'return-to')
      ?>  ?=(%s -.id-val)
      ?>  ?=(%s -.rt-val)
      [%remote-connect `@tas`p.id-val p.rt-val]
    ::
        %'set-relay-url'
      ?>  ?=(%o -.jon)
      =/  url-val=(unit json)  (~(get by p.jon) 'url')
      =/  url=(unit @t)
        ?~  url-val  ~
        ?.  ?=(%s -.u.url-val)  ~
        ?:  =('' p.u.url-val)  ~
        `p.u.url-val
      [%set-relay-url url]
    ==
  --
++  grad  %noun
--
