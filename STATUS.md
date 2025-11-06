# Blackjack NockApp - Current Status

## What's Working ✅

### Browser Game (Standalone)
- Fully functional blackjack game
- Windows 3.1 aesthetic
- All features implemented:
  - Hit, Stand, Deal
  - Double Down, Split, Surrender
  - Visual bet display with chip sprites
  - Card display from spritesheet
  - Bank management ($1000 starting)
  - Win/loss tracking

**Test it**: `python3 server.py` → http://localhost:8000/

### Files Ready
- `index.html` (4.7K) - Complete UI
- `style.css` (11K) - Full styling with mask color
- `game.js` (15K) - All game logic implemented
- `img/sprites.png` (57K) - Cards and chips

## What's Built (Not Yet Deployed) 🏗️

### NockApp Structure
- `hoon/app/blackjack.hoon` - Gall agent with HTTP routing
- `hoon/lib/blackjack-static.hoon` - Static file serving (placeholders)
- `hoon/sur/blackjack.hoon` - Type definitions
- `desk.bill` - Configuration

### HTTP Routes Defined
```
GET  /blackjack              → index.html
GET  /blackjack/style.css    → CSS
GET  /blackjack/game.js      → JavaScript
GET  /blackjack/img/sprites.png → Sprite image
```

## What Needs to Happen Next 📋

### To Complete Phase 1 (Static Serving)

**Option 1: Quick Test**
1. Embed just the HTML placeholder
2. Update CSS to use external sprite temporarily
3. Deploy to NockApp
4. Verify routing works

**Option 2: Full Embed**
1. Replace placeholders in `hoon/lib/blackjack-static.hoon`
2. Embed actual HTML (4.7K)
3. Embed actual CSS (11K)
4. Embed actual JS (15K)
5. Handle sprite (57K) - base64 or external reference
6. Deploy to NockApp
7. Test at NockApp URL

### For Phase 2 (Server-Side Logic)

See `PHASE2_PLAN.md` for detailed roadmap.

Key steps:
1. Add POST endpoints
2. Implement Hoon game logic
3. Update JavaScript to call APIs
4. Manage state in Gall agent

## File Organization

```
Current Working Tree:
.
├── index.html              # Browser game (working)
├── style.css
├── game.js
├── img/sprites.png
├── server.py              # Test server
│
├── hoon/                  # NockApp code (ready)
│   ├── app/blackjack.hoon
│   ├── lib/blackjack-static.hoon    ⚠️ Has placeholders
│   └── sur/blackjack.hoon
│
├── desk.bill
│
└── docs/
    ├── NOCKAPP_DEPLOYMENT.md
    ├── QUICKSTART.md
    └── PHASE2_PLAN.md         # Future roadmap
```

## Key Decisions Needed

1. **For Phase 1 deployment:**
   - How does content get into NockApp? (Build process? Manual?)
   - Where does NockApp read files from?
   - How to handle 57K PNG sprite?

2. **For Phase 2 planning:**
   - Which features to implement first?
   - Session management strategy?
   - JSON encoding preferences?

## Next Action

**Recommended**: Clarify NockApp deployment workflow, then either:
- Embed content and deploy Phase 1, OR
- Jump to Phase 2 with minimal Phase 1 (just prove routing works)

Your call! 🎰
