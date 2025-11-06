::  blackjack/lib/blackjack-static.hoon
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
+$  hand  (list card)
::
::  Game state
+$  game-state
  $:  deck=(list card)
      player-hand=(list hand)  :: list for splitting hands
      dealer-hand=(list hand)
      bank=@ud
      current-bet=@ud
      win-loss=@sd
      game-in-progress=?
      dealer-turn=?
  ==
--
|%
++  leg  42
--
