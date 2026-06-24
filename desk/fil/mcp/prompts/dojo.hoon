/-  mcp
^-  prompt:mcp
:*  'Dojo command'
    'mcp/dojo'
    '''
    Run the given command in the Dojo
    '''
    :~  :*  'command'
            'Command to run'
            &
        ==
    ==
    ~
    |=  args=(map name:argument:prompt:mcp @t)
    ^-  (list message:prompt:mcp)
    =/  com  (~(got by args) 'command')
    :~  :-  %user
        :-  %text
        %-  some
        %-  crip
        """
        Run this command in the Dojo: {(trip com)}
        """
    ==
==
