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
  ==
::
+$  game-state-inner
  $:  deck=(list card)
      player-hand=(list hand)  :: list for splitting hands
      dealer-hand=(list hand)
      bank=@ud
      current-bet=@ud
      win-loss=@sd
      hands-played=@ud         :: Track number of hands
      game-in-progress=?
      dealer-turn=?
  ==
::
:: Old game-state type for backward compatibility
+$  game-state  game-state-inner
::
+$  server-config
  $:  wallet-pkh=@t                :: Server's PKH from config
      confirmation-blocks=@ud      :: Required confirmations
      enable-blockchain=?          :: Toggle blockchain integration
      initial-bank=@ud             :: Initial bank for new sessions
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
  %+  weld  "\{\"sessionId\":"
  %+  weld  (a-co:co sid)
  %+  weld  ",\"bank\":"
  %+  weld  (a-co:co bank)
  "}"
::
++  make-json-deal
  |=  [player=(list hand) dealer=(list hand) score=@ud visible=card sid=@ud bank=@ud]
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
  "}"
  ==
::
++  make-json-hit
  |=  [new-card=card hand=hand score=@ud busted=? bank=@ud]
  ^-  tape
  %+  weld  "\{\"newCard\":"
  %+  weld  (card-to-json new-card)
  %+  weld  ",\"hand\":"
  %+  weld  (hand-to-json hand)
  %+  weld  ",\"score\":"
  %+  weld  (a-co:co score)
  %+  weld  ",\"busted\":"
  %+  weld  ?:(busted "true" "false")
  %+  weld  ",\"bank\":"
  %+  weld  (a-co:co bank)
  "}"
::
++  make-json-stand
  |=  [dealer=hand score=@ud outcome=?(%win %loss %push %blackjack) payout=@ud bank=@ud]
  ^-  tape
  %+  weld  "\{\"dealerHand\":"
  %+  weld  (hand-to-json dealer)
  %+  weld  ",\"dealerScore\":"
  %+  weld  (a-co:co score)
  %+  weld  ",\"outcome\":\""
  %+  weld  (scow %tas outcome)
  %+  weld  "\",\"payout\":"
  %+  weld  (a-co:co payout)
  %+  weld  ",\"bank\":"
  %+  weld  (a-co:co bank)
  "}"
::
++  make-json-double
  |=  [player=hand dealer=hand dealer-score=@ud outcome=?(%win %loss %push %blackjack) payout=@ud bank=@ud]
  ^-  tape
  %+  weld  "\{\"playerHand\":"
  %+  weld  (hand-to-json player)
  %+  weld  ",\"dealerHand\":"
  %+  weld  (hand-to-json dealer)
  %+  weld  ",\"dealerScore\":"
  %+  weld  (a-co:co dealer-score)
  %+  weld  ",\"outcome\":\""
  %+  weld  (scow %tas outcome)
  %+  weld  "\",\"payout\":"
  %+  weld  (a-co:co payout)
  %+  weld  ",\"bank\":"
  %+  weld  (a-co:co bank)
  "}"
::
::  Session management helpers
++  generate-uuid
  |=  ent=@
  ^-  @t
  ::  Generate UUID-style identifier using entropy
  =/  hex=tape  (scow %ux ent)
  =/  uuid=tape
    %+  weld  (scag 8 hex)
    %+  weld  "-"
    %+  weld  (scag 4 (slag 8 hex))
    %+  weld  "-"
    (scag 12 (slag 12 hex))
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
      hands-played=0
      game-in-progress=%.n
      dealer-turn=%.n
  ==
::
++  make-json-session-created
  |=  [game-id=@t server-pkh=@t]
  ^-  tape
  %+  weld  "\{\"gameId\":\""
  %+  weld  (trip game-id)
  %+  weld  "\",\"serverWalletPkh\":\""
  %+  weld  (trip server-pkh)
  "\"}"
::
++  make-json-session-status
  |=  [game-id=@t status=session-status player-pkh=(unit @t) bank=@ud]
  ^-  tape
  %+  weld  "\{\"gameId\":\""
  %+  weld  (trip game-id)
  %+  weld  "\",\"status\":\""
  %+  weld  (scow %tas status)
  %+  weld  "\",\"playerPkh\":"
  %+  weld  ?~(player-pkh "null" (weld "\"" (weld (trip u.player-pkh) "\"")))
  %+  weld  ",\"bank\":"
  %+  weld  (a-co:co bank)
  "}"
--
