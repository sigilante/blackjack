::  blackjack/app/blackjack.hoon
::  Browser-based blackjack game - Phase 2 with server-side logic
::
/-  *blackjack
/+  default-agent, dbug, server, game=blackjack-game
::  Load static files via Ford
/*  index-html  %html  /app/blackjack/index/html
/*  style-css   %css   /app/blackjack/style/css
/*  game-js     %js    /app/blackjack/game/js
::
|%
+$  versioned-state
  $%  state-0
  ==
::
+$  state-0
  $:  %0
      ::  Map of session-id to game state
      games=(map session-id game-state)
      ::  Simple counter for session IDs
      next-session-id=@ud
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
  ::
  ?+    method.request.req
    ::  Method not allowed
    :_  this
    :~  (give-simple-payload:app:server req [405 ~] ~)
    ==
  ::
  ::  GET requests for static files
    %'GET'
    ?+    site.request-line
      ::  404 for unknown paths
      :_  this
      :~  (give-simple-payload:app:server req [404 ~] ~)
      ==
    ::
      [%blackjack ~]
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'text/html'] ~]
          `(as-octs:mimes:html index-html)
      ==
    ::
      [%blackjack %style.css ~]
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'text/css'] ~]
          `(as-octs:mimes:html style-css)
      ==
    ::
      [%blackjack %game.js ~]
      :_  this
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'application/javascript'] ~]
          `(as-octs:mimes:html game-js)
      ==
    ==
  ::
  ::  POST requests for game API
    %'POST'
    ?+    site.request-line
      :_  this
      :~  (give-simple-payload:app:server req [404 ~] ~)
      ==
    ::
      [%blackjack %api %new-game ~]
      ::  Initialize new game session
      =/  session-id=@ud  next-session-id
      =/  new-game=game-state
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
        (make-json-new-game session-id 1.000)
      :_  this(games (~(put by games) session-id new-game), next-session-id +(next-session-id))
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'application/json'] ~]
          `(as-octs:mimes:html (crip json))
      ==
    ::
      [%blackjack %api %deal ~]
      ::  Deal initial hands
      ::  Parse body to get session-id
      =/  body=@t  q.body.request.req
      =/  session-id=@ud  0  ::  TODO: Parse from JSON body
      ::
      ::  Get or create game state
      =/  existing=(unit game-state)  (~(get by games) session-id)
      =/  current-game=game-state
        ?~  existing
          ::  Create new game if doesn't exist
          :*  deck=~
              player-hand=~
              dealer-hand=~
              bank=1.000
              current-bet=0
              win-loss=--0
              game-in-progress=%.n
              dealer-turn=%.n
          ==
        u.existing
      ::
      ::  Create and shuffle deck
      =/  fresh-deck=(list card)  create-deck:game
      =/  shuffled-deck=(list card)
        (shuffle-deck:game fresh-deck eny.bowl)
      ::
      ::  Deal initial hands
      =+  [player-hand dealer-hand remaining-deck]=(deal-initial:game shuffled-deck)
      =/  player-score=@ud  (hand-value:game player-hand)
      =/  dealer-visible=card  (snag 1 dealer-hand)
      ::
      ::  Update game state
      =/  updated-game=game-state
        current-game(deck remaining-deck, player-hand player-hand, dealer-hand dealer-hand, game-in-progress %.y, dealer-turn %.n)
      ::
      =/  json=tape
        (make-json-deal player-hand dealer-hand player-score dealer-visible session-id)
      ::
      :_  this(games (~(put by games) session-id updated-game))
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'application/json'] ~]
          `(as-octs:mimes:html (crip json))
      ==
    ::
      [%blackjack %api %hit ~]
      ::  Player hits (draw card)
      =/  body=@t  q.body.request.req
      =/  session-id=@ud  0  ::  TODO: Parse from JSON
      ::
      =/  existing=(unit game-state)  (~(get by games) session-id)
      ?~  existing
        :_  this
        :~  (give-simple-payload:app:server req [404 ~] ~)
        ==
      =/  current-game=game-state  u.existing
      ::
      ::  Draw card
      =+  [new-card remaining-deck]=(draw-card:game deck.current-game)
      =/  new-player-hand=hand  (snoc player-hand.current-game new-card)
      =/  new-score=@ud  (hand-value:game new-player-hand)
      =/  busted=?  (is-busted:game new-player-hand)
      ::
      ::  Update game
      =/  updated-game=game-state
        current-game(deck remaining-deck, player-hand new-player-hand)
      ::
      =/  json=tape
        (make-json-hit new-card new-player-hand new-score busted)
      ::
      :_  this(games (~(put by games) session-id updated-game))
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'application/json'] ~]
          `(as-octs:mimes:html (crip json))
      ==
    ::
      [%blackjack %api %stand ~]
      ::  Player stands, dealer plays
      =/  body=@t  q.body.request.req
      =/  session-id=@ud  0  ::  TODO: Parse from JSON
      ::
      =/  existing=(unit game-state)  (~(get by games) session-id)
      ?~  existing
        :_  this
        :~  (give-simple-payload:app:server req [404 ~] ~)
        ==
      =/  current-game=game-state  u.existing
      ::
      ::  Dealer plays
      =/  final-dealer-hand=hand  dealer-hand.current-game
      =/  remaining-deck=(list card)  deck.current-game
      |-
      ?:  (dealer-should-hit:game final-dealer-hand)
        =+  [new-card new-deck]=(draw-card:game remaining-deck)
        $(final-dealer-hand (snoc final-dealer-hand new-card), remaining-deck new-deck)
      ::
      ::  Resolve outcome
      =+  [outcome multiplier]=(resolve-outcome:game player-hand.current-game final-dealer-hand)
      =/  payout=@ud  (mul current-bet.current-game multiplier)
      =/  new-bank=@ud  (add bank.current-game payout)
      =/  dealer-score=@ud  (hand-value:game final-dealer-hand)
      ::
      ::  Update game
      =/  updated-game=game-state
        current-game(dealer-hand final-dealer-hand, deck remaining-deck, bank new-bank, game-in-progress %.n)
      ::
      =/  json=tape
        (make-json-stand final-dealer-hand dealer-score outcome payout new-bank)
      ::
      :_  this(games (~(put by games) session-id updated-game))
      :~  %^  give-simple-payload:app:server
            req
            [200 ['Content-Type' 'application/json'] ~]
          `(as-octs:mimes:html (crip json))
      ==
    ==
  ==
::
::  JSON encoding helpers
++  card-to-json
  |=  c=card
  ^-  tape
  (weld "{\"suit\":\"" (weld (trip (scot %tas suit.c)) (weld "\",\"rank\":\"" (weld (trip (scot %tas rank.c)) "\"}"))))
::
++  hand-to-json
  |=  h=hand
  ^-  tape
  =/  cards-json=(list tape)
    (turn h card-to-json)
  (weld "[" (weld (roll cards-json |=([a=tape b=tape] ?~(b a (weld b (weld "," a))))) "]"))
::
++  make-json-new-game
  |=  [sid=@ud bank=@ud]
  ^-  tape
  %+  weld  "{\"sessionId\":"
  %+  weld  (trip (scot %ud sid))
  %+  weld  ",\"bank\":"
  %+  weld  (trip (scot %ud bank))
  "}"
::
++  make-json-deal
  |=  [player=hand dealer=hand score=@ud visible=card sid=@ud]
  ^-  tape
  %+  weld  "{\"playerHand\":"
  %+  weld  (hand-to-json player)
  %+  weld  ",\"dealerHand\":"
  %+  weld  (hand-to-json dealer)
  %+  weld  ",\"playerScore\":"
  %+  weld  (trip (scot %ud score))
  %+  weld  ",\"dealerVisibleCard\":"
  %+  weld  (card-to-json visible)
  %+  weld  ",\"sessionId\":"
  %+  weld  (trip (scot %ud sid))
  "}"
::
++  make-json-hit
  |=  [new-card=card hand=hand score=@ud busted=?]
  ^-  tape
  %+  weld  "{\"newCard\":"
  %+  weld  (card-to-json new-card)
  %+  weld  ",\"hand\":"
  %+  weld  (hand-to-json hand)
  %+  weld  ",\"score\":"
  %+  weld  (trip (scot %ud score))
  %+  weld  ",\"busted\":"
  %+  weld  ?:(busted "true" "false")
  "}"
::
++  make-json-stand
  |=  [dealer=hand score=@ud outcome=?(%win %loss %push %blackjack) payout=@ud bank=@ud]
  ^-  tape
  %+  weld  "{\"dealerHand\":"
  %+  weld  (hand-to-json dealer)
  %+  weld  ",\"dealerScore\":"
  %+  weld  (trip (scot %ud score))
  %+  weld  ",\"outcome\":\""
  %+  weld  (trip (scot %tas outcome))
  %+  weld  "\",\"payout\":"
  %+  weld  (trip (scot %ud payout))
  %+  weld  ",\"bank\":"
  %+  weld  (trip (scot %ud bank))
  "}"
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
