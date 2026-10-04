::  url-utils: HTTP URL origins and percent encoding
::
|%
++  percent-encode
  |=  raw=@t
  ^-  @t
  =/  chars=tape  (trip raw)
  =/  out=tape  ~
  |-
  ?~  chars
    (crip out)
  =/  c=@tD  i.chars
  ?:  (url-unreserved c)
    $(chars t.chars, out (snoc out c))
  $(chars t.chars, out (weld out (percent-byte c)))
::
++  url-unreserved
  |=  c=@
  ^-  ?
  ?|  &((gte c 'a') (lte c 'z'))
      &((gte c 'A') (lte c 'Z'))
      &((gte c '0') (lte c '9'))
      =(c '-')
      =(c '.')
      =(c '_')
      =(c '~')
  ==
::
++  percent-byte
  |=  c=@
  ^-  tape
  :~  '%'
      (hex-char (div c 16))
      (hex-char (mod c 16))
  ==
::
++  hex-char
  |=  n=@ud
  ^-  @tD
  ?:  (lth n 10)
    `@tD`(add '0' n)
  `@tD`(add 'A' (sub n 10))
::
++  get-base-url
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  =/  scheme-mark=(unit @ud)  (find "://" t)
  ?~  scheme-mark  url
  =/  after-scheme=@ud  (add 3 u.scheme-mark)
  =/  rest=tape  (slag after-scheme t)
  =/  path-start=(unit @ud)  (find "/" rest)
  ?~  path-start  url
  (crip (scag (add after-scheme u.path-start) t))
--
