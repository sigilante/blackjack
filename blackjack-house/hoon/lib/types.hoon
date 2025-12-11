/=  transact  /common/tx-engine
::
|%
::
+$  cause
  $%  [%tx-sent tx-hash=@t]
      [%tx-fail error=@t]
  ==
::
+$  effect
  $%
    $:  %tx
        %send
        src-pkh=@
        src-privkey=@
        src-first-name=*
        trg-pkh=@
        amount=@
    ==
    [%exit ~]
  ==
::
--
