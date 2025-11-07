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
    ~&  "Parsed path: {<uri>}"
    ::  Handle GET/POST requests
    ?+    method  [~[[%res ~ %400 ~ ~]] state]
      ::
        %'GET'
      ?+    uri  [~[[%res ~ %404 ~ ~]] state]
        ::
          :: Serve index.html at /blackjack
          [%blackjack ~]
        :_  state
        ^-  (list effect:http)
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/html']
            ==
            (to-octs:http q.index)
        ==
        ::
          :: Serve style.css at /blackjack/style.css
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
          :: Serve game.js at /blackjack/game.js
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
          :: Serve sprites.png at /blackjack/img/sprites.png
          [%blackjack %img %'sprites.png' ~]
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
          [%blackjack %api %new-game ~]
        =/  session-id=@ud  next-session-id.state
        =/  new-game=game-state:blackjack
          :*  deck=*(list card:blackjack)
              player-hand=*(list (list card:blackjack))
              dealer-hand=*(list (list card:blackjack))
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
        ::  Deal initial hands
          [%blackjack %api %deal ~]
        ::  Parse body to get session-id
        :: =/  body=@t  q.body.request.req
        =/  session-id=@ud  0  ::  TODO: Parse from JSON body
        ::
        ::  Get or create game state
        =/  existing=(unit game-state:blackjack)  (~(get by games.state) session-id)
        =/  current-game=game-state:blackjack
          ?~  existing
            ::  Create new game if doesn't exist
            :*  deck=*(list card:blackjack)
                player-hand=*(list (list card:blackjack))
                dealer-hand=*(list (list card:blackjack))
                bank=1.000
                current-bet=0
                win-loss=--0
                game-in-progress=%.n
                dealer-turn=%.n
            ==
          u.existing
        ::
        ::  Create and shuffle deck
        =/  fresh-deck=(list card:blackjack)  create-deck:blackjack
        =/  shuffled-deck=(list card:blackjack)
          (shuffle-deck:blackjack fresh-deck `@uvJ`42)
        ::
        ::  Deal initial hands
        =+  [player-hand dealer-hand remaining-deck]=(deal-initial:blackjack shuffled-deck)
        =/  player-score=@ud  (hand-value:blackjack (snag 0 player-hand))
        =/  dealer-visible=card:blackjack  (snag 1 (snag 0 dealer-hand))
        ::
        ::  Update game state
        =/  updated-game=game-state:blackjack
          current-game(deck remaining-deck, player-hand player-hand, dealer-hand dealer-hand, game-in-progress %.y, dealer-turn %.n)
        ::
        =/  json=tape
          (make-json-deal:blackjack player-hand dealer-hand player-score dealer-visible session-id)
        ::
        :_  state(games (~(put by games.state) session-id updated-game))
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'application/json']
            ==
            (to-octs:http (crip json))
        ==
        ::
          [%blackjack %api %hit ~]
        ::  Player hits (draw card)
        :: =/  body=@t  q.body.request.req
        =/  session-id=@ud  0  ::  TODO: Parse from JSON
        ::
        =/  existing=(unit game-state:blackjack)  (~(get by games.state) session-id)
        ?~  existing
          [~[[%res ~ %404 ~ ~]] state]
        =/  current-game=game-state:blackjack  u.existing
        ::
        ::  Draw card
        =+  [new-card remaining-deck]=(draw-card:blackjack deck.current-game)
        =/  new-player-hand=hand:blackjack  (snoc (snag 0 player-hand.current-game) new-card)
        =/  new-score=@ud  (hand-value:blackjack new-player-hand)
        =/  busted=?  (is-busted:blackjack new-player-hand)
        ::
        ::  Update game
        =/  updated-game=game-state:blackjack
          current-game(deck remaining-deck, player-hand (snap player-hand.current-game 0 new-player-hand))
        ::
        =/  json=tape
          (make-json-hit:blackjack new-card new-player-hand new-score busted)
        ::
        :_  state(games (~(put by games.state) session-id updated-game))
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'application/json']
            ==
            (to-octs:http (crip json))
        ==
        ::
          [%blackjack %api %stand ~]
        ::  Player stands, dealer plays
        :: =/  body=@t  q.body.request.req
        =/  session-id=@ud  0  ::  TODO: Parse from JSON
        ::
        =/  existing=(unit game-state:blackjack)  (~(get by games.state) session-id)
        ?~  existing
          [~[[%res ~ %404 ~ ~]] state]
        =/  current-game=game-state:blackjack  u.existing
        ::
        ::  Dealer plays
        =/  final-dealer-hand=hand:blackjack  (snag 0 dealer-hand.current-game)
        =/  remaining-deck=(list card:blackjack)  deck.current-game
        |-
        ?:  (dealer-should-hit:blackjack final-dealer-hand)
          =+  [new-card new-deck]=(draw-card:blackjack remaining-deck)
          $(final-dealer-hand (snoc final-dealer-hand new-card), remaining-deck new-deck)
        ::
        ::  Resolve outcome
        =+  [outcome multiplier]=(resolve-outcome:blackjack (snag 0 player-hand.current-game) final-dealer-hand)
        =/  payout=@ud  (mul current-bet.current-game multiplier)
        =/  new-bank=@ud  (add bank.current-game payout)
        =/  dealer-score=@ud  (hand-value:blackjack final-dealer-hand)
        ::
        ::  Update game
        =/  updated-game=game-state:blackjack
          current-game(dealer-hand (snap dealer-hand.current-game 0 final-dealer-hand), deck remaining-deck, bank new-bank, game-in-progress %.n)
        ::
        =/  json=tape
          (make-json-stand:blackjack final-dealer-hand dealer-score outcome payout new-bank)
        ::
        :_  state(games (~(put by games.state) session-id updated-game))
        :_  ~
        ^-  effect:http
        :*  %res  id=id  %200
            :~  ['Content-Type' 'application/json']
            ==
            (to-octs:http (crip json))
        ==
      ==  :: end POST
    ==  :: end GET/POST
  --
--
((moat |) inner)
