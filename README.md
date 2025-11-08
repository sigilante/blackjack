# **Blackjack**

A NockApp blackjack game.

![](./img/header.png)

## Development Stages

This project will be developed in four stages:

1. Browser-based game - Supports hit, stand, and resolve for players and house with bet tracking
2. **NockApp backend** (Current) - Server with deck shuffling
3. Nockchain wallet integration - Fakenet wallet support
4. Enhanced gameplay - Additional play options

## Current Features

- Classic blackjack gameplay (hit, stand)
- Windows 3.1 style interface with toolbar and menubar
- Spritesheet-based playing cards (71x96 Windows 98 style)
- Poker chip betting interface ($5, $25, $100, $500)
    
- Bet tracking and bankroll management
- Win/loss tracking
- Dealer AI (dealer hits until 17)
- Blackjack pays 3:2

## How to Play

0. Clone the repository:

   ```bash
   git clone https://github.com/sigilante/blackjack.git
   cd blackjack
   ```

1. Download and install [Nockup](https://github.com/sigilante/nockup).

2. Build and run the NockApp server:

   ```bash
   nockup build blackjack
   nockup run blackjack
   ```

2. Open your browser to `http://127.0.0.1:8080/` (or the address shown in your terminal).

3. Game flow:

   - Click chips to place your bet
   - Click "Deal" to start the hand
   - Click "Hit" to draw another card or "Stand" to hold
   - Dealer plays automatically after you stand
   - Click "New Game" to reset your bankroll

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