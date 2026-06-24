/-  mcp
|_  templates=(list template:resource:mcp)
++  grad  %noun
++  grow
  |%
  ++  noun  templates
  ++  json
  %-  pairs:enjs:format
  :~  :-  'resourceTemplates'
      :-  %a
      %+  turn
        templates
      |=  =template:resource:mcp
      %-  pairs:enjs:format
      %+  welp
        :~  ['uriTemplate' s+uri-template.template]
            ['name' s+name.template]
        ==
      %+  welp
        ?~  title.template
          ~
        :~  ['title' s+u.title.template]
        ==
      %+  welp
        ?~  desc.template
          ~
        :~  ['description' s+u.desc.template]
        ==
      %+  welp
        ?~  mime-type.template
          ~
        :~  ['mimeType' s+u.mime-type.template]
        ==
      ?~  size.template
        ~
      :~  ['size' n+(scot %ud u.size.template)]
      ==
  ==
  --
++  grab
  |%
  ++  noun  ,(list template:resource:mcp)
  --
--
