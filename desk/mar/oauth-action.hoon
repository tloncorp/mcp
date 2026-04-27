::  oauth-action: mark for oauth agent actions
::
/-  oauth
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
      =/  f
        %-  ot
        :~  id+so
            auth-url+so
            token-url+so
            revoke-url+(mu so)
            client-id+so
            client-secret+so
            redirect-uri+so
            scopes+so
        ==
      =/  [id=@t auth-url=@t token-url=@t revoke-url=(unit @t) client-id=@t client-secret=@t redirect-uri=@t scopes=@t]
        (f jon)
      =/  token-resource=(unit @t)
        =/  val=(unit json)  (~(get by p.jon) 'token-resource')
        ?~  val  ~
        ?.  ?=(%s -.u.val)  ~
        ?:  =('' p.u.val)  ~
        `p.u.val
      =/  token-auth=token-auth-mode:oauth
        =/  val=(unit json)  (~(get by p.jon) 'token-auth')
        ?~  val  %basic
        ?.  ?=(%s -.u.val)  %basic
        ?:  =('body' p.u.val)  %body
        %basic
      [%add-provider `@tas`id [auth-url token-url revoke-url client-id client-secret redirect-uri scopes token-resource token-auth]]
    ::
        %'remove-provider'
      [%remove-provider `@tas`((ot ~[id+so]) jon)]
    ::
        %'update-provider'
      =/  f
        %-  ot
        :~  id+so
            auth-url+so
            token-url+so
            revoke-url+(mu so)
            client-id+so
            client-secret+so
            redirect-uri+so
            scopes+so
        ==
      =/  [id=@t auth-url=@t token-url=@t revoke-url=(unit @t) client-id=@t client-secret=@t redirect-uri=@t scopes=@t]
        (f jon)
      =/  token-resource=(unit @t)
        =/  val=(unit json)  (~(get by p.jon) 'token-resource')
        ?~  val  ~
        ?.  ?=(%s -.u.val)  ~
        ?:  =('' p.u.val)  ~
        `p.u.val
      =/  token-auth=token-auth-mode:oauth
        =/  val=(unit json)  (~(get by p.jon) 'token-auth')
        ?~  val  %basic
        ?.  ?=(%s -.u.val)  %basic
        ?:  =('body' p.u.val)  %body
        %basic
      [%update-provider `@tas`id [auth-url token-url revoke-url client-id client-secret redirect-uri scopes token-resource token-auth]]
    ::
        %'config-provider'
      =/  f
        %-  ot
        :~  id+so
            auth-url+so
            token-url+so
            revoke-url+(mu so)
            client-id+so
            client-secret+so
            redirect-uri+so
            scopes+so
        ==
      =/  [id=@t auth-url=@t token-url=@t revoke-url=(unit @t) client-id=@t client-secret=@t redirect-uri=@t scopes=@t]
        (f jon)
      =/  token-resource=(unit @t)
        =/  val=(unit json)  (~(get by p.jon) 'token-resource')
        ?~  val  ~
        ?.  ?=(%s -.u.val)  ~
        ?:  =('' p.u.val)  ~
        `p.u.val
      =/  token-auth=token-auth-mode:oauth
        =/  val=(unit json)  (~(get by p.jon) 'token-auth')
        ?~  val  %basic
        ?.  ?=(%s -.u.val)  %basic
        ?:  =('body' p.u.val)  %body
        %basic
      [%config-provider `@tas`id [auth-url token-url revoke-url client-id client-secret redirect-uri scopes token-resource token-auth]]
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
