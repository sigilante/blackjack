::  blackjack/lib/blackjack-static.hoon
::
/=  ztd  /common/ztd/three
::
::  blackjack/sur/blackjack.hoon
::  Data structures for blackjack game
::
=>
|%
::  Card suits and ranks
+$  suit  ?(%hearts %diamonds %clubs %spades)
+$  rank  ?(%'A' %'2' %'3' %'4' %'5' %'6' %'7' %'8' %'9' %'10' %'J' %'Q' %'K')
::
::  Card structure
+$  card  [=suit =rank]
::
::  Hand of cards
+$  hand  (list card)  :: could plausibly be a (set card)
::
::  Session and game state
+$  game-id  @t  :: UUID-style identifier
+$  session-id  @ud  :: Old style, kept for compatibility
::
+$  bet-status
  $?  %pending      :: Transaction submitted, waiting for confirmations
      %confirmed    :: Transaction has required confirmations
      %failed       :: Transaction failed or invalid
  ==
::
+$  session-status
  $?  %awaiting-bet    :: Session created, waiting for bet transaction
      %bet-pending     :: Bet transaction seen, waiting for confirmations
      %active          :: Bet confirmed, game in progress
      %ended           :: Game ended, waiting for payout
      %paid-out        :: Payout transaction broadcast
      %closed          :: Session closed
  ==
::
+$  hand-history
  $:  bet=@ud
      player-hand=hand
      dealer-hand=hand
      outcome=?(%win %loss %push %blackjack)
      payout=@ud
      bank-after=@ud            :: Bank balance after this hand
      timestamp=@da
  ==
::
+$  session-state
  $:  game-id=@t
      player-pkh=(unit @t)        :: Player's public key hash
      bet-tx-hash=(unit @t)       :: Transaction hash of initial bet
      bet-status=bet-status       :: Status of bet transaction
      confirmed-amount=@ud        :: Amount confirmed on-chain (0 if pending)
      game=game-state-inner       :: Actual game state
      created=@da
      last-activity=@da
      status=session-status
      history=(list hand-history) :: Last N hands played
  ==
::
+$  game-state-inner
  $:  deck=(list card)
      player-hand=(list hand)  :: list for splitting hands
      dealer-hand=(list hand)
      bank=@ud
      current-bet=@ud
      win-loss=@sd
      deals-made=@ud           :: Track number of deals
      game-in-progress=?
      dealer-turn=?
  ==
::
:: Old game-state type for backward compatibility
+$  game-state  game-state-inner
::
+$  server-config
  $:  wallet-pkh=@t                :: Server's PKH from config
      confirmation-blocks=@ud      :: Required confirmations (typically 3)
      enable-blockchain=?          :: Toggle blockchain integration
      initial-bank=@ud             :: Initial bank for new sessions (default 1000)
      max-history-entries=@ud      :: Maximum history entries to keep (default 20)
  ==
::
::  Runtime server configuration (includes keys and notes)
::  This gets poked in from Rust driver on startup
+$  runtime-config
  $:  wallet-pkh=@t                        :: Server's wallet PKH
      private-key=(unit @t)                :: Server's private key (base58)
      confirmation-blocks=@ud              :: Required confirmations
      enable-blockchain=?                  :: Blockchain integration enabled
      initial-bank=@ud                     :: Initial bank amount
      max-history-entries=@ud              :: Max history entries
      notes=(map @t *)                     :: Server's UTXOs (note name -> note data)
  ==
--
::  Game mechanics
|%
::  Create a fresh 52-card deck in standard new-deck order (NDO), no jokers
++  create-deck
  ^-  (list card)
  =/  deck=(list card)  ~
  =/  suits=(list suit)  ~[%spades %diamonds %clubs %hearts]
  =/  ranks=(list rank)  ~[%'A' %'2' %'3' %'4' %'5' %'6' %'7' %'8' %'9' %'10' %'J' %'Q' %'K']
  ::
  |-  ^-  (list card)
  ?~  suits  deck
  =/  current-suit=suit  i.suits
  =/  suit-cards=(list card)
    %+  turn  ranks
    |=(r=rank [suit=current-suit rank=r])
  $(suits t.suits, deck (weld deck suit-cards))
::
::  Shuffle deck
++  shuffle-deck
  |=  [deck=(list card) eny=@uvJ]
  ^-  (list card)
  =/  n  (lent deck)
  =/  remaining=(list card)  deck
  =/  shuffled=(list card)  ~
  =/  rng  ~(. tog:tip5:ztd (reap 16 eny))
  |-  ^-  (list card)
  ?:  =(~ remaining)  shuffled
  =/  len=@ud  (lent remaining)
  ?:  =(len 1)  (weld shuffled remaining)
  =^  index=@  rng  (index:rng (lent remaining))
  =/  chosen=card  (snag index remaining)
  =/  new-remaining=(list card)
    (weld (scag index remaining) (slag +(index) remaining))
  $(remaining new-remaining, shuffled `(list card)`[chosen shuffled])
::
::  Calculate hand value (handle aces)
++  calculate-hand-value
  |=  h=hand
  ^-  [@ud @ud]
  =/  value=@ud  0
  =/  aces=@ud  0
  ::
  ::  First pass: sum all values, count aces
  =/  cards=hand  h
  |-  ^-  [@ud @ud]
  ?~  cards  [value aces]
  =/  c=card  i.cards
  =/  rank-value=@ud
    ?-  rank.c
      %'A'   1
      %'2'   2
      %'3'   3
      %'4'   4
      %'5'   5
      %'6'   6
      %'7'   7
      %'8'   8
      %'9'   9
      %'10'  10
      %'J'   10
      %'Q'   10
      %'K'   10
    ==
  ?:  =(%'A' rank.c)
    $(cards t.cards, value (add value 11), aces +(aces))
  $(cards t.cards, value (add value rank-value))
::
::  Second pass: adjust aces if needed
++  adjust-aces
  |=  [value=@ud aces=@ud]
  ^-  @ud
  |-  ^-  @ud
  ?:  (lte value 21)  value
  ?:  =(aces 0)  value
  $(value (sub value 10), aces (dec aces))
::
::  Calculate hand value (exported version)
++  hand-value
  |=  h=hand
  ^-  @ud
  =+  [value aces]=(calculate-hand-value h)
  (adjust-aces value aces)
::
::  Check if hand is busted
++  is-busted
  |=  h=hand
  ^-  ?
  (gth (hand-value h) 21)
::
::  Check if hand is blackjack (21 with 2 cards)
++  is-blackjack
  |=  h=hand
  ^-  ?
  ?&  =(2 (lent h))
      =(21 (hand-value h))
  ==
::
::  Dealer should hit (< 17)
++  dealer-should-hit
  |=  h=hand
  ^-  ?
  (lth (hand-value h) 17)
::
::  Deal initial hands (2 cards each)
++  deal-initial
  |=  deck=(list card)
  ^-  [(list hand) (list hand) (list card)]
  =/  player-card-1=card  (snag 0 deck)
  =/  dealer-card-1=card  (snag 1 deck)
  =/  player-card-2=card  (snag 2 deck)
  =/  dealer-card-2=card  (snag 3 deck)
  =/  player-hand=hand  ~[player-card-1 player-card-2]
  =/  dealer-hand=hand  ~[dealer-card-1 dealer-card-2]
  =/  remaining-deck=(list card)  (slag 4 deck)
  [~[player-hand] ~[dealer-hand] remaining-deck]
::
::  Draw one card (and remove it from the deck)
++  draw-card
  |=  deck=(list card)
  ^-  [card (list card)]
  [(snag 0 deck) (slag 1 deck)]
::
::  Resolve game outcome
::  Returns: [outcome-type payout-multiplier]
::  outcome-type: %win %loss %push %blackjack
::  payout-multiplier: 0=loss, 1=push, 2=win, 2.5=blackjack
++  resolve-outcome
  |=  [player-hand=hand dealer-hand=hand]
  ^-  [?(%win %loss %push %blackjack) @ud]
  =/  player-value=@ud  (hand-value player-hand)
  =/  dealer-value=@ud  (hand-value dealer-hand)
  =/  player-bj=?  (is-blackjack player-hand)
  =/  dealer-bj=?  (is-blackjack dealer-hand)
  ::
  ::  Player busted
  ?:  (gth player-value 21)
    [%loss 0]
  ::
  ::  Blackjacks
  ?:  player-bj
    ?:  dealer-bj
      [%push 1]
    [%blackjack 5]  ::  Returns 2.5x (bet + 1.5x bet = 2.5x bet)
  ::
  ::  Dealer busted
  ?:  (gth dealer-value 21)
    [%win 2]
  ::
  ::  Compare values
  ?:  (gth player-value dealer-value)
    [%win 2]
  ?:  (lth player-value dealer-value)
    [%loss 0]
  [%push 1]
::
::
::  JSON parsing helpers
++  parse-json-number
  |=  [key=tape json-text=tape]
  ^-  (unit @ud)
  ::  Find the key in the JSON
  =/  key-str=tape  (weld "\"" (weld key "\":"))
  =/  idx=(unit @ud)  (find key-str json-text)
  ?~  idx  ~
  ::  Skip past the key and colon
  =/  remaining=tape  (slag (add u.idx (lent key-str)) json-text)
  ::  Extract digits
  =/  digits=tape
    |-  ^-  tape
    ?~  remaining  ~
    ?:  ?&  (gte i.remaining '0')  (lte i.remaining '9')  ==
      [i.remaining $(remaining t.remaining)]
    ~
  ?~  digits  ~
  `(rash (crip digits) dem)
::
::  JSON encoding helpers
++  card-to-json
  |=  c=card
  ^-  tape
  (weld "\{\"suit\":\"" (weld (scow %tas suit.c) (weld "\",\"rank\":\"" (weld (scow %tas rank.c) "\"}"))))
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
  ;:  weld
    "\{\"sessionId\":"
    (a-co:co sid)
    ",\"bank\":"
    (a-co:co bank)
    "}"
  ==
::
++  make-json-deal
  |=  [player=(list hand) dealer=(list hand) score=@ud visible=card sid=@ud bank=@ud win-loss=@sd]
  ^-  tape
  ;:  weld
    "\{\"playerHand\":"
    (roll (turn player hand-to-json) |=([a=tape b=tape] (weld b a)))
    ",\"dealerHand\":"
    (roll (turn dealer hand-to-json) |=([a=tape b=tape] (weld b a)))
    ",\"playerScore\":"
    (a-co:co score)
    ",\"dealerVisibleCard\":"  :: TODO for each hand
    (card-to-json visible)
    ",\"sessionId\":"
    (a-co:co sid)
    ",\"bank\":"
    (a-co:co bank)
    ",\"winLoss\":"
    (a-co:co win-loss)
  "}"
  ==
::
++  make-json-hit
  |=  [new-card=card hand=hand score=@ud busted=? bank=@ud win-loss=@sd]
  ^-  tape
  ;:  weld
    "\{\"newCard\":"
    (card-to-json new-card)
    ",\"hand\":"
    (hand-to-json hand)
    ",\"score\":"
    (a-co:co score)
    ",\"busted\":"
    ?:(busted "true" "false")
    ",\"bank\":"
    (a-co:co bank)
    ",\"winLoss\":"
    (a-co:co win-loss)
    "}"
  ==
::
++  make-json-stand
  |=  [dealer=hand score=@ud outcome=?(%win %loss %push %blackjack) payout=@ud bank=@ud win-loss=@sd]
  ^-  tape
  ;:  weld
    "\{\"dealerHand\":"
    (hand-to-json dealer)
    ",\"dealerScore\":"
    (a-co:co score)
    ",\"outcome\":\""
    (scow %tas outcome)
    "\",\"payout\":"
    (a-co:co payout)
    ",\"bank\":"
    (a-co:co bank)
    ",\"winLoss\":"
    (a-co:co win-loss)
    "}"
  ==
::
++  make-json-double
  |=  [player=hand dealer=hand dealer-score=@ud outcome=?(%win %loss %push %blackjack) payout=@ud bank=@ud win-loss=@sd]
  ^-  tape
  ;:  weld
    "\{\"playerHand\":"
    (hand-to-json player)
    ",\"dealerHand\":"
    (hand-to-json dealer)
    ",\"dealerScore\":"
    (a-co:co dealer-score)
    ",\"outcome\":\""
    (scow %tas outcome)
    "\",\"payout\":"
    (a-co:co payout)
    ",\"bank\":"
    (a-co:co bank)
    ",\"winLoss\":"
    (a-co:co win-loss)
    "}"
  ==
::
::  Session management helpers
++  generate-uuid
  |=  ent=@
  ^-  @t
  ::  Generate UUID-style identifier using entropy
  =/  hex=tape  (scow %ux ent)
  =/  uuid=tape
    ;:  weld
      (scag 8 hex)
      "-"
      (scag 4 (slag 8 hex))
      "-"
      (scag 12 (slag 12 hex))
    ==
  (crip uuid)
::
++  initial-game-state
  |=  initial-bank=@ud
  ^-  game-state-inner
  :*  deck=~
      player-hand=~
      dealer-hand=~
      bank=initial-bank
      current-bet=0
      win-loss=--0
      deals-made=0
      game-in-progress=%.n
      dealer-turn=%.n
  ==
::
++  make-json-session-created
  |=  [game-id=@t server-pkh=@t bank=@ud]
  ^-  tape
  ;:  weld
    "\{\"gameId\":\""
    (trip game-id)
    "\",\"serverWalletPkh\":\""
    (trip server-pkh)
    "\",\"bank\":"
    (a-co:co bank)
    "}"
  ==
::
++  make-json-session-status
  |=  [game-id=@t status=session-status player-pkh=(unit @t) bank=@ud]
  ^-  tape
  ;:  weld
    "\{\"gameId\":\""
    (trip game-id)
    "\",\"status\":\""
    (scow %tas status)
    "\",\"playerPkh\":"
    ?~(player-pkh "null" (weld "\"" (weld (trip u.player-pkh) "\"")))
    ",\"bank\":"
    (a-co:co bank)
    "}"
  ==
::
++  make-json-error
  |=  [code=@ud message=tape]
  ^-  tape
  ;:  weld
    "\{\"error\":\""
    message
    "\",\"code\":"
    (a-co:co code)
    "}"
  ==
::
++  append-to-history
  |=  [new-entry=hand-history old-history=(list hand-history) max-entries=@ud]
  ^-  (list hand-history)
  ::  Prepend new entry and keep last N entries
  (scag max-entries `(list hand-history)`[new-entry old-history])
::
++  validate-game-action
  |=  [action=?(%hit %stand %double %deal) sess=session-state]
  ^-  (unit tape)
  ::  Returns error message if invalid, ~ if valid
  =/  game=game-state-inner  game.sess
  ?-  action
    %deal
      ?:  game-in-progress.game
        `"Cannot deal while game is in progress"
      ::  For now, allow dealing without blockchain confirmation
      ::  This will be enforced when enable-blockchain=%.y
      ~
    %hit
      ?:  |(=(%.n game-in-progress.game) dealer-turn.game)
        `"Cannot hit - not player's turn"
      ~
    %stand
      ?:  |(=(%.n game-in-progress.game) dealer-turn.game)
        `"Cannot stand - not player's turn"
      ~
    %double
      ?:  |(=(%.n game-in-progress.game) dealer-turn.game)
        `"Cannot double - not player's turn"
      ::  Check if player has exactly 2 cards (first turn only)
      ?:  !=(2 (lent (snag 0 player-hand.game)))
        `"Can only double on first two cards"
      ~
  ==
::
++  hand-history-to-json
  |=  hist=hand-history
  ^-  tape
  ;:  weld
    "\{\"bet\":"
    (a-co:co bet.hist)
    ",\"playerHand\":"
    (hand-to-json player-hand.hist)
    ",\"dealerHand\":"
    (hand-to-json dealer-hand.hist)
    ",\"outcome\":\""
    (scow %tas outcome.hist)
    "\",\"payout\":"
    (a-co:co payout.hist)
    ",\"bankAfter\":"
    (a-co:co bank-after.hist)
    "}"
  ==
::
++  history-list-to-json
  |=  history=(list hand-history)
  ^-  tape
  ?~  history
    "[]"
  =/  json-items=(list tape)
    %+  turn  history
    |=(hist=hand-history (hand-history-to-json hist))
    ;:  weld
      "["
      (join-tapes json-items ",")
      "]"
    ==
::
++  join-tapes
  |=  [items=(list tape) separator=tape]
  ^-  tape
  ?~  items  ""
  ?~  t.items  i.items
  ;:  weld
    i.items
    separator
    $(items t.items)
  ==
::
++  make-json-sessions-list
  |=  sessions=(list [game-id=@t status=session-status bank=@ud deals-made=@ud])
  ^-  tape
  ?~  sessions
    "\{\"sessions\":[]}"
  =/  session-jsons=(list tape)
    %+  turn  sessions
    |=  [game-id=@t status=session-status bank=@ud deals-made=@ud]
    ^-  tape
    ;:  weld
      "\{\"gameId\":\""
      (trip game-id)
      "\",\"status\":\""
      (scow %tas status)
      "\",\"bank\":"
      (a-co:co bank)
      ",\"dealsMade\":"
      (a-co:co deals-made)
      "}"
    ==
  ;:  weld
      "\{\"sessions\":["
      (join-tapes session-jsons ",")
      "]}"
  ==
::
++  make-json-full-session
  |=  sess=session-state
  ^-  tape
  ;:  weld
    "\{\"gameId\":\""
    (trip game-id.sess)
    "\",\"status\":\""
    (scow %tas status.sess)
    "\",\"playerPkh\":"
    ?~(player-pkh.sess "null" (weld "\"" (weld (trip u.player-pkh.sess) "\"")))
    ",\"bank\":"
    (a-co:co bank.game.sess)
    ",\"currentBet\":"
    (a-co:co current-bet.game.sess)
    ",\"dealsMade\":"
    (a-co:co deals-made.game.sess)
    ",\"gameInProgress\":"
    ?:(game-in-progress.game.sess "true" "false")
    ",\"playerHand\":"
    ?:(=(~ player-hand.game.sess) "[]" (hand-to-json (snag 0 player-hand.game.sess)))
    ",\"dealerHand\":"
    ?:(=(~ dealer-hand.game.sess) "[]" (hand-to-json (snag 0 dealer-hand.game.sess)))
    ",\"dealerTurn\":"
    ?:(dealer-turn.game.sess "true" "false")
    ",\"history\":"
    (history-list-to-json history.sess)
    ",\"winLoss\":"
    (a-co:co win-loss.game.sess)
    "}"
  ==
::
++  parse-json-text
  |=  [key=tape json-text=tape]
  ^-  (unit @t)
  ::  Find the key in the JSON
  =/  key-str=tape  (weld "\"" (weld key "\":\""))
  =/  idx=(unit @ud)  (find key-str json-text)
  ?~  idx  ~
  ::  Skip past the key, colon, and opening quote
  =/  remaining=tape  (slag (add u.idx (lent key-str)) json-text)
  ::  Extract characters until closing quote
  =/  text=tape
    |-  ^-  tape
    ?~  remaining  ~
    ?:  =(i.remaining '"')  ~
    [i.remaining $(remaining t.remaining)]
  ?~  text  ~
  `(crip text)
::
++  make-json-cashout-tx
  |=  [game-id=@t amount=@ud player-pkh=@t new-bank=@ud tx-ready=? error=(unit tape)]
  ^-  tape
  ?^  error
    ::  Error response
    ;:  weld
      "\{\"success\":false,\"error\":\""
      u.error
      "\"}"
    ==
  ::  Success response
  ;:  weld
    "\{\"success\":true"
    ",\"gameId\":\""
    (trip game-id)
    "\",\"amount\":"
    (a-co:co amount)
    ",\"playerPkh\":\""
    (trip player-pkh)
    "\",\"newBank\":"
    (a-co:co new-bank)
    ",\"txReady\":"
    ?:(tx-ready "true" "false")
    ",\"message\":\""
    ?:(tx-ready "Transaction built successfully - awaiting submission" "Transaction structure prepared")
    "\"}"
  ==
::
+$  config-poke
  $:  %init-config
      wallet-pkh=@t
      private-key=@t
      confirmation-blocks=@ud
      enable-blockchain=?
      initial-bank=@ud
      max-history=@ud
  ==
::
--
