::  blackjack/lib/blackjack-game.hoon
::  Game logic for blackjack
::
/-  *blackjack
|%
::  Create a fresh 52-card deck
++  create-deck
  ^-  (list card)
  =/  deck=(list card)  ~
  =/  suits=(list suit)  ~[%hearts %diamonds %clubs %spades]
  =/  ranks=(list rank)  ~[%A %2 %3 %4 %5 %6 %7 %8 %9 %10 %J %Q %K]
  ::
  |-  ^-  (list card)
  ?~  suits  deck
  =/  current-suit=suit  i.suits
  =/  suit-cards=(list card)
    %+  turn  ranks
    |=(r=rank [suit=current-suit rank=r])
  $(suits t.suits, deck (weld deck suit-cards))
::
::  Shuffle deck using entropy
++  shuffle-deck
  |=  [deck=(list card) eny=@uvJ]
  ^-  (list card)
  =/  remaining=(list card)  deck
  =/  shuffled=(list card)  ~
  =/  rng  ~(. og eny)
  ::
  |-  ^-  (list card)
  ?~  remaining  shuffled
  =/  len=@ud  (lent remaining)
  ?:  =(len 1)
    (weld shuffled remaining)
  ::
  ::  Get random index
  =^  rand  rng  (rads:rng len)
  =/  chosen=card  (snag rand remaining)
  =/  new-remaining=(list card)
    (weld (scag rand remaining) (slag +(rand) remaining))
  ::
  $(remaining new-remaining, shuffled [chosen shuffled])
::
::  Calculate hand value (handle aces)
++  calculate-hand-value
  |=  h=hand
  ^-  @ud
  =/  value=@ud  0
  =/  aces=@ud  0
  ::
  ::  First pass: sum all values, count aces
  =/  cards=hand  h
  |-  ^-  [@ud @ud]
  ?~  cards  [value aces]
  =/  c=card  i.cards
  =/  rank-value=@ud
    ?+  rank.c  0
      %A   [value $(cards t.cards, value (add value 11), aces +(aces))]
      %2   2
      %3   3
      %4   4
      %5   5
      %6   6
      %7   7
      %8   8
      %9   9
      %10  10
      %J   10
      %Q   10
      %K   10
    ==
  ?:  =(%A rank.c)
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
  ^-  [hand hand (list card)]
  =/  player-card-1=card  (snag 0 deck)
  =/  dealer-card-1=card  (snag 1 deck)
  =/  player-card-2=card  (snag 2 deck)
  =/  dealer-card-2=card  (snag 3 deck)
  =/  player-hand=hand  ~[player-card-1 player-card-2]
  =/  dealer-hand=hand  ~[dealer-card-1 dealer-card-2]
  =/  remaining-deck=(list card)  (slag 4 deck)
  [player-hand dealer-hand remaining-deck]
::
::  Draw one card
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
--
