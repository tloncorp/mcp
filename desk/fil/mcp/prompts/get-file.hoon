/-  mcp
^-  prompt:mcp
:*  'Get file'
    'mcp/get-file'
    '''
    Fetch a Clay file on the local ship
    '''
    :~  :*  'desk'
            'The desk this file is in (Default: %base)'
            |
        ==
        :*  'case'
            'The $case (revision number or datetime) at which to access this file (Default: now)'
            |
        ==
        :*  'path'
            'The remaining filepath'
            &
        ==
    ==
    ~
    |=  args=(map name:argument:prompt:mcp @t)
    ^-  (list message:prompt:mcp)
    =/  path-str  (~(get by args) 'path')
    ?~  path-str
      ~|(%missing-path !!)
    =/  desk-str  (~(get by args) 'desk')
    =/  case-str  (~(get by args) 'case')
    =/  desk-part=tape
      ?~  desk-str  "%base"  "%{(trip u.desk-str)}"
    =/  case-part=tape
      ?~  case-str  "[now]"  "{(trip u.case-str)}"
    :~  :-  %user
        :-  %text
        %-  some
        %-  crip
        """
        Use your get-file tool to get {(trip u.path-str)}
        on the local ship in desk {desk-part} at case {case-part}.
        Use your get-file tool to retrieve it.
        """
    ==
==
