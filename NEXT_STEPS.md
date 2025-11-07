# Next Steps - Phase 2 Server Integration

## Immediate Tasks

### 1. Update JavaScript to Call Server APIs

**File:** `game.js`

**Add at top:**
```javascript
let sessionId = null;  // Track server session
```

**Update `startNewGame()`:**
```javascript
async function startNewGame() {
    try {
        const response = await fetch('/blackjack/api/new-game', {
            method: 'POST'
        });
        const data = await response.json();

        sessionId = data.sessionId;
        gameState.bank = data.bank;
        gameState.winLoss = 0;
        gameState.currentBet = 0;

        updateUI();
        setStatus('New game started! Place your bet.');
    } catch (error) {
        setStatus('Error starting game: ' + error.message);
    }
}
```

**Update `dealHand()`:**
```javascript
async function dealHand() {
    if (!sessionId) {
        await startNewGame();
    }

    if (gameState.currentBet === 0) {
        setStatus('Please place a bet first!');
        return;
    }

    try {
        const response = await fetch('/blackjack/api/deal', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId,
                bet: gameState.currentBet
            })
        });
        const data = await response.json();

        // Update game state from server
        gameState.playerHand = data.playerHand;
        gameState.dealerHand = [data.dealerVisibleCard, null];  // Hide hole card
        gameState.deck = [];  // Server manages deck

        renderHands();
        updateScores();
        updateButtons();
    } catch (error) {
        setStatus('Error dealing: ' + error.message);
    }
}
```

**Update `hit()`:**
```javascript
async function hit() {
    try {
        const response = await fetch('/blackjack/api/hit', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId
            })
        });
        const data = await response.json();

        gameState.playerHand = data.hand;

        renderHands();
        updateScores();

        if (data.busted) {
            resolveHand();
        } else {
            updateButtons();
        }
    } catch (error) {
        setStatus('Error hitting: ' + error.message);
    }
}
```

**Update `stand()`:**
```javascript
async function stand() {
    try {
        const response = await fetch('/blackjack/api/stand', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId
            })
        });
        const data = await response.json();

        gameState.dealerHand = data.dealerHand;
        gameState.bank = data.bank;

        renderHands();
        updateScores();

        setStatus(data.outcome + ' - Payout: $' + data.payout);
        updateButtons();
    } catch (error) {
        setStatus('Error standing: ' + error.message);
    }
}
```

### 2. Fix Hoon JSON Parsing

**File:** `blackjack/hoon/app/app.hoon`

**Current issue (line ~162, ~208, ~240):**
```hoon
=/  session-id=@ud  0  ::  TODO: Parse from JSON body
```

**Simple fix for now:**
```hoon
::  Parse body to get session-id
=/  session-id=@ud
  ?~  body
    0
  ::  Extract first number from body (hacky but works for simple JSON)
  =/  body-text=@t  q.u.body
  ::  For now, just use 0 - proper JSON parsing TBD
  0
```

**Better approach:** Use existing JSON parser or add simple one:
```hoon
++  parse-session-id
  |=  body=(unit octs:http)
  ^-  @ud
  ?~  body  0
  ::  Look for "sessionId":123 pattern in body
  ::  Simplified for demo - real JSON parser would be better
  0
```

### 3. Implement Randomization with +tog

**File:** `blackjack/hoon/lib/blackjack.hoon`

**Current (line ~164):**
```hoon
=/  shuffled-deck=(list card:blackjack)
  (shuffle-deck:blackjack fresh-deck `@uvJ`42)
```

**Change to:**
```hoon
++  shuffle-deck
  |=  [deck=(list card) eny=@uvJ]  ::  Add entropy parameter
  ^-  (list card)
  ::  Use +tog for cryptographically secure randomization
  =/  rng  ~(. og eny)  ::  Initialize with entropy
  ::  ... existing Fisher-Yates logic ...
```

**In app.hoon deal endpoint:**
```hoon
::  Get entropy from Nock runtime
=/  shuffled-deck=(list card:blackjack)
  (shuffle-deck:blackjack fresh-deck eny)  ::  Use system entropy
```

### 4. Test Everything

**Test sequence:**
1. Start NockApp: `nockup run blackjack`
2. Open browser: `http://127.0.0.1:8080/blackjack`
3. Open DevTools Console (F12)
4. Click "New Game" - check console for API response
5. Place bet and click "Deal" - verify cards appear
6. Click "Hit" - verify new card appears
7. Click "Stand" - verify dealer plays and outcome shown

**Expected console output:**
```
POST /blackjack/api/new-game → {sessionId: 0, bank: 1000}
POST /blackjack/api/deal → {playerHand: [...], dealerHand: [...]}
POST /blackjack/api/hit → {newCard: {...}, hand: [...]}
POST /blackjack/api/stand → {outcome: "win", payout: 200, bank: 1200}
```

---

## Phase 2 Complete When...

- [ ] Browser successfully calls all 4 API endpoints
- [ ] Server returns proper JSON responses
- [ ] Game state persists across multiple rounds (same session)
- [ ] Win/loss tracking works correctly
- [ ] Bank balance updates properly
- [ ] No client-side deck/card logic (all server-side)

---

## Later Enhancements

- Proper JSON parsing in Hoon
- Session persistence (survive server restart?)
- Multiple concurrent players
- Better error messages
- Loading indicators during API calls
