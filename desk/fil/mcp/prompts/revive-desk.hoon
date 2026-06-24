/-  mcp
^-  prompt:mcp
:*  'Revive desk'
    'mcp/revive-desk'
    '''
    Boot the agents on a nuked / suspended desk.
    '''
    :~  :*  'desk'
            'Desk name to revive (e.g. "hark" to revive %hark)'
            &
        ==
    ==
    ~
    |=  args=(map name:argument:prompt:mcp @t)
    ^-  (list message:prompt:mcp)
    =/  desk  (~(get by args) 'desk')
    :~  :-  %user
        :-  %text
        %-  some
        ?~  desk
         '''
         Use your revive-desk tool to revive the desk we're working on.
         '''
        %-  crip
        """
        Use your revive-desk tool to revive %{(trip u.desk)}.
        """
    ==
==
