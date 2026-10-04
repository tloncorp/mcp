::  mcp-json: tool results and resource content envelopes
::
/-  mcp
|%
++  as-object
  |=  jon=json
  ^-  json
  ?:  ?=([%o *] jon)  jon
  (frond:enjs:format 'data' jon)
::
++  text-content
  |=  text=@t
  ^-  json
  (pairs:enjs:format ~[['type' s+'text'] ['text' s+text]])
::
++  resource-content
  |=  [uri=@t mime=@t text=@t]
  ^-  json
  %+  frond:enjs:format  'contents'
  :-  %a
  :~  %-  pairs:enjs:format
      :~  ['uri' s+uri]
          ['mimeType' s+mime]
          ['text' s+text]
      ==
  ==
::
++  tool-result
  |=  =response:tool:mcp
  ^-  json
  ?-  -.response
      %error
    %-  pairs:enjs:format
    %+  welp
      ~[['content' a+~[(text-content message.response)]]]
    %+  welp
      ?~  data.response  ~
      ~[['structuredContent' (as-object u.data.response)]]
    ~[['isError' b+.y]]
  ::
      %result
    %-  pairs:enjs:format
    ?-  response
        [%result %structured *]
      :~  ['content' a+~[(text-content (en:json:html json.response))]]
          ['structuredContent' (as-object json.response)]
          ['isError' b+.n]
      ==
    ::
        [%result %unstructured *]
      :~  ['content' a+(turn results.response content)]
          ['isError' b+.n]
      ==
    ==
  ==
::
++  content
  |=  =result:tool:mcp
  ^-  json
  ?-  -.result
      %text
    (text-content text.result)
  ::
      %audio
    %-  pairs:enjs:format
    :~  ['type' s+'audio']
        ['data' s+data.result]
        ['mimeType' s+mime.result]
    ==
  ::
      %resource-link
    %-  pairs:enjs:format
    :~  ['type' s+'resource_link']
        ['uri' s+uri.result]
        ['name' s+name.result]
        ['description' s+desc.result]
        ['mimeType' s+mime.result]
    ==
  ::
      %image
    %-  pairs:enjs:format
    :~  ['type' s+'image']
        ['data' s+data.result]
        ['mimeType' s+mime.result]
    ==
  ::
      %resource
    %-  pairs:enjs:format
    :~  ['type' s+'resource']
        :-  'resource'
        %-  pairs:enjs:format
        :~  ['uri' s+uri.result]
            ['mimeType' s+mime.result]
            ['text' s+text.result]
        ==
    ==
  ==
::
++  clay-permission
  |=  permission=dict:clay
  ^-  json
  %-  pairs:enjs:format
  :~  ['source' s+(spat src.permission)]
      ['mode' s+(scot %tas mod.rul.permission)]
      :-  'ships'
      :-  %a
      %+  turn
        ~(tap in p.who.rul.permission)
      |=  =ship
      [%s (scot %p ship)]
      :-  'groups'
      :-  %a
      %+  turn
        ~(tap by q.who.rul.permission)
      |=  [name=@ta ships=(set ship)]
      %-  pairs:enjs:format
      :~  ['name' s+name]
          :-  'ships'
          :-  %a
          %+  turn
            ~(tap in ships)
          |=  =ship
          [%s (scot %p ship)]
      ==
  ==
--
