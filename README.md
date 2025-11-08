# **Blackjack**

A NockApp blackjack game.

## **Development Stages**

This project will be developed in four stages:

1. **Browser-based game** - Supports hit, stand, and resolve for players and house with bet tracking; DONE
    
2. **NockApp backend** - Server with deck shuffling; DONE
    
3. **Nockchain wallet integration** - Fakenet wallet support and game locks
    
4. **Enhanced gameplay** - Additional play options (to wit, split and multiplayer)
    

## **Current Features**

- Blackjack gameplay (H17 variant; blackjack pays 3:2)
    
- Windows 3.1-style interface with the fun old cards
    
- Poker chip betting interface ($5, $25, $100, $500)
    
- Bet tracking and bankroll management
    

## **How to Play**

1. Download and install Nockup.
    
2. Clone this repo and `cd` into it.
    
3. Build using Nockup:
    
4. Open your browser to `http://localhost:8080/blackjack` or whatever your platform prefers.
    
5. Play the game, which I think is pretty intuitive.
    

## **Game Rules**

- Player starts with $1000
    
- Dealer hits until reaching 17
    
- Blackjack (21 with first two cards) pays 3:2
    
- Player busts over 21
    
- Push (tie) returns your bet
    

## **Status**

The next stage will involve:

- Nockchain wallet integration
    
- Multiple hand support