^?
|%
::  $header: a single HTTP header key-value pair
::
+$  header  [k=@t v=@t]
::  +header-list: an ordered list of http headers
::
+$  header-list
(list [key=@t value=@t])
::  +method: exhaustive list of http verbs
::
+$  method
$?  %'CONNECT'
    %'DELETE'
    %'GET'
    %'HEAD'
    %'OPTIONS'
    %'PATCH'
    %'POST'
    %'PUT'
    %'TRACE'
==
::  $octs: length in bytes and payload
::
+$  octs  [p=@ q=@]
::  +to-octs: convert an atom to octs
::
++  to-octs
  |=  bod=@
  ^-  (unit octs)
  =/  len  (met 3 bod)
  ?:  =(len 0)  ~
  `[len bod]
::  $cause: the cause of an HTTP event
::
+$  cause
  $:  %req
      id=@
      uri=@t
      =method
      headers=(list header)
      body=(unit octs)
  ==
::  $effect: the result of an HTTP event
::
+$  effect
  $:  %res
      id=@
      status=@ud
      headers=(list header)
      body=(unit octs)
  ==
::  +request: a single http request
::
+$  request
$:  ::  method: http method
    ::
    method=method
    ::  url: the url requested
    ::
    ::    The url is not escaped. There is no escape.
    ::
    url=@t
    ::  header-list: headers to pass with this request
    ::
    =header-list
    ::  body: optionally, data to send with this request
    ::
    body=(unit octs)
==
::  +response-header: the status code and header list on an http request
::
::    We separate these away from the body data because we may not wait for
::    the entire body before we send a %progress to the caller.
::
+$  response-header
$:  ::  status: http status code
    ::
    status-code=@ud
    ::  headers: http headers
    ::
    headers=header-list
==
::  +http-event: packetized http
::
::    Urbit treats Earth's HTTP servers as pipes, where Urbit sends or
::    receives one or more %http-events. The first of these will always be a
::    %start or an %error, and the last will always be %cancel or will have
::    :complete set to %.y to finish the connection.
::
::    Calculation of control headers such as 'Content-Length' or
::    'Transfer-Encoding' should be performed at a higher level; this structure
::    is merely for what gets sent to or received from Earth.
::
+$  http-event
$%  ::  %start: the first packet in a response
    ::
    $:  %start
        ::  response-header: first event information
        ::
        =response-header
        ::  data: data to pass to the pipe
        ::
        data=(unit octs)
        ::  whether this completes the request
        ::
        complete=?
    ==
    ::  %continue: every subsequent packet
    ::
    $:  %continue
        ::  data: data to pass to the pipe
        ::
        data=(unit octs)
        ::  complete: whether this completes the request
        ::
        complete=?
    ==
    ::  %cancel: represents unsuccessful termination
    ::
    [%cancel ~]
==
::  +get-header: returns the value for :header, if it exists in :header-list
::
++  get-header
|=  [header=@t =header-list]
^-  (unit @t)
::
?~  header-list
    ~
::
?:  =(key.i.header-list header)
    `value.i.header-list
::
$(header-list t.header-list)
::  +set-header: sets the value of an item in the header list
::
::    This adds to the end if it doesn't exist.
::
++  set-header
|=  [header=@t value=@t =header-list]
^-  ^header-list
::
?~  header-list
    ::  we didn't encounter the value, add it to the end
    ::
    [[header value] ~]
::
?:  =(key.i.header-list header)
    [[header value] t.header-list]
::
[i.header-list $(header-list t.header-list)]
::  +delete-header: removes the first instance of a header from the list
::
++  delete-header
|=  [header=@t =header-list]
^-  ^header-list
::
?~  header-list
    ~
::  if we see it in the list, remove it
::
?:  =(key.i.header-list header)
    t.header-list
::
[i.header-list $(header-list t.header-list)]
::  +unpack-header: parse header field values
::
++  unpack-header
|^  |=  value=@t
    ^-  (unit (list (map @t @t)))
    (rust (cass (trip value)) values)
::
++  values
    %+  more
    (ifix [. .]:(star ;~(pose ace (just '\09'))) com)
    pairs
::
++  pairs
    %+  cook
    ~(gas by *(map @t @t))
    %+  most  (ifix [. .]:(star ace) mic)
    ;~(plug token ;~(pose ;~(pfix tis value) (easy '')))
::
++  value
    ;~(pose token quoted-string)
::
++  token                                         ::  7230 token
    %+  cook  crip
    ::NOTE  this is ptok:de-purl:html, but can't access that here
    %-  plus
    ;~  pose
    aln  zap  hax  buc  cen  pam  soq  tar  lus
    hep  dot  ket  cab  tic  bar  sig
    ==
::
++  quoted-string                                 ::  7230 quoted string
    %+  cook  crip
    %+  ifix  [. .]:;~(less (jest '\\"') doq)
    %-  star
    ;~  pose
    ;~(pfix bas ;~(pose (just '\09') ace prn))
    ;~(pose (just '\09') ;~(less (mask "\22\5c\7f") (shim 0x20 0xff)))
    ==
--
::  +simple-payload: a simple, one event response used for generators
::
+$  simple-payload
  $:  ::  response-header: status code, etc
      ::
      =response-header
      ::  data: the data returned as the body
      ::
      data=(unit octs)
  ==
::  JSON interaction helpers
::                                                    ::  ++enjs:format
++  enjs  ^?                                          ::  json encoders
  |%
  ::                                                  ::  ++frond:enjs:format
  ++  frond                                           ::  object from k-v pair
      |=  [p=@t q=json]
      ^-  json
      [%o [[p q] ~ ~]]
  ::                                                  ::  ++pairs:enjs:format
  ++  pairs                                           ::  object from k-v list
      |=  a=(list [p=@t q=json])
      ^-  json
      [%o (~(gas by *(map @t json)) a)]
  ::                                                  ::  ++tape:enjs:format
  ++  tape                                            ::  string from tape
      |=  a=^tape
      ^-  json
      [%s (crip a)]
  ::                                                  ::  ++wall:enjs:format
  :: ++  wall                                            ::  string from wall
  ::     |=  a=^wall
  ::     ^-  json
  ::     (tape (of-wall a))
  ::                                                  ::  ++ship:enjs:format
  ++  ship                                            ::  string from ship
      |=  a=^ship
      ^-  json
      [%n (rap 3 '"' (rsh [3 1] (scot %p a)) '"' ~)]
  ::                                                  ::  ++numb:enjs:format
  ++  numb                                            ::  number from unsigned
      |=  a=@u
      ^-  json
      :-  %n
      ?:  =(0 a)  '0'
      %-  crip
      %-  flop
      |-  ^-  ^tape
      ?:(=(0 a) ~ [(add '0' (mod a 10)) $(a (div a 10))])
  ::                                                  ::  ++sect:enjs:format
  :: ++  sect                                            ::  s timestamp
  ::     |=  a=^time
  ::     (numb (unt:chrono:userlib a))
  :: ::                                                  ::  ++time:enjs:format
  :: ++  time                                            ::  ms timestamp
  ::     |=  a=^time
  ::     (numb (unm:chrono:userlib a))
  ::                                                  ::  ++path:enjs:format
  ++  path                                            ::  string from path
      |=  a=^path
      ^-  json
      [%s (spat a)]
  ::                                                  ::  ++tank:enjs:format
  ++  tank                                            ::  tank as string arr
      |=  a=^tank
      ^-  json
      [%a (turn (wash [0 80] a) tape)]
  --  ::enjs
::                                                    ::  ++dejs:format
++  dejs                                              ::  json reparser
  =>  |%  ++  grub  *                                 ::  result
          ++  fist  $-(json grub)                     ::  reparser instance
      --  ::
  |%
  ::                                                  ::  ++ar:dejs:format
  ++  ar                                              ::  array as list
      |*  wit=fist
      |=  jon=json  ^-  (list _(wit *json))
      ?>  ?=([%a *] jon)
      (turn p.jon wit)
  ::                                                  ::  ++as:dejs:format
  ++  as                                              ::  array as set
      |*  a=fist
      (cu ~(gas in *(set _$:a)) (ar a))
  ::                                                  ::  ++at:dejs:format
  ++  at                                              ::  array as tuple
      |*  wil=(pole fist)
      |=  jon=json
      ?>  ?=([%a *] jon)
      ((at-raw wil) p.jon)
  ::                                                  ::  ++at-raw:dejs:format
  ++  at-raw                                          ::  array as tuple
      |*  wil=(pole fist)
      |=  jol=(list json)
      ?~  jol  !!
      ?-    wil                                         :: mint-vain on empty
          :: [wit=* t=*]
          [* t=*]
      =>  .(wil [wit *]=wil)
      ?~  t.wil  ?^(t.jol !! (wit.wil i.jol))
      [(wit.wil i.jol) ((at-raw t.wil) t.jol)]
      ==
  ::                                                  ::  ++bo:dejs:format
  ++  bo                                              ::  boolean
      |=(jon=json ?>(?=([%b *] jon) p.jon))
  ::                                                  ::  ++bu:dejs:format
  ++  bu                                              ::  boolean not
      |=(jon=json ?>(?=([%b *] jon) !p.jon))
  ::                                                  ::  ++ci:dejs:format
  ++  ci                                              ::  maybe transform
      |*  [poq=gate wit=fist]
      |=  jon=json
      (need (poq (wit jon)))
  ::                                                  ::  ++cu:dejs:format
  ++  cu                                              ::  transform
      |*  [poq=gate wit=fist]
      |=  jon=json
      (poq (wit jon))
  :: ::                                                  ::  ++di:dejs:format
  :: ++  di                                              ::  millisecond date
  ::     (cu from-unix-ms:chrono:userlib ni)
  :: ::                                                  ::  ++du:dejs:format
  :: ++  du                                              ::  second date
  ::     (cu from-unix:chrono:userlib ni)
  ::                                                  ::  ++mu:dejs:format
  ++  mu                                              ::  true unit
      |*  wit=fist
      |=  jon=json
      ?~(jon ~ (some (wit jon)))
  ::                                                  ::  ++ne:dejs:format
  :: ++  ne                                              ::  number as real
  ::     |=  jon=json
  ::     ^-  @rd
  ::     ?>  ?=([%n *] jon)
  ::     (rash p.jon (cook ryld (cook royl-cell:^so json-rn)))
  ::                                                  ::  ++ni:dejs:format
  ++  ni                                              ::  number as integer
      |=  jon=json
      ?>  ?=([%n *] jon)
      (rash p.jon dem)
  ::                                                  ::  ++ns:dejs:format
  ++  ns                                              ::  number as signed
      |=  jon=json
      ^-  @s
      ?>  ?=([%n *] jon)
      %+  rash  p.jon
      %+  cook  new:si
      ;~(plug ;~(pose (cold %| (jest '-')) (easy %&)) dem)
  ::                                                  ::  ++no:dejs:format
  ++  no                                              ::  number as cord
      |=(jon=json ?>(?=([%n *] jon) p.jon))
  ::                                                  ::  ++nu:dejs:format
  ++  nu                                              ::  parse number as hex
      |=  jon=json
      ?>  ?=([%s *] jon)
      (rash p.jon hex)
  ::                                                  ::  ++of:dejs:format
  ++  of                                              ::  object as frond
      |*  wer=(pole [cord fist])
      |=  jon=json
      ?>  ?=([%o [@ *] ~ ~] jon)
      |-
      ?-    wer                                         :: mint-vain on empty
          :: [[key=@t wit=*] t=*]
          [[key=@t *] t=*]
      =>  .(wer [[* wit] *]=wer)
      ?:  =(key.wer p.n.p.jon)
          [key.wer ~|(key+key.wer (wit.wer q.n.p.jon))]
      ?~  t.wer  ~|(bad-key+p.n.p.jon !!)
      ((of t.wer) jon)
      ==
  ::                                                  ::  ++ot:dejs:format
  ++  ot                                              ::  object as tuple
      |*  wer=(pole [cord fist])
      |=  jon=json
      ?>  ?=([%o *] jon)
      ((ot-raw wer) p.jon)
  ::                                                  ::  ++ot-raw:dejs:format
  ++  ot-raw                                          ::  object as tuple
      |*  wer=(pole [cord fist])
      |=  jom=(map @t json)
      ?-    wer                                         :: mint-vain on empty
          :: [[key=@t wit=*] t=*]
          [[key=@t *] t=*]
      =>  .(wer [[* wit] *]=wer)
      =/  ten  ~|(key+key.wer (wit.wer (~(got by jom) key.wer)))
      ?~(t.wer ten [ten ((ot-raw t.wer) jom)])
      ==
  ::
  ++  ou                                              ::  object of units
      |*  wer=(pole [cord fist])
      |=  jon=json
      ?>  ?=([%o *] jon)
      ((ou-raw wer) p.jon)
  ::                                                  ::  ++ou-raw:dejs:format
  ++  ou-raw                                          ::  object of units
      |*  wer=(pole [cord fist])
      |=  jom=(map @t json)
      ?-    wer                                         :: mint-vain on empty
          :: [[key=@t wit=*] t=*]
          [[key=@t *] t=*]
      =>  .(wer [[* wit] *]=wer)
      =/  ten  ~|(key+key.wer (wit.wer (~(get by jom) key.wer)))
      ?~(t.wer ten [ten ((ou-raw t.wer) jom)])
      ==
  ::                                                  ::  ++oj:dejs:format
  ++  oj                                              ::  object as jug
      |*  =fist
      ^-  $-(json (jug cord _(fist *json)))
      (om (as fist))
  ::                                                  ::  ++om:dejs:format
  ++  om                                              ::  object as map
      |*  wit=fist
      |=  jon=json
      ?>  ?=([%o *] jon)
      (~(run by p.jon) wit)
  ::                                                  ::  ++op:dejs:format
  ++  op                                              ::  parse keys of map
      |*  [fel=rule wit=fist]
      |=  jon=json  ^-  (map _(wonk *fel) _*wit)
      =/  jom  ((om wit) jon)
      %-  malt
      %+  turn  ~(tap by jom)
      |*  [a=cord b=*]
      =>  .(+< [a b]=+<)
      [(rash a fel) b]
  ::                                                  ::  ++pa:dejs:format
  ++  pa                                              ::  string as path
      (su stap)
  ::                                                  ::  ++pe:dejs:format
  ++  pe                                              ::  prefix
      |*  [pre=* wit=fist]
      (cu |*(* [pre +<]) wit)
  ::                                                  ::  ++sa:dejs:format
  ++  sa                                              ::  string as tape
      |=(jon=json ?>(?=([%s *] jon) (trip p.jon)))
  ::                                                  ::  ++sd:dejs:format
  ++  sd                                              ::  string @ud as date
      |=  jon=json
      ^-  @da
      ?>  ?=(%s -.jon)
      `@da`(rash p.jon dem:ag)
  ::                                                  ::  ++se:dejs:format
  ++  se                                              ::  string as aura
      |=  aur=@tas
      |=  jon=json
      ?>(?=([%s *] jon) (slav aur p.jon))
  ::                                                  ::  ++so:dejs:format
  ++  so                                              ::  string as cord
      |=(jon=json ?>(?=([%s *] jon) p.jon))
  ::                                                  ::  ++su:dejs:format
  ++  su                                              ::  parse string
      |*  sab=rule
      |=  jon=json  ^+  (wonk *sab)
      ?>  ?=([%s *] jon)
      (rash p.jon sab)
  ::                                                  ::  ++uf:dejs:format
  ++  uf                                              ::  unit fall
      |*  [def=* wit=fist]
      |=  jon=(unit json)
      ?~(jon def (wit u.jon))
  ::                                                  ::  ++un:dejs:format
  ++  un                                              ::  unit need
      |*  wit=fist
      |=  jon=(unit json)
      (wit (need jon))
  ::                                                  ::  ++ul:dejs:format
  ++  ul                                              ::  null
      |=(jon=json ?~(jon ~ !!))
  ::
  ++  za                                              ::  full unit pole
      |*  pod=(pole (unit))
      ?~  pod  &
      ?~  -.pod  |
      (za +.pod)
  ::
  ++  zl                                              ::  collapse unit list
      |*  lut=(list (unit))
      ?.  |-  ^-  ?
          ?~(lut & ?~(i.lut | $(lut t.lut)))
      ~
      %-  some
      |-
      ?~  lut  ~
      [i=u:+.i.lut t=$(lut t.lut)]
  ::
  ++  zp                                              ::  unit tuple
      |*  but=(pole (unit))
      ?~  but  !!
      ?~  +.but
      u:->.but
      [u:->.but (zp +.but)]
  ::
  ++  zm                                              ::  collapse unit map
      |*  lum=(map term (unit))
      ?:  (~(rep by lum) |=([[@ a=(unit)] b=_|] |(b ?=(~ a))))
      ~
      (some (~(run by lum) need))
  --  ::dejs
::
+$  json                                                ::  normal json value
  $@  ~                                                 ::  null
  $%  [%a p=(list json)]                                ::  array
      [%b p=?]                                          ::  boolean
      [%o p=(map @t json)]                              ::  object
      [%n p=@ta]                                        ::  number
      [%s p=@t]                                         ::  string
  ==                                                    ::
--