/+  txt=types
/=  transact  /common/tx-engine
/=  *  /common/wrapper
::
=>
|%
::
+$  versioned-state
  $:  %v1
      ~
  ==
::
--
|%
++  moat  (keep versioned-state)
::
++  inner
  |_  state=versioned-state
  ::
  ++  load
    |=  old-state=versioned-state
    ^-  _state
    ?:  =(-.old-state %v1)
      old-state
    old-state
  ::
  ++  peek
    |=  =path
    ^-  (unit (unit *))
    ~>  %slog.[0 'Peeks awaiting implementation']
    ~
  ::
  ++  poke
    |=  =ovum:moat
    ^-  [(list effect:txt) _state]
    ~>  %slog.[1 (crip "Poke received with ovum {<cause.input.ovum>}")]
    =/  cause  ((soft cause:txt) cause.input.ovum)
    ?~  cause
      ~>  %slog.[3 (crip "invalid cause {<cause.input.ovum>}")]
      !!
    ?:  ?=([%cause ~] u.cause)
      ~>  %slog.[1 'No-op cause received; emitting base TX effect']
      :_  state
      ^-  (list effect:txt)
      :~  :*  %tx
              %send
              src-pkh='9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV'
              src-privkey='7VnoWdeQBFLxQAwwqmWnjY4tN6MjKFXRZivPje9t2iRT'
              src-first-name=(simple:v1:first-name:transact (from-b58:hash:transact '9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV'))
              trg-pkh='9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV'
              amount='32768'
      ==  ==
    ?:  ?=([%tx-sent tx-hash=@] u.cause)
      ~>  %slog.[2 (crip "Transaction sent successfully with hash {<`@t`tx-hash.u.cause>}")]
      :_  state
      ^-  (list effect:txt)
      :~  [%exit ~]
      ==
    ?>  ?=([%tx-fail error=@t] u.cause)
      ~>  %slog.[3 (crip "Transaction failed with error {<`@t`error.u.cause>}")]
      :_  state
      ^-  (list effect:txt)
      :~  [%exit ~]
      ==
  --
--
((moat |) inner)
