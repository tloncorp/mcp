/-  mcp
|_  resources=(list resource:mcp)
++  grad  %noun
++  grow
  |%
  ++  noun  resources
  ++  json
  %-  pairs:enjs:format
  :~  :-  'resources'
      :-  %a
      %+  turn
        resources
      |=  =resource:mcp
      %-  pairs:enjs:format
      %+  welp
        :~  ['uri' s+uri.resource]
            ['name' s+name.resource]
            ['description' s+desc.resource]
        ==
      ?~  mime-type.resource
        ~
      :~  ['mimeType' s+u.mime-type.resource]
      ==
  ==
  --
++  grab
  |%
  ++  noun  ,(list resource:mcp)
  --
--
