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
        ==
      %+  welp
        ?~  title.resource
          ~
        :~  ['title' s+u.title.resource]
        ==
      %+  welp
        ?~  desc.resource
          ~
        :~  ['description' s+u.desc.resource]
        ==
      %+  welp
        ?~  mime-type.resource
          ~
        :~  ['mimeType' s+u.mime-type.resource]
        ==
      ?~  size.resource
        ~
      :~  ['size' n+(scot %ud u.size.resource)]
      ==
  ==
  --
++  grab
  |%
  ++  noun  ,(list resource:mcp)
  --
--
