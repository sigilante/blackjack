::  blackjack/app/blackjack.hoon
::  Browser-based blackjack game served as a NockApp
::
/+  http, static=blackjack-static
/=  *  /common/wrapper
::  Static resources (load as cords)
/*  index    %html   /app/site/index/html
/*  style    %css   /app/site/style/css
/*  game     %js    /app/site/game/js
/*  sprites  %png   /app/site/sprites/png
::
=>
|%
+$  server-state  [%0 value=@]
:: ++  page  index
--
::
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
    =/  uri=path  (pa:dejs:http s+uri)
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
      ::   %'POST'
      :: ?:  =('/increment' uri)
      ::   :_  state(value +(value.state))
      ::   :_  ~
      ::   ^-  effect:http
      ::   :*  %res  id=id  %200
      ::       ['content-type' 'text/html']~
      ::       %-  to-octs:http
      ::       %-  crip
      ::       ^-  tape
      ::       =/  index  (find "COUNT" page)
      ::       ;:  weld
      ::         (scag (need index) page)
      ::         (scow %ud +(value.state))
      ::         (slag (add (need index) ^~((lent "COUNT"))) page)
      ::   ==  ==
      :: ::
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
    ==  :: end GET/POST
  --
--
((moat |) inner)
