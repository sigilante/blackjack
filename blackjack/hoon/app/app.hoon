::  blackjack/app/blackjack.hoon
::  Browser-based blackjack game served as a NockApp
::
/+  http, blackjack
/=  *  /common/wrapper
::  Static resources (load as cords)
/*  index    %html   /app/site/index/html
/*  style    %css   /app/site/style/css
/*  game     %js    /app/site/game/js
/*  sprites  %png   /app/site/sprites/png
::  Application state
=>
|%
+$  server-state
  $:  %0
      ::  Map of client sessions to game state
      games=(map session-id:blackjack game-state:blackjack)
      ::  Simple counter for session IDs
      next-session-id=@ud
  ==
--
::  Application logic
=>
|%
++  moat  (keep server-state)
::
++  inner
  |_  state=server-state
  ::
  ::  +load: upgrade from previous state
  ::
  ++  load
    |=  arg=server-state
    ^-  server-state
    arg
  ::
  ::  +peek: external inspect
  ::
  ++  peek
    |=  =path
    ^-  (unit (unit *))
    ~>  %slog.[0 'Peeks awaiting implementation']
    ~
  ::
  ::  +poke: external apply
  ::
  ++  poke
    |=  =ovum:moat
    ^-  [(list effect:http) server-state]
    =/  sof-cau=(unit cause:http)  ((soft cause:http) cause.input.ovum)
    ?~  sof-cau
      ~&  "cause incorrectly formatted!"
      ~&  now.input.ovum
      !!
    ::  Parse request into components.
    =/  [id=@ uri=@t =method:http headers=(list header:http) body=(unit octs:http)]
      +.u.sof-cau
    ~&  "Received request: {<method>} {<uri>}"
    =/  uri=path  (pa:dejs:http [%s uri])
    ::  Handle GET/POST requests
    ?+    method  [~[[%res ~ %400 ~ ~]] state]
      ::
        %'GET'
      ?+    uri  [~[[%res ~ %404 ~ ~]] state]
        ::
          :: Serve index.html
          [%blackjack ~]
        :_  state
        ^-  (list effect:http)
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'text/html']
            ==
            (to-octs:http q.index)
        ==
        ::
          :: Serve style.css
          [%blackjack %'style.css' ~]
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'text/css']
            ==
            (to-octs:http q.style)
        ==
        ::
          :: Serve game.js
          [%blackjack %'game.js' ~]
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'text/javascript']
            ==
            (to-octs:http q.game)
        ==
        ::
          :: Serve sprites.png
          [%blackjack %'sprites.png' ~]
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'image/png']
            ==
            (to-octs:http q.sprites)
        ==
      ==  :: end GET
      ::
        %'POST'
      ?+    uri  [~[[%res ~ %500 ~ ~]] state]
        ::
          :: Initialize new game session
          [%blackjack %api %'new-game' ~]
        =/  session-id=@ud  next-session-id.state
        =/  new-game=game-state:blackjack
          :*  deck=~
              player-hand=~
              dealer-hand=~
              bank=1.000
              current-bet=0
              win-loss=--0
              game-in-progress=%.n
              dealer-turn=%.n
          ==
        =/  json=tape
          (make-json-new-game:blackjack session-id 1.000)
        :_  state(games (~(put by games.state) session-id new-game), next-session-id +(next-session-id.state))
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'application/json']
            ==
            (to-octs:http (crip json))
        ==
      ::

      :: ?>  =('/reset' uri)
      :: :_  state(value 0)
      :: :_  ~
      :: ^-  effect:http
      :: :*  %res  id=id  %200
      ::     ['content-type' 'text/html']~
      ::     %-  to-octs:http
      ::     %-  crip
      ::     ^-  tape
      ::     =/  index  (find "COUNT" page)
      ::     ;:  weld
      ::       (scag (need index) page)
      ::       (scow %ud 0)
      ::       (slag (add (need index) ^~((lent "COUNT"))) page)
      :: ==  ==
      ==  :: end POST
    ==  :: end GET/POST
  --
--
((moat |) inner)
