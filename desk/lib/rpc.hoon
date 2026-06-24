/-  *json-rpc
|%
++  rpc
  |%
  ++  make-response
    |=  res=response
    ^-  json
    ?-    -.res
        %result
      %-  pairs:enjs:format
      :~  ['id' n+id.res]
          ['jsonrpc' s+'2.0']
          ['result' result.res]
      ==
    ::
        %error
      %-  pairs:enjs:format
      :~  ['id' n+id.res]
          ['jsonrpc' s+'2.0']
          :-  'error'
          %-  pairs:enjs:format
          %+  welp
            :~  ['code' n+code.res]
                ['message' s+message.res]
            ==
          ?~  data.res
            ~
          :~  ['data' u.data.res]
          ==
      ==
    ==
  ++  result
    |=  [id=@t res=json]
    (make-response [%result id res])
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
    ++  parse
      |=  [id=@ta message=@t data=(unit json)]
      (make-response [%error id parse-error:code message data])
    ++  request
      |=  [id=@ta message=@t data=(unit json)]
      (make-response [%error id invalid-request:code message data])
    ++  method
      |=  [id=@ta message=@t data=(unit json)]
      (make-response [%error id method-not-found:code message data])
    ++  params
      |=  [id=@ta message=@t data=(unit json)]
      (make-response [%error id invalid-params:code message data])
    ++  internal
      |=  [id=@ta message=@t data=(unit json)]
      (make-response [%error id internal-error:code message data])
    --
  --
--
