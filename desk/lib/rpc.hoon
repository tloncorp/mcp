|%
++  rpc
  |%
  ++  result
    |=  [id=@ta result=json]
    %-  pairs:enjs:format
    :~  ['id' n+id]
        ['jsonrpc' s+'2.0']
        ['result' result]
    ==
  ++  error
    |%
    ++  code
    |%
    ++  parse-error       ~.-32700
    ++  invalid-request   ~.-32600
    ++  method-not-found  ~.-32601
    ++  invalid-params    ~.-32602
    ++  internal-error    ~.-32603
    --
    ++  make
      |=  [id=(unit @ta) code=@ta message=@t]
      ^-  json
      %-  pairs:enjs:format
      :~  ['id' n+?~(id *@ta u.id)]
          ['jsonrpc' s+'2.0']
          :-  'error'
          %-  pairs:enjs:format
          :~  ['code' n+code]
              ['message' s+message]
          ==
      ==
    ++  parse
      |=  [id=(unit @ta) message=@t]
      (make id parse-error:code message)
    ++  request
      |=  [id=(unit @ta) message=@t]
      (make id invalid-request:code message)
    ++  method
      |=  [id=(unit @ta) message=@t]
      (make id method-not-found:code message)
    ++  params
      |=  [id=(unit @ta) message=@t]
      (make id invalid-params:code message)
    ++  internal
      |=  [id=(unit @ta) message=@t]
      (make id internal-error:code message)
    --
  --
--
