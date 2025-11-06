# Phase 2: JavaScript Migration Guide

## Overview

This guide shows how to update `game.js` to use the new server-side API endpoints instead of local game logic.

## API Endpoints Available

```
POST /blackjack/api/new-game     → Create new session
POST /blackjack/api/deal          → Shuffle & deal hands
POST /blackjack/api/hit           → Draw a card
POST /blackjack/api/stand         → Dealer plays & resolve
```

## Migration Strategy

### What Stays in JavaScript
- `gameState` object (for UI state only)
- `updateDisplay()` - DOM manipulation
- `renderCard()` - Card rendering
- `updateHand()` - Hand display
- `updateBetDisplay()` - Chip display
- Button enable/disable logic

### What Gets Replaced
- `createDeck()` → Server handles
- `shuffleDeck()` → Server handles
- `calculateHandValue()` → Server handles
- `dealHand()` → API call
- `hit()` → API call
- `stand()` → API call
- `playDealerHand()` → Server handles

## Step-by-Step Changes

### 1. Add Session Management

At the top of `game.js`, add:

```javascript
// Session management
let sessionId = null;

async function initSession() {
    const response = await fetch('/blackjack/api/new-game', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'}
    });
    const data = await response.json();
    sessionId = data.sessionId;
    gameState.bank = data.bank;
    updateDisplay();
}

// Initialize on load
window.addEventListener('DOMContentLoaded', () => {
    initSession();
    initGame();
});
```

### 2. Update `dealHand()` Function

**Old (Phase 1):**
```javascript
function dealHand() {
    if (gameState.currentBet === 0) {
        setStatus('Please place a bet first.');
        return;
    }

    // Deduct bet
    gameState.bank -= gameState.currentBet;

    // Create and shuffle deck locally
    gameState.deck = createDeck();
    gameState.deck = shuffleDeck(gameState.deck);

    // Deal cards
    gameState.playerHand = [
        gameState.deck.pop(),
        gameState.deck.pop()
    ];
    gameState.dealerHand = [
        gameState.deck.pop(),
        gameState.deck.pop()
    ];

    // ... rest of logic
}
```

**New (Phase 2):**
```javascript
async function dealHand() {
    if (gameState.currentBet === 0) {
        setStatus('Please place a bet first.');
        return;
    }

    // Deduct bet (optimistic update)
    gameState.bank -= gameState.currentBet;
    updateDisplay();

    try {
        const response = await fetch('/blackjack/api/deal', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId,
                bet: gameState.currentBet
            })
        });

        if (!response.ok) {
            throw new Error('Deal failed');
        }

        const data = await response.json();

        // Update game state from server
        gameState.playerHand = data.playerHand;
        gameState.dealerHand = data.dealerHand;
        gameState.gameInProgress = true;
        gameState.dealerTurn = false;

        updateDisplay();

        // Enable buttons
        document.getElementById('hit-btn').disabled = false;
        document.getElementById('stand-btn').disabled = false;
        document.getElementById('deal-btn').disabled = true;

        // Enable special actions if conditions met
        if (gameState.bank >= gameState.currentBet) {
            document.getElementById('double-btn').disabled = false;
        }
        document.getElementById('surrender-btn').disabled = false;

        setStatus(`Player: ${data.playerScore}. Hit or Stand?`);

    } catch (error) {
        console.error('Deal error:', error);
        // Rollback optimistic update
        gameState.bank += gameState.currentBet;
        updateDisplay();
        setStatus('Error dealing cards. Please try again.');
    }
}
```

### 3. Update `hit()` Function

**Old:**
```javascript
function hit() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    disableSpecialActions();

    // Draw locally
    gameState.playerHand.push(gameState.deck.pop());
    updateDisplay();

    const playerValue = calculateHandValue(gameState.playerHand);
    // ... handle bust/21
}
```

**New:**
```javascript
async function hit() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    disableSpecialActions();
    document.getElementById('hit-btn').disabled = true;  // Prevent double-click

    try {
        const response = await fetch('/blackjack/api/hit', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({sessionId: sessionId})
        });

        if (!response.ok) {
            throw new Error('Hit failed');
        }

        const data = await response.json();

        // Update from server
        gameState.playerHand = data.hand;
        updateDisplay();

        if (data.busted) {
            gameState.dealerTurn = true;
            updateDisplay();
            resolveLoss('Player busts!');
        } else if (data.score === 21) {
            stand();  // Auto-stand on 21
        } else {
            document.getElementById('hit-btn').disabled = false;
            setStatus(`Score: ${data.score}. Hit or Stand?`);
        }

    } catch (error) {
        console.error('Hit error:', error);
        document.getElementById('hit-btn').disabled = false;
        setStatus('Error drawing card. Please try again.');
    }
}
```

### 4. Update `stand()` Function

**Old:**
```javascript
function stand() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    gameState.dealerTurn = true;
    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;

    updateDisplay();
    setStatus('Dealer\'s turn...');

    setTimeout(playDealerHand, 1000);
}

function playDealerHand() {
    const dealerValue = calculateHandValue(gameState.dealerHand);
    if (dealerValue < 17) {
        gameState.dealerHand.push(gameState.deck.pop());
        updateDisplay();
        setTimeout(playDealerHand, 1000);
    } else {
        // Resolve...
    }
}
```

**New:**
```javascript
async function stand() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    gameState.dealerTurn = true;
    disableSpecialActions();
    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;

    updateDisplay();
    setStatus('Dealer\'s turn...');

    try {
        const response = await fetch('/blackjack/api/stand', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({sessionId: sessionId})
        });

        if (!response.ok) {
            throw new Error('Stand failed');
        }

        const data = await response.json();

        // Update dealer hand from server
        gameState.dealerHand = data.dealerHand;
        updateDisplay();

        // Handle outcome
        gameState.bank = data.bank;

        let message = '';
        switch(data.outcome) {
            case 'win':
                message = `You win $${data.payout}!`;
                gameState.winLoss += (data.payout - gameState.currentBet);
                break;
            case 'loss':
                message = 'Dealer wins.';
                gameState.winLoss -= gameState.currentBet;
                break;
            case 'push':
                message = 'Push (tie).';
                break;
            case 'blackjack':
                message = `Blackjack! You win $${data.payout}!`;
                gameState.winLoss += (data.payout - gameState.currentBet);
                break;
        }

        endRound(message);

    } catch (error) {
        console.error('Stand error:', error);
        setStatus('Error resolving hand. Please refresh.');
    }
}
```

### 5. Remove Unused Functions

Delete these functions (server now handles them):
- `createDeck()`
- `shuffleDeck()`
- `calculateHandValue()`
- `playDealerHand()`
- `resolveWin()`, `resolveLoss()`, `resolveBlackjack()` - merge into stand handler

Keep these helper functions:
- `renderCard()`
- `updateDisplay()`
- `updateHand()`
- `updateBetDisplay()`
- `setStatus()`
- `endRound()` (but simplify it)

### 6. Simplified `endRound()`

**New version:**
```javascript
function endRound(message) {
    gameState.gameInProgress = false;
    gameState.currentBet = 0;

    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;
    document.getElementById('double-btn').disabled = true;
    document.getElementById('split-btn').disabled = true;
    document.getElementById('surrender-btn').disabled = true;

    updateDisplay();
    setStatus(message + ' Place your bet for the next hand.');

    if (gameState.bank < 1) {
        setStatus(message + ' Game over! Click New Game to restart.');
    }
}
```

## Error Handling

Add global error handler:

```javascript
window.addEventListener('unhandledrejection', event => {
    console.error('Unhandled promise rejection:', event.reason);
    setStatus('Network error. Please check connection.');
});
```

## Testing Checklist

After migration:
- [ ] Game initializes and gets session ID
- [ ] Betting works
- [ ] Deal button triggers server shuffle
- [ ] Cards display correctly from server data
- [ ] Hit draws cards from server
- [ ] Stand triggers dealer play
- [ ] Outcomes calculated correctly
- [ ] Bank updates match server
- [ ] Errors are handled gracefully
- [ ] Network failures show user-friendly messages

## Debugging Tips

1. **Check Network Tab**: See actual API calls
2. **Console Errors**: Watch for JSON parse errors
3. **Server Logs**: Check Hoon dojo for errors
4. **State Inspection**: Log `gameState` after each API call

```javascript
// Add after each API response
console.log('Server response:', data);
console.log('Game state:', gameState);
```

## Next Steps

After JavaScript is migrated:
1. Test thoroughly
2. Add remaining endpoints (double, split, surrender)
3. Improve JSON parsing (currently hardcoded session-id = 0)
4. Add proper session persistence
5. Consider wallet integration

---

**Key Insight**: The JavaScript becomes much simpler! Just UI updates and API calls. All game logic lives in Hoon where it can be audited and trusted.
