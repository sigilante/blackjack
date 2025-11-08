# Blackjack NockApp - Project Status

**Last Updated:** November 7, 2024
**Status:** Phase 1 Complete, Ready for Phase 2 Server Integration

---

## Current State

### ✅ What's Working

#### Frontend (Browser-Only Game)
- **Full blackjack gameplay** with client-side logic
- **Windows 3.1 aesthetic** with card sprites and poker chips
- **Game features implemented:**
  - Hit, Stand, Double Down, Split, Surrender
  - Proper ace handling (1 or 11)
  - Dealer AI (hits on < 17)
  - Bet tracking and win/loss calculation
  - Visual chip stacking for bet display

#### NockApp Infrastructure
- **Static file serving** working correctly
- **HTTP routing** functional at `/blackjack/*`
- **Cache bug identified and fixed** (see CACHE_FIX_SUMMARY.md)
- **Ford runes** loading all static resources (HTML, CSS, JS, PNG)

#### Server-Side Game Logic (Hoon)
- **Complete game library** (`blackjack/hoon/lib/blackjack.hoon`, 268 lines)
  - Deck creation and shuffling
  - Hand value calculation with ace adjustment
  - Dealer AI logic
  - Outcome resolution
  - JSON serialization functions

- **Server state management** (`blackjack/hoon/app/app.hoon`, 282 lines)
  - Session tracking (map of session-id → game-state)
  - Session ID generation

- **API Endpoints Implemented:**
  - `POST /blackjack/api/new-game` - Create new session
  - `POST /blackjack/api/deal` - Deal initial hand
  - `POST /blackjack/api/hit` - Draw a card
  - `POST /blackjack/api/stand` - Stand and resolve

### ⚠️ Known Issues

1. **HTTP Cache Bug (FIXED)**
   - **Problem:** NockApp HTTP driver caches by parent path only
   - **Impact:** All `/blackjack/*` requests returned same cached response
   - **Status:** Fix created in `http.rs.fixed` - ready for upstream PR
   - **Workaround:** Cache-control headers added (limited effectiveness)

2. **Randomization Not Implemented**
   - **Current:** Uses hardcoded seed `42` for shuffling
   - **Needed:** Use `+tog` (cryptographically secure RNG) instead of `+og`
   - **Impact:** Predictable card order in server-side mode

3. **JSON Parsing Not Implemented**
   - **Current:** Hardcoded `session-id = 0` in POST handlers
   - **Needed:** Parse request body to extract session-id and other params
   - **Impact:** Only single session works in server mode

---

## Architecture

### File Structure
```
blackjack/
├── index.html              # Main game interface
├── style.css              # Windows 3.1 styling + sprite positions
├── game.js                # Client-side game logic (15KB)
├── img/sprites.png        # Card and chip sprites
├── blackjack.toml         # NockApp config
└── blackjack/
    ├── hoon/
    │   ├── app/
    │   │   └── app.hoon              # Main Gall agent (282 lines)
    │   ├── lib/
    │   │   ├── blackjack.hoon        # Game logic library (268 lines)
    │   │   └── http.hoon             # HTTP utilities
    │   └── common/
    │       └── wrapper.hoon          # NockApp wrapper
    └── src/
        └── main.rs                   # Rust entry point
```

### Data Flow (Phase 2 Target)

```
Browser                  NockApp HTTP Driver           Hoon App
   │                            │                          │
   ├─── POST /api/new-game ────>│                          │
   │                            ├─── poke ────────────────>│
   │                            │                          ├─ create session
   │                            │<──── res ────────────────┤   assign ID
   │<────── JSON response ──────┤                          │   return JSON
   │                            │                          │
   ├─── POST /api/deal ────────>│                          │
   │    (with session-id)       ├─── poke ────────────────>│
   │                            │                          ├─ shuffle deck
   │                            │                          ├─ deal cards
   │                            │<──── res ────────────────┤   calculate score
   │<────── JSON response ──────┤                          │   return hands
   │                            │                          │
   ├─── POST /api/hit ─────────>│                          │
   │    (with session-id)       ├─── poke ────────────────>│
   │                            │                          ├─ draw card
   │                            │<──── res ────────────────┤   update hand
   │<────── JSON response ──────┤                          │   check bust
   │                            │                          │
   └─── POST /api/stand ───────>│                          │
        (with session-id)       ├─── poke ────────────────>│
                                │                          ├─ dealer plays
                                │                          ├─ resolve outcome
                                │<──── res ────────────────┤   update bank
        <────── JSON response ──┤                          │   return result
```

---

## Next Steps (Phase 2: Server Integration)

### Priority 1: JavaScript Client Updates
**Goal:** Migrate from client-side logic to server API calls

**Files to modify:** `game.js`

**Changes needed:**

1. **Session Management**
   ```javascript
   let sessionId = null;

   async function startNewGame() {
       const response = await fetch('/blackjack/api/new-game', {
           method: 'POST'
       });
       const data = await response.json();
       sessionId = data.sessionId;
       gameState.bank = data.bank;
       // Update UI
   }
   ```

2. **Deal Handler**
   ```javascript
   async function dealHand() {
       if (!sessionId) await startNewGame();

       const response = await fetch('/blackjack/api/deal', {
           method: 'POST',
           headers: {'Content-Type': 'application/json'},
           body: JSON.stringify({
               sessionId: sessionId,
               bet: gameState.currentBet
           })
       });
       const data = await response.json();
       // Update player/dealer hands from server response
   }
   ```

3. **Hit/Stand Handlers**
   - Similar pattern: POST with sessionId
   - Receive updated game state from server
   - Update UI to reflect server state

**Keep client-side:**
- UI rendering
- Bet placement logic
- Button state management
- Visual effects

**Move to server:**
- Deck shuffling
- Card dealing
- Hand value calculation
- Outcome resolution

### Priority 2: Hoon App Improvements

**File:** `blackjack/hoon/app/app.hoon`

**Changes needed:**

1. **JSON Parsing**
   ```hoon
   ::  Parse JSON request body
   ++  parse-json-body
     |=  body=(unit octs:http)
     ^-  (unit (map @t *))
     ?~  body  ~
     ::  TODO: Implement JSON parser
     ::  For now, extract session-id from simple JSON
   ```

2. **Randomization with +tog**
   ```hoon
   ::  In deal endpoint
   =/  shuffled-deck=(list card:blackjack)
     (shuffle-deck:blackjack fresh-deck (need eny))  :: Use entropy
   ```

3. **Error Handling**
   - Return 404 if session-id not found
   - Return 400 if invalid bet amount
   - Return proper error JSON messages

### Priority 3: Testing

1. **Unit Tests** (if NockApp supports)
   - Test game logic functions in isolation
   - Test JSON serialization

2. **Integration Tests**
   - Full game flow: new-game → deal → hit/stand
   - Multiple concurrent sessions
   - Edge cases (splitting aces, double down, etc.)

3. **Manual Testing Checklist**
   - [ ] Create new game session
   - [ ] Place bet and deal
   - [ ] Hit multiple times
   - [ ] Stand and see dealer play
   - [ ] Win/loss/push outcomes
   - [ ] Bank balance updates correctly
   - [ ] Multiple rounds in same session
   - [ ] Browser refresh (session persistence?)

---

## Phase 3 & 4 (Future)

### Phase 3: Nockchain Wallet Integration
- Replace bank tracking with actual cryptocurrency
- Connect to fakenet for testing
- Implement wallet signing for bets

### Phase 4: Enhanced Gameplay
- Multiple concurrent players
- Tournament mode
- Leaderboards
- Side bets (insurance, etc.)

---

## Development Commands

```bash
# Build NockApp
nockup build blackjack

# Run locally
nockup run blackjack

# Access game
open http://127.0.0.1:8080/blackjack

# View logs
# Look for "Received request", "Matched route", etc.
```

---

## Key Technical Decisions

1. **HTMX loaded but not used** - Loaded for future enhancements, currently using fetch API
2. **Cache-control headers added** - Don't fully work due to driver bug, but ready for fixed driver
3. **Windows 3.1 aesthetic** - Beveled borders, specific color palette (#c0c0c0, #008080, etc.)
4. **Sprite-based graphics** - 71x96 cards, 45x45 chips from single PNG
5. **Session-based architecture** - Server tracks multiple games by session-id

---

## Documentation

- **CACHE_FIX_SUMMARY.md** - HTTP cache bug fix for upstream
- **http.rs.fixed** - Fixed HTTP driver ready for PR
- **QUICKSTART.md** - Basic setup instructions
- **README.md** - Project overview
- **docs/archive/** - Old phase documentation

---

## Questions / Blockers

None currently - ready to proceed with Phase 2 implementation!
