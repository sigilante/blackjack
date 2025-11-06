::  blackjack/sur/blackjack.hoon
::  Data structures for blackjack game
::
|%
::  Card suits and ranks
+$  suit  ?(%hearts %diamonds %clubs %spades)
+$  rank  ?(%A %2 %3 %4 %5 %6 %7 %8 %9 %10 %J %Q %K)
::
::  Card structure
+$  card  [=suit =rank]
::
::  Hand of cards
+$  hand  (list card)
::
::  Game state (server-side)
+$  game-state
  $:  deck=(list card)
      player-hand=hand
      dealer-hand=hand
      bank=@ud
      current-bet=@ud
      win-loss=@sd
      game-in-progress=?
      dealer-turn=?
  ==
::
::  Session identifier
+$  session-id  @ud
::
::  API request/response types
+$  bet-amount  @ud
::
+$  deal-response
  $:  player-hand=hand
      dealer-hand=hand
      player-score=@ud
      dealer-visible-card=card
      game-id=session-id
  ==
::
+$  hit-response
  $:  new-card=card
      player-hand=hand
      player-score=@ud
      busted=?
  ==
::
+$  stand-response
  $:  dealer-hand=hand
      dealer-score=@ud
      outcome=?(%win %loss %push %blackjack)
      payout=@ud
      new-bank=@ud
  ==
--
