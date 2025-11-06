::  blackjack/sur/blackjack.hoon
::  Data structures for blackjack game
::
|%
::  Card suits and ranks (for future use)
+$  suit  ?(%hearts %diamonds %clubs %spades)
+$  rank  ?(%A %2 %3 %4 %5 %6 %7 %8 %9 %10 %J %Q %K)
::
::  Card structure
+$  card  [=suit =rank]
::
::  Hand of cards
+$  hand  (list card)
::
::  Game state (for future server-side logic)
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
--
