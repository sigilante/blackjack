::  blackjack/app/blackjack.hoon
::  Browser-based blackjack game served as a NockApp
::
/-  *blackjack
/+  default-agent, dbug, server, static=blackjack-static
::
|%
+$  versioned-state
  $%  state-0
  ==
::
+$  state-0
  $:  %0
      ::  For Phase 1, no server-side game state needed
      ::  All game logic is in JavaScript
  ==
::
+$  card  card:agent:gall
--
::
%-  agent:dbug
=|  state-0
=*  state  -
::
^-  agent:gall
|_  =bowl:gall
+*  this     .
    default  ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  :_  this
  :~  [%pass /bind %arvo %e %connect [~ /blackjack] %blackjack]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?>  ?=(%handle-http-request mark)
  =/  req  !<([@ta inbound-request:eyre] vase)
  =/  request-line  (parse-request-line url.request.req)
  ?+    method.request.req
    ::  Method not allowed
    :_  this
    :~  (give-simple-payload:app:server req [405 ~] ~)
    ==
  ::
    %'GET'
    ?+    site.request-line
      ::  404 for unknown paths
      :_  this
      :~  (give-simple-payload:app:server req [404 ~] ~)
      ==
    ::
      [%blackjack ~]
      ::  Serve index.html
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            :-  200
            :~  ['Content-Type' 'text/html']
            ==
          `(as-octs:mimes:html index-html:static)
      ==
    ::
      [%blackjack %style.css ~]
      ::  Serve CSS
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            :-  200
            :~  ['Content-Type' 'text/css']
            ==
          `(as-octs:mimes:html style-css:static)
      ==
    ::
      [%blackjack %game.js ~]
      ::  Serve JavaScript
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            :-  200
            :~  ['Content-Type' 'application/javascript']
            ==
          `(as-octs:mimes:html game-js:static)
      ==
    ::
      [%blackjack %img %sprites.png ~]
      ::  Serve sprite image
      ::  For Phase 1, this is a placeholder
      ::  You'll need to either:
      ::  1. Load from desk using scry
      ::  2. Embed as base64-encoded cord
      ::  3. Serve from external URL (temporary)
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            :-  200
            :~  ['Content-Type' 'image/png']
            ==
          ::  Placeholder - replace with actual PNG data
          `[p=0 q=sprites-png:static]
      ==
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?>  ?=([%http-response *] path)
  [~ this]
::
++  on-leave  on-leave:default
++  on-peek   on-peek:default
++  on-agent  on-agent:default
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?.  ?=([%bind ~] wire)
    (on-arvo:default wire sign-arvo)
  ?.  ?=([%eyre %bound *] sign-arvo)
    (on-arvo:default wire sign-arvo)
  ~?  !accepted.sign-arvo
    [%eyre-rejected-binding binding.sign-arvo]
  [~ this]
::
++  on-fail   on-fail:default
--
