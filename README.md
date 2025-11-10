# **Blackjack**

A NockApp blackjack game.

**Status**:  In active development.  The main gameplay is functional, with plans for Nockchain integration next.

![](./img/header.png)

## Development Stages

This project will be developed in four stages:

1. Browser-based game - Supports hit, stand, and resolve for players and house with bet tracking
2. NockApp backend - Server with deck shuffling
3. **Nockchain integration** (Current) - Transaction support
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

2. Open your browser to `http://127.0.0.1:8080/blackjack` (or the address/port shown in your terminal).

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
- Push (tie) returns your bet

## **Status**

The next stage will involve:

- Nockchain wallet integration
- Multiple hand support

## Wallet Integration

The purpose of Blackjack on Nockchain is to demonstrate secure, verifiable gaming on a decentralized platform.  Ultimately, this should look like “mental poker” where the server cannot cheat.

The steps which need to take place are:

1. Players create a wallet and fund it with Nockchain tokens.
2. Players place bets by creating transactions which lock funds in a game wallet.
3. The server shuffles and deals cards using verifiable randomness.
4. At the end of the game (consisting of multiple hands), the server creates a transaction to pay out winnings from the smart contract.
5. Game outcome is logged on-chain _de facto_ through the payout.

The server needs its own pkh for receiving bets and paying out winnings.  This can be a multisig wallet shared among multiple game servers to prevent theft, but let's punt on that for now.

The available lock types on Nockchain today are limited to time locks, hash locks, and pkh locks (whether 1-of-1 or multisig).  To implement a game wallet, we can use a pkh lock where the server holds the private key.  This is not ideal yet since it requires trust in the server operator, but it'll get us started until we have better options.

Let's assume that players already have wallets and some Nockchain tokens.  The flow for placing bets will be:

1. Player starts a new game session, generating a unique game ID.
2. Player creates a transaction sending their bet amount to the game wallet pkh, with the game ID in the memo field.
3. Server monitors the blockchain for incoming bet transactions to the game wallet.
4. Once the bet is confirmed, the server starts the game session for that player.

That means that we need to split our current single-server functionality into a server (which can handle multiple game sessions, each identified by a unique game ID) and a client (which interacts with the server and manages the player's wallet).  Each session will track the player's bankroll, current hand, and game state.

Talk me through how to implement this in the codebase.

---

Next, we need to implement the client-side setup to create and send bet transactions.  This will involve:

1. Integrating a Nockchain wallet library into the client.
2. Creating a UI for players to connect their wallet and view their balance.
3. Implementing the logic to create and send bet transactions to the game wallet.

The client-side code will need to handle wallet connections, balance checks, and transaction creation.  We can use existing Nockchain wallet libraries to facilitate this.
