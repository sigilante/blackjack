::  blackjack/app/blackjack.hoon
::  Browser-based blackjack game served as a NockApp
::
/+  http, blackjack
/=  *  /common/wrapper
::  Wallet imports
/=  wallet        /apps/wallet/wallet
/=  wt            /apps/wallet/lib/types
::  Static resources (load as [@ud @t])
/*  index         %html   /app/site/index/html
/*  style         %css    /app/site/style/css
/*  game          %js     /app/site/game/js
/*  sprites       %png    /app/site/sprites/png
/*  watcher-html  %html   /app/site/watcher/html
/*  watcher-js    %js     /app/site/watcher/js
/*  watcher-css   %css    /app/site/watcher/css
/*  wallet-html   %html   /app/site/wallet/html
/*  wallet-js     %js     /app/site/wallet/js
/*  wallet-css    %css    /app/site/wallet/css
::  Application state
=>
|%
+$  server-state
  $:  %0
      sessions=(map game-id:blackjack session-state:blackjack)
      config=(unit runtime-config:blackjack)  :: Runtime config (poked from Rust)
  ==
::
::  Default server configuration (fallback if no config poked)
::
++  default-config
  ^-  runtime-config:blackjack
  :*  wallet-pkh=%''
      private-key=~
      confirmation-blocks=3
      enable-blockchain=%.n
      initial-bank=1.000
      max-history-entries=20
      notes=*(map @t *)
  ==
::
::  Get config (either from state or default)
::
++  get-config
  |=  state=server-state
  ^-  runtime-config:blackjack
  ?~  config.state
    default-config
  u.config.state
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
    ^-  [(list ?(effect:http effect:wt)) server-state]
    ::  Extract entropy from poke input
    =/  entropy=@  eny.input.ovum
    ::
    ::  Check if this is a config poke (non-HTTP)
    =/  config-poke=(unit config-poke:blackjack)
      ((soft config-poke:blackjack) cause.input.ovum)
    ?^  config-poke
      ::  Handle init-config poke
      ~&  >>  "Received init-config poke"
      =/  new-config=runtime-config:blackjack
        :*  wallet-pkh.u.config-poke
            `private-key.u.config-poke
            confirmation-blocks.u.config-poke
            enable-blockchain.u.config-poke
            initial-bank.u.config-poke
            max-history.u.config-poke
            ~  :: empty notes map initially
        ==
      ~&  >>  "Config updated with PKH: {<wallet-pkh.new-config>}"
      [~ state(config `new-config)]
    ::
    ::  Otherwise, parse as HTTP request
    =/  sof-cau=(unit cause:http)  ((soft cause:http) cause.input.ovum)
    ?~  sof-cau
      ~&  "cause incorrectly formatted!"
      ~&  now.input.ovum
      !!
    ::  Parse request into components.
    =/  [id=@ uri=@t =method:http headers=(list header:http) body=(unit octs:http)]
      +.u.sof-cau
    ~&  >  "Received request: {<method>} {<uri>}"
    =/  uri=path  (pa:dejs:http [%s uri])
    ~&  >>  "Parsed path: {<uri>}"
    ~&  >>  "Method: {<method>}"
    ::  Handle GET/POST requests
    ?+    method  [~[[%res ~ %400 ~ ~]] state]
      ::
        %'GET'
      ?+    uri
        ~&  >>>  "No route matched, returning 404 for: {<uri>}"
        [~[[%res ~ %404 ~ ~]] state]
        ::
          :: Serve index.html at /blackjack
          [%blackjack ~]
        ~&  >>  "Matched route: /blackjack (index.html)"
        :_  state
        ^-  (list effect:http)
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/html']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
                ['Pragma' 'no-cache']
                ['Expires' '0']
            ==
            (to-octs:http q.index)
        ==
        ::
          :: Serve style.css at /blackjack/style.css
          [%blackjack %'style.css' ~]
        ~&  >>  "Matched route: /blackjack/style.css"
        ~&  >>  "CSS length: {<(met 3 q.style)>} bytes"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/css']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
                ['Pragma' 'no-cache']
                ['Expires' '0']
            ==
            (to-octs:http q.style)
        ==
        ::
          :: Serve game.js at /blackjack/game.js
          [%blackjack %'game.js' ~]
        ~&  >>  "Matched route: /blackjack/game.js"
        ~&  >>  "JS length: {<(met 3 q.game)>} bytes"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/javascript']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
                ['Pragma' 'no-cache']
                ['Expires' '0']
            ==
            (to-octs:http q.game)
        ==
        ::
          :: Serve sprites.png at /blackjack/img/sprites.png
          [%blackjack %img %'sprites.png' ~]
        ~&  >>  "Matched route: /blackjack/img/sprites.png"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'image/png']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
                ['Pragma' 'no-cache']
                ['Expires' '0']
            ==
            (to-octs:http q.sprites)
        ==
        ::
          :: Serve watcher.html
          [%blackjack %'watcher.html' ~]
        ~&  >>  "Matched route: /blackjack/watcher.html"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/html']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http q.watcher-html)
        ==
        ::
          :: Serve watcher.js
          [%blackjack %'watcher.js' ~]
        ~&  >>  "Matched route: /blackjack/watcher.js"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/javascript']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http q.watcher-js)
        ==
        ::
          :: Serve watcher.css
          [%blackjack %'watcher.css' ~]
        ~&  >>  "Matched route: /blackjack/watcher.css"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/css']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http q.watcher-css)
        ==
        ::
          :: Serve wallet.html
          [%blackjack %'wallet.html' ~]
        ~&  >>  "Matched route: /blackjack/wallet.html"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/html']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http q.wallet-html)
        ==
        ::
          :: Serve wallet.js
          [%blackjack %'wallet.js' ~]
        ~&  >>  "Matched route: /blackjack/wallet.js"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/javascript']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http q.wallet-js)
        ==
        ::
          :: Serve wallet.css
          [%blackjack %'wallet.css' ~]
        ~&  >>  "Matched route: /blackjack/wallet.css"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'text/css']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http q.wallet-css)
        ==
        ::
          :: GET /api/sessions - List all active sessions
          [%blackjack %api %sessions ~]
        ~&  >>  "Matched route: GET /blackjack/api/sessions"
        ~&  >>>  "Total sessions in state: {<~(wyt by sessions.state)>}"
        ::  Extract session info from all sessions
        =/  session-list=(list [game-id=@t status=session-status:blackjack bank=@ud deals-made=@ud])
          %+  turn  ~(tap by sessions.state)
          |=  [gid=@t sess=session-state:blackjack]
          ^-  [game-id=@t status=session-status:blackjack bank=@ud deals-made=@ud]
          [gid status.sess bank.game.sess deals-made.game.sess]
        ~&  >>>  "Session list length: {<(lent session-list)>}"
        =/  json=tape
          (make-json-sessions-list:blackjack session-list)
        ~&  >>>  "JSON response: {<json>}"
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
        ::
          :: GET /api/{game-id}/status - Get full session state
          [%blackjack %api game-id:blackjack %status ~]
        =/  =game-id:blackjack  (snag 2 `path`uri)
        ~&  >>  "Matched route: GET /blackjack/api/{<game-id>}/status"
        =/  existing=(unit session-state:blackjack)  (~(get by sessions.state) game-id)
        ?~  existing
          ~&  >>>  "Session not found: {<game-id>}"
          =/  error-json=tape  (make-json-error:blackjack 404 "Session not found")
          :_  state
          :_  ~
          ^-  effect:http
          [%res id %404 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  json=tape
          (make-json-full-session:blackjack u.existing)
        :_  state
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
      ==  :: end GET
      ::
        %'POST'
      ~&  >>  "POST request detected!"
      ?+    uri
        ~&  >>  "No POST route matched for: {<uri>}"
        [~[[%res ~ %500 ~ ~]] state]
        ::
          :: Create new game session
          [%blackjack %api %session %create ~]
        ~&  >>  "Matched /blackjack/api/session/create route"
        ::  Generate UUID from entropy
        =/  =game-id:blackjack  (generate-uuid:blackjack entropy)
        ~&  >>  "Generated game-id: {<game-id>}"
        ::  Create initial game state
        =/  config=runtime-config:blackjack  (get-config state)
        =/  initial-game=game-state-inner:blackjack
          (initial-game-state:blackjack initial-bank.config)
        ::  Create session state
        =/  new-session=session-state:blackjack
          :*  game-id=game-id
              player-pkh=~
              bet-tx-hash=~
              bet-status=%pending
              confirmed-amount=0
              game=initial-game
              created=now.input.ovum
              last-activity=now.input.ovum
              status=%awaiting-bet
              history=~
          ==
        ::  Return session info with server PKH and initial bank
        =/  json=tape
          (make-json-session-created:blackjack game-id wallet-pkh.config bank.initial-game)
        ~&  >>  "Created session: {<game-id>}"
        :_  state(sessions (~(put by sessions.state) game-id new-session))
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
        ::
          ::  Deal initial hands
          [%blackjack %api game-id:blackjack %deal ~]
        =/  =game-id:blackjack  (snag 2 `path`uri)
        ~&  >>  "Matched /blackjack/api/{<game-id>}/deal route"
        ::  Parse body to get bet amount
        ?~  body
          =/  error-json=tape  (make-json-error:blackjack 400 "Missing request body")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  body-text=tape  (trip q.u.body)
        =/  bet-parsed=(unit @ud)  (parse-json-number:blackjack "bet" body-text)
        =/  bet=@ud  ?~(bet-parsed 100 u.bet-parsed)
        ~&  >>  "Using bet: {<bet>}"
        ::
        ::  Get session state
        =/  existing=(unit session-state:blackjack)  (~(get by sessions.state) game-id)
        ?~  existing
          ~&  >>>  "Session not found: {<game-id>}"
          =/  error-json=tape  (make-json-error:blackjack 404 "Session not found")
          :_  state
          :_  ~
          [%res id %404 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  current-session=session-state:blackjack  u.existing
        =/  current-game=game-state-inner:blackjack  game.current-session
        ::
        ::  Validate game action
        =/  validation-error=(unit tape)
          (validate-game-action:blackjack %deal current-session)
        ?^  validation-error
          =/  error-json=tape  (make-json-error:blackjack 400 u.validation-error)
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Check if player can afford the bet
        ?:  (gth bet bank.current-game)
          =/  error-json=tape  (make-json-error:blackjack 400 "Insufficient funds")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Deduct bet from bank
        =/  new-bank=@ud  (sub bank.current-game bet)
        ::
        ::  Create and shuffle deck with entropy
        =/  fresh-deck=(list card:blackjack)  create-deck:blackjack
        =/  shuffled-deck=(list card:blackjack)
          (shuffle-deck:blackjack fresh-deck `@uvJ`entropy)
        ::
        ::  Deal initial hands
        =+  [player-hand dealer-hand remaining-deck]=(deal-initial:blackjack shuffled-deck)
        =/  player-score=@ud  (hand-value:blackjack (snag 0 player-hand))
        =/  dealer-visible=card:blackjack  (snag 1 (snag 0 dealer-hand))
        ::
        ::  Update game state with bet deducted
        =/  updated-game=game-state-inner:blackjack
          current-game(deck remaining-deck, player-hand player-hand, dealer-hand dealer-hand, current-bet bet, bank new-bank, game-in-progress %.y, dealer-turn %.n, deals-made +(deals-made.current-game))
        ::
        ::  Update session state (set status to active)
        =/  updated-session=session-state:blackjack
          current-session(game updated-game, last-activity now.input.ovum, status %active)
        ~&  >>  "Updated game - current-bet: {<current-bet.updated-game>}, bank: {<bank.updated-game>}"
        ::
        ::  Build response (note: using 0 for backward compat with old sessionId field)
        =/  json=tape
          (make-json-deal:blackjack player-hand dealer-hand player-score dealer-visible 0 new-bank win-loss.updated-game)
        ::
        :_  state(sessions (~(put by sessions.state) game-id updated-session))
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
        ::
          ::  Player hits
          [%blackjack %api game-id:blackjack %hit ~]
        =/  =game-id:blackjack  (snag 2 `path`uri)
        ~&  >>  "Matched /blackjack/api/{<game-id>}/hit route"
        ::  Get session state
        =/  existing=(unit session-state:blackjack)  (~(get by sessions.state) game-id)
        ?~  existing
          ~&  >>>  "Session not found: {<game-id>}"
          =/  error-json=tape  (make-json-error:blackjack 404 "Session not found")
          :_  state
          :_  ~
          [%res id %404 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  current-session=session-state:blackjack  u.existing
        =/  current-game=game-state-inner:blackjack  game.current-session
        ::
        ::  Validate game action
        =/  validation-error=(unit tape)
          (validate-game-action:blackjack %hit current-session)
        ?^  validation-error
          =/  error-json=tape  (make-json-error:blackjack 400 u.validation-error)
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Draw card
        =+  [new-card remaining-deck]=(draw-card:blackjack deck.current-game)
        =/  new-player-hand=hand:blackjack  (snoc (snag 0 player-hand.current-game) new-card)
        =/  new-score=@ud  (hand-value:blackjack new-player-hand)
        =/  busted=?  (is-busted:blackjack new-player-hand)
        ::
        ::  Update game (end game if busted, clear bet)
        =/  updated-game=game-state-inner:blackjack
          ?:  busted
            current-game(deck remaining-deck, player-hand (snap player-hand.current-game 0 new-player-hand), current-bet 0, game-in-progress %.n)
          current-game(deck remaining-deck, player-hand (snap player-hand.current-game 0 new-player-hand))
        ::
        ::  Update session state
        =/  updated-session=session-state:blackjack
          current-session(game updated-game, last-activity now.input.ovum, status ?:(busted %ended %active))
        ::
        =/  json=tape
          (make-json-hit:blackjack new-card new-player-hand new-score busted bank.updated-game win-loss.updated-game)
        ::
        :_  state(sessions (~(put by sessions.state) game-id updated-session))
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
        ::
          ::  Player stands
          [%blackjack %api game-id:blackjack %stand ~]
        =/  =game-id:blackjack  (snag 2 `path`uri)
        ~&  >>  "Matched /blackjack/api/{<game-id>}/stand route"
        ::  Get session state
        =/  existing=(unit session-state:blackjack)  (~(get by sessions.state) game-id)
        ?~  existing
          ~&  >>>  "Session not found: {<game-id>}"
          =/  error-json=tape  (make-json-error:blackjack 404 "Session not found")
          :_  state
          :_  ~
          [%res id %404 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  current-session=session-state:blackjack  u.existing
        =/  current-game=game-state-inner:blackjack  game.current-session
        ::
        ::  Validate game action
        =/  validation-error=(unit tape)
          (validate-game-action:blackjack %stand current-session)
        ?^  validation-error
          =/  error-json=tape  (make-json-error:blackjack 400 u.validation-error)
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
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
        ~&  >  "Stand - current-bet: {<current-bet.current-game>}, bank: {<bank.current-game>}"
        =+  [outcome multiplier]=(resolve-outcome:blackjack (snag 0 player-hand.current-game) final-dealer-hand)
        ~&  >  "Outcome: {<outcome>}, multiplier: {<multiplier>}"
        =/  payout=@ud  (mul current-bet.current-game multiplier)
        ~&  >  "Payout: {<payout>}"
        =/  new-bank=@ud  (add bank.current-game payout)
        ~&  >  "New bank: {<new-bank>}"
        =/  dealer-score=@ud  (hand-value:blackjack final-dealer-hand)
        ~&  >  "Win/loss: {<win-loss.current-game>}"
        ::
        ::  Calculate win/loss change (payout includes return of bet)
        =/  profit=@sd
          =/  raw-profit=@s  (dif:si (sun:si payout) (sun:si current-bet.current-game))
          ?:  (syn:si raw-profit)  raw-profit
          (new:si %.n (abs:si raw-profit))
        =/  new-win-loss=@sd  (sum:si win-loss.current-game profit)
        ::
        ::  Update game (clear bet when ending)
        =/  updated-game=game-state-inner:blackjack
          current-game(dealer-hand (snap dealer-hand.current-game 0 final-dealer-hand), deck remaining-deck, bank new-bank, win-loss new-win-loss, current-bet 0, game-in-progress %.n)
        ::
        ::  Create history entry
        =/  history-entry=hand-history:blackjack
          :*  bet=current-bet.current-game
              player-hand=(snag 0 player-hand.current-game)
              dealer-hand=final-dealer-hand
              outcome=outcome
              payout=payout
              bank-after=new-bank
              timestamp=now.input.ovum
          ==
        ::  Append to history (keep last N hands per config)
        =/  config=runtime-config:blackjack  (get-config state)
        =/  new-history=(list hand-history:blackjack)
          (append-to-history:blackjack history-entry history.current-session max-history-entries.config)
        ::
        ::  Update session state (set status to ended and add history)
        =/  updated-session=session-state:blackjack
          current-session(game updated-game, last-activity now.input.ovum, status %ended, history new-history)
        ::
        =/  json=tape
          (make-json-stand:blackjack final-dealer-hand dealer-score outcome payout new-bank new-win-loss)
        ::
        :_  state(sessions (~(put by sessions.state) game-id updated-session))
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
        ::
          ::  Player doubles down
          [%blackjack %api game-id:blackjack %double ~]
        =/  =game-id:blackjack  (snag 2 `path`uri)
        ~&  >>  "Matched /blackjack/api/{<game-id>}/double route"
        ::  Get session state
        =/  existing=(unit session-state:blackjack)  (~(get by sessions.state) game-id)
        ?~  existing
          ~&  >>>  "Session not found: {<game-id>}"
          =/  error-json=tape  (make-json-error:blackjack 404 "Session not found")
          :_  state
          :_  ~
          [%res id %404 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  current-session=session-state:blackjack  u.existing
        =/  current-game=game-state-inner:blackjack  game.current-session
        ::
        ::  Validate game action
        =/  validation-error=(unit tape)
          (validate-game-action:blackjack %double current-session)
        ?^  validation-error
          =/  error-json=tape  (make-json-error:blackjack 400 u.validation-error)
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Check if player can afford to double
        ?:  (gth current-bet.current-game bank.current-game)
          =/  error-json=tape  (make-json-error:blackjack 400 "Insufficient funds to double down")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Deduct additional bet from bank and double current-bet
        =/  new-bank=@ud  (sub bank.current-game current-bet.current-game)
        =/  doubled-bet=@ud  (mul current-bet.current-game 2)
        ::
        ::  Draw exactly one card
        =+  [new-card remaining-deck]=(draw-card:blackjack deck.current-game)
        =/  new-player-hand=hand:blackjack  (snoc (snag 0 player-hand.current-game) new-card)
        =/  player-busted=?  (is-busted:blackjack new-player-hand)
        ::
        ::  If busted, game over (no need to play dealer hand)
        ?:  player-busted
          =/  dealer-hand-current=hand:blackjack  (snag 0 dealer-hand.current-game)
          =/  dealer-score=@ud  (hand-value:blackjack dealer-hand-current)
          ::  Calculate win/loss (busted = loss of doubled bet)
          =/  loss=@sd  (new:si %.n doubled-bet)
          =/  new-win-loss=@sd  (sum:si win-loss.current-game loss)
          =/  final-game=game-state-inner:blackjack
            current-game(deck remaining-deck, player-hand (snap player-hand.current-game 0 new-player-hand), current-bet 0, bank new-bank, win-loss new-win-loss, game-in-progress %.n)
          ::  Create history entry (busted = loss)
          =/  history-entry=hand-history:blackjack
            :*  bet=doubled-bet
                player-hand=new-player-hand
                dealer-hand=dealer-hand-current
                outcome=%loss
                payout=0
                bank-after=new-bank
                timestamp=now.input.ovum
            ==
          ::  Append to history (keep last N hands per config)
          =/  config=runtime-config:blackjack  (get-config state)
          =/  new-history=(list hand-history:blackjack)
            (append-to-history:blackjack history-entry history.current-session max-history-entries.config)
          ::  Update session state (set status to ended and add history)
          =/  final-session=session-state:blackjack
            current-session(game final-game, last-activity now.input.ovum, status %ended, history new-history)
          =/  json=tape
            (make-json-double:blackjack new-player-hand dealer-hand-current dealer-score %loss 0 new-bank new-win-loss)
          :_  state(sessions (~(put by sessions.state) game-id final-session))
          :_  ~
          ^-  effect:http
          :*  %res  id  %200
              :~  ['Content-Type' 'application/json']
                  ['Cache-Control' 'no-cache, no-store, must-revalidate']
              ==
              (to-octs:http (crip json))
          ==
        ::
        ::  Not busted, dealer plays
        =/  final-dealer-hand=hand:blackjack  (snag 0 dealer-hand.current-game)
        =/  deck-for-dealer=(list card:blackjack)  remaining-deck
        |-
        ?:  (dealer-should-hit:blackjack final-dealer-hand)
          =+  [new-card new-deck]=(draw-card:blackjack deck-for-dealer)
          $(final-dealer-hand (snoc final-dealer-hand new-card), deck-for-dealer new-deck)
        ::
        ::  Resolve outcome with doubled bet
        =+  [outcome multiplier]=(resolve-outcome:blackjack new-player-hand final-dealer-hand)
        =/  payout=@ud  (mul doubled-bet multiplier)
        =/  final-bank=@ud  (add new-bank payout)
        =/  dealer-score=@ud  (hand-value:blackjack final-dealer-hand)
        ::
        ::  Calculate win/loss change (payout includes return of bet)
        =/  profit=@sd
          =/  raw-profit=@s  (dif:si (sun:si payout) (sun:si doubled-bet))
          ?:  (syn:si raw-profit)  raw-profit
          (new:si %.n (abs:si raw-profit))
        =/  new-win-loss=@sd  (sum:si win-loss.current-game profit)
        ::
        ::  Update game (clear bet when ending)
        =/  final-game=game-state-inner:blackjack
          current-game(dealer-hand (snap dealer-hand.current-game 0 final-dealer-hand), player-hand (snap player-hand.current-game 0 new-player-hand), deck deck-for-dealer, current-bet 0, bank final-bank, win-loss new-win-loss, game-in-progress %.n)
        ::
        ::  Create history entry
        =/  history-entry=hand-history:blackjack
          :*  bet=doubled-bet
              player-hand=new-player-hand
              dealer-hand=final-dealer-hand
              outcome=outcome
              payout=payout
              bank-after=final-bank
              timestamp=now.input.ovum
          ==
        ::  Append to history (keep last N hands per config)
        =/  config=runtime-config:blackjack  (get-config state)
        =/  new-history=(list hand-history:blackjack)
          (append-to-history:blackjack history-entry history.current-session max-history-entries.config)
        ::
        ::  Update session state (set status to ended and add history)
        =/  final-session=session-state:blackjack
          current-session(game final-game, last-activity now.input.ovum, status %ended, history new-history)
        ::
        =/  json=tape
          (make-json-double:blackjack new-player-hand final-dealer-hand dealer-score outcome payout final-bank new-win-loss)
        ::
        :_  state(sessions (~(put by sessions.state) game-id final-session))
        :_  ~
        ^-  effect:http
        :*  %res  id  %200
            :~  ['Content-Type' 'application/json']
                ['Cache-Control' 'no-cache, no-store, must-revalidate']
            ==
            (to-octs:http (crip json))
        ==
        ::
          ::  Cash out - withdraw funds from game to player's wallet
          [%blackjack %api %wallet %cashout ~]
        ~&  >>  "Matched /blackjack/api/wallet/cashout route"
        ::  Parse body to get game-id, player-pkh, and amount
        ?~  body
          =/  error-json=tape  (make-json-error:blackjack 400 "Missing request body")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        =/  body-text=tape  (trip q.u.body)
        ~&  >>  "Cashout request body: {<body-text>}"
        ::
        ::  Parse required fields
        =/  game-id-parsed=(unit @t)  (parse-json-text:blackjack "gameId" body-text)
        =/  player-pkh-parsed=(unit @t)  (parse-json-text:blackjack "playerPkh" body-text)
        =/  amount-parsed=(unit @ud)  (parse-json-number:blackjack "amount" body-text)
        ::
        ::  Validate all fields present
        ?~  game-id-parsed
          =/  error-json=tape  (make-json-cashout-tx:blackjack '' 0 '' 0 %.n `"Missing gameId field")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ?~  player-pkh-parsed
          =/  error-json=tape  (make-json-cashout-tx:blackjack u.game-id-parsed 0 '' 0 %.n `"Missing playerPkh field")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ?~  amount-parsed
          =/  error-json=tape  (make-json-cashout-tx:blackjack u.game-id-parsed 0 u.player-pkh-parsed 0 %.n `"Missing amount field")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        =/  =game-id:blackjack  u.game-id-parsed
        =/  player-pkh=@t  u.player-pkh-parsed
        =/  amount=@ud  u.amount-parsed
        ~&  >>  "Cashout: game-id={<game-id>}, player-pkh={<player-pkh>}, amount={<amount>}"
        ::
        ::  Validate session exists
        =/  existing=(unit session-state:blackjack)  (~(get by sessions.state) game-id)
        ?~  existing
          ~&  >>>  "Session not found: {<game-id>}"
          =/  error-json=tape  (make-json-cashout-tx:blackjack game-id amount player-pkh 0 %.n `"Session not found")
          :_  state
          :_  ~
          [%res id %404 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        =/  current-session=session-state:blackjack  u.existing
        =/  current-game=game-state-inner:blackjack  game.current-session
        ::
        ::  Validate no game in progress
        ?:  game-in-progress.current-game
          =/  error-json=tape  (make-json-cashout-tx:blackjack game-id amount player-pkh bank.current-game %.n `"Cannot cash out during active game")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Validate sufficient balance
        ?:  (gth amount bank.current-game)
          =/  error-json=tape  (make-json-cashout-tx:blackjack game-id amount player-pkh bank.current-game %.n `"Insufficient balance")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Validate minimum cashout amount (at least 1)
        ?:  =(0 amount)
          =/  error-json=tape  (make-json-cashout-tx:blackjack game-id amount player-pkh bank.current-game %.n `"Amount must be greater than 0")
          :_  state
          :_  ~
          [%res id %400 ~[['Content-Type' 'application/json']] (to-octs:http (crip error-json))]
        ::
        ::  Deduct amount from bank
        =/  new-bank=@ud  (sub bank.current-game amount)
        ~&  >>  "Cashout approved: {<amount>} from {<bank.current-game>} leaving {<new-bank>}"
        ::
        ::  TODO: Build transaction using wallet tx-builder
        ::  For now, we'll just update the bank and return a success message
        ::  When wallet library is available:
        ::  1. Get server's available notes (UTXOs)
        ::  2. Use tx-builder to construct transaction
        ::  3. Sign with server's private key
        ::  4. Return raw-tx for submission
        ::
        ::  Update game state
        =/  updated-game=game-state-inner:blackjack
          current-game(bank new-bank)
        ::
        ::  Update session state
        =/  updated-session=session-state:blackjack
          current-session(game updated-game, last-activity now.input.ovum)
        ::
        ::  Build response (tx-ready=%.n since we don't have wallet library yet)
        =/  json=tape
          (make-json-cashout-tx:blackjack game-id amount player-pkh new-bank %.n ~)
        ~&  >>  "Cashout completed, returning response"
        ::
        :_  state(sessions (~(put by sessions.state) game-id updated-session))
        ;:  weld
          :~  ^-  effect:http
              :*  %res  id  %200
                  :~  ['Content-Type' 'application/json']
                      ['Cache-Control' 'no-cache, no-store, must-revalidate']
                  ==
                  (to-octs:http (crip json))
          ==  ==
          ::  Create transaction effect if config exists
          ?~  config.state
            ~&  >>  "No config state for creating cashout tx effect"
            ~
          ?~  private-key.u.config.state
            ~&  >>  "No private key in config, cannot create transaction"
            ~
          ::  Build the transaction effect
          =/  tx-effect=effect:wt
            %+  create-cause:blackjack
              [wallet-pkh.u.config.state u.private-key.u.config.state]
            [player-pkh amount]
          ~[tx-effect]
        ==
      ==  :: end POST
    ==  :: end GET/POST
  --
--
((moat |) inner)
