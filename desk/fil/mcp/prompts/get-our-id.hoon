/-  mcp
^-  prompt:mcp
:*  'Get Our Urbit ID'
    'mcp/get-our-id'
    'Retrieve the Urbit ID (@p) of this ship'
    ~
    ~
    |=  args=(map name:argument:prompt:mcp @t)
    ^-  (list message:prompt:mcp)
    :~  :-  %user
        :-  %text
        %-  some
        '''
        Use your get-our-id tool to get the Urbit ID of this ship.
        '''
    ==
==
