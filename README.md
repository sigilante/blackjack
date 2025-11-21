# **Blackjack**

A [NockApp](https://github.com/nockchain/nockchain) blackjack game demonstrating NockApp application design principles.

**Status**:  In active development as a demo.  The main gameplay is functional.  Nockchain integration is under way, based on the `tx_driver` release in Nockchain's main repo.

![](./img/header.png)

## Development Stages

This project will be developed in four stages:

1. Browser-based game - Supports hit, stand, and resolve for players and house with bet tracking
2. NockApp backend - Server with deck shuffling
3. Nockchain integration - Transaction support
  * [x] Payouts with `tx_driver`
  * [ ] Payins from Nockchain wallet (currently manual)
  * [ ] Server/client support for multiple players
  * [ ] Better fakenet support
4. Enhanced gameplay - Additional play options
  * Multiple hands
  * Multiplayer support

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

2. Open your browser to `http://127.0.0.1:8080/blackjack` (or the address/port shown in your terminal; the port may differ by OS).

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
- Player and dealer bust over 21
  - TODO dealer should reveal hole card on blackjack
- Push (tie) returns player's bet

## **Architecture**

As a NockApp application, there are two layers:

1. NockApp kernel:  manages game state, serves HTTP requests, and handles transactions.
2. NockApp driver:  routes requests to the kernel and processes Nockchain interactivity.

## **Status**

The next stage will involve:

- Enhanced Nockchain wallet integration
- Multi-hand support and multiplayer features
