/-  mcp
|_  tools=(list tool:mcp)
++  grad  %noun
++  grow
  |%
  ++  noun  tools
  ++  json
  %-  pairs:enjs:format
  :~  :-  'tools'
      :-  %a
      %+  turn
        tools
      |=  =tool:mcp
      %-  pairs:enjs:format
      :~  ['name' [%s name.tool]]
          ['description' [%s desc.tool]]
          :-  'inputSchema'
          %-  pairs:enjs:format
          :~  ['type' [%s 'object']]
              :-  'properties'
              :-  %o
              %-  ~(run by parameters.tool)
              |=  =def:parameter:tool:mcp
              %-  pairs:enjs:format
              :~  ['type' s+type.def]
                  ['description' s+desc.def]
              ==
              :-  'required'
              :-  %a
              %+  turn
                required.tool
              |=  f=@t
              s+f
  ==  ==  ==
  --
++  grab
  |%
  ++  noun  ,(list tool:mcp)
  --
--
