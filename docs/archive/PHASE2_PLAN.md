# Phase 1 Review & Phase 2 Plan

## Current State (Phase 1) - What You Have

### ✅ File Structure
```
blackjack/
├── hoon/
│   ├── app/blackjack.hoon          # Gall agent (128 lines)
│   ├── lib/blackjack-static.hoon   # Static content (89 lines, placeholders)
│   └── sur/blackjack.hoon          # Type defs (27 lines)
├── Browser Game (working):
│   ├── index.html                  # 4.7K - Full UI
│   ├── style.css                   # 11K - Win3.1 styling
│   ├── game.js                     # 15K - All game logic
│   └── img/sprites.png             # 57K - Cards & chips
└── Configuration:
    ├── desk.bill
    └── docs (NOCKAPP_DEPLOYMENT.md, QUICKSTART.md)
```

### ✅ What Works (In Theory)
Your Hoon app structure is solid:
- **HTTP routing**: GET endpoints for `/blackjack`, `/style.css`, `/game.js`, `/img/sprites.png`
- **Response handling**: Proper Content-Type headers
- **Gall agent**: Standard structure with `on-init`, `on-poke`, `on-watch`, etc.
- **Eyre binding**: Connects to `/blackjack` path

### ⚠️ What Needs Attention for NockApp

Since you're deploying to **NockApp** (not a full Urbit ship):

1. **No Clay filesystem** - The file loading option won't work
   - Must use embedded content (Option B)
   - Need to actually embed your HTML/CSS/JS

2. **Content currently placeholders** - `lib/blackjack-static.hoon` has:
   - Minimal HTML placeholder
   - Minimal CSS placeholder
   - Minimal JS placeholder
   - Empty PNG (`*@`)

3. **Must embed everything** - For NockApp deployment:
   - Replace placeholders with actual content
   - Embed sprites.png as base64 or reference external URL

### 📊 Phase 1 Assessment

**Architecture**: ✅ Excellent
**HTTP Routing**: ✅ Correct
**Content**: ❌ Needs embedding
**Ready to deploy**: 🔶 After embedding content

---

## Phase 2 Plan - Server-Side Game Logic

### Goals
Move from "Hoon serves files" → "Hoon runs the game"

### What Stays Client-Side (JavaScript)
- UI rendering (DOM manipulation)
- User input handling (button clicks)
- Animation (card dealing, chip stacking)
- Display updates (showing cards, scores)

### What Moves Server-Side (Hoon)
- **Deck management**: Shuffling, drawing cards
- **Game state**: Current hands, bets, bank
- **Game rules**: Hit/stand logic, bust detection, dealer AI
- **Outcome resolution**: Win/loss calculation

### Architecture Changes

#### Current (Phase 1):
```
Browser
  ↓
  JavaScript does everything
  (shuffle, deal, hit, stand, calculate)
  ↓
  DOM updates
```

#### Phase 2:
```
Browser                          NockApp
  ↓                               ↓
  User clicks "Deal"       →  POST /api/deal
  ←  JSON response             Hoon shuffles deck
  ↓                            Deals cards
  JavaScript updates DOM       Updates game-state
                              Returns hand data
```

### New HTTP Endpoints to Add

```hoon
%'POST'
  [%blackjack %api %new-game ~]
  :: Initialize game with starting bank
  :: Returns: {bank: 1000, currentBet: 0}

  [%blackjack %api %place-bet ~]
  :: Body: {amount: 25}
  :: Returns: {success: true, currentBet: 25, bank: 975}

  [%blackjack %api %deal ~]
  :: Shuffles deck, deals initial hands
  :: Returns: {
  ::   playerHand: [{suit: 'hearts', rank: 'A'}, ...],
  ::   dealerHand: [{suit: 'spades', rank: 'K'}, {hidden: true}],
  ::   playerScore: 21,
  ::   ...
  :: }

  [%blackjack %api %hit ~]
  :: Draws card for player
  :: Returns: {card: {...}, newScore: 18, busted: false}

  [%blackjack %api %stand ~]
  :: Triggers dealer play
  :: Returns: {dealerHand: [...], outcome: 'win', payout: 50}

  [%blackjack %api %double ~]
  :: Double down logic

  [%blackjack %api %surrender ~]
  :: Surrender logic
```

### State Management

Update `state-0` in `app/blackjack.hoon`:

```hoon
+$  state-0
  $:  %0
      ::  Map of session-id to game state
      games=(map @ta game-state)
      ::
      ::  For NockApp, session-id could be:
      ::  - Browser session ID
      ::  - Wallet address (future)
      ::  - Simple counter for single-player
  ==
```

### Hoon Game Logic to Implement

Add to `lib/blackjack-game.hoon` (new file):

```hoon
|%
++  create-deck
  :: Generate fresh 52-card deck

++  shuffle-deck
  :: Fisher-Yates shuffle using Hoon's random

++  deal-initial-hand
  :: Draw 2 cards for player, 2 for dealer

++  calculate-hand-value
  :: Sum card values, handle aces

++  should-dealer-hit
  :: Dealer logic: hit on 16, stand on 17+

++  resolve-outcome
  :: Compare hands, calculate payout
--
```

### JavaScript Changes

Minimal! Just change from local functions to API calls:

**Before (Phase 1):**
```javascript
function dealHand() {
    gameState.deck = createDeck();
    gameState.playerHand = [
        gameState.deck.pop(),
        gameState.deck.pop()
    ];
    // ... more local logic
}
```

**After (Phase 2):**
```javascript
async function dealHand() {
    const response = await fetch('/blackjack/api/deal', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({sessionId: getSessionId()})
    });
    const data = await response.json();

    gameState.playerHand = data.playerHand;
    gameState.dealerHand = data.dealerHand;
    updateDisplay();
}
```

### Data Flow Example: "Hit" Action

```
1. User clicks "Hit" button
   ↓
2. JavaScript: fetch('/blackjack/api/hit', {method: 'POST'})
   ↓
3. Hoon receives poke with %handle-http-request
   ↓
4. Route to [%blackjack %api %hit ~]
   ↓
5. Hoon game logic:
   - Look up game state by session ID
   - Draw card from deck
   - Add to player hand
   - Calculate new score
   - Check for bust
   ↓
6. Hoon returns JSON:
   {
     card: {suit: 'diamonds', rank: '7'},
     newScore: 18,
     busted: false,
     hand: [full hand array]
   }
   ↓
7. JavaScript receives response
   ↓
8. Update DOM:
   - Add card element to display
   - Update score display
   - Check if busted (disable buttons)
```

### Session Management

For NockApp (no ship identity), options:

1. **Simple counter** (single player):
   ```hoon
   games=(map @ud game-state)  :: Key = 0, 1, 2...
   ```

2. **Browser session ID**:
   ```javascript
   // Client generates/stores
   const sessionId = localStorage.getItem('sessionId') || generateSessionId();
   ```

3. **Future: Wallet integration**:
   ```hoon
   games=(map @ux game-state)  :: Key = Ethereum address
   ```

### Benefits of Phase 2

1. **Provably fair**: Deck shuffle happens server-side, can be audited
2. **State persistence**: Game survives browser refresh
3. **Foundation for multiplayer**: State is server-side
4. **Security**: Bank/bet validation on server
5. **Future wallet integration**: Easy to add later

### Migration Path

**Step 1**: Embed content (finish Phase 1)
- Get current game working in NockApp
- Verify all routes work
- Confirm sprites load

**Step 2**: Add POST handlers (parallel development)
- Keep GET routes working
- Add POST endpoints one at a time
- Test each endpoint independently

**Step 3**: Add Hoon game library
- Implement deck functions
- Implement hand calculation
- Implement game rules

**Step 4**: Update JavaScript incrementally
- Replace `dealHand()` first
- Then `hit()`, `stand()`, etc.
- Keep working game at each step

**Step 5**: Remove old JavaScript logic
- Clean up local game state
- Remove shuffle/deal functions
- Keep only UI and API calls

### What to Tackle First?

**For Phase 2, I recommend:**

1. **Finish Phase 1 embedding** (necessary first)
   - Embed actual HTML/CSS/JS in `lib/blackjack-static.hoon`
   - Deploy and test in NockApp
   - Verify game works as-is

2. **Add simplest endpoint**: `/api/new-game`
   - Just returns `{bank: 1000}`
   - Test POST handling works
   - Learn JSON encoding in Hoon

3. **Add `/api/shuffle`**
   - Implement deck creation and shuffle in Hoon
   - Return shuffled deck as JSON
   - Verify randomness works

4. **Add `/api/deal`**
   - Use shuffled deck from state
   - Return initial hands
   - This is the "hello world" of Phase 2

Then build from there!

---

## Questions for You

1. **Do you have NockApp running locally?** Can you deploy and test?

2. **Content embedding preference?**
   - Shall I help embed your actual HTML/CSS/JS into the lib file?
   - Or will you handle that part?

3. **Phase 2 scope?**
   - Just deal/hit/stand? (minimum viable)
   - Or include double down, split, surrender?
   - Multi-session support or single player?

4. **Randomness**: Do you know how random number generation works in NockApp's Hoon environment?

Let me know what you'd like to tackle first!
