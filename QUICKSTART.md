# Blackjack NockApp - Quick Start

## The Fastest Way to Get Running

### Prerequisites

- Running Urbit ship
- Mounted desk (we'll use `%blackjack`)

### 5-Minute Setup

```bash
# 1. On your ship
|merge %blackjack our %base
|mount %blackjack

# 2. Copy Hoon files
cd /path/to/your/pier/blackjack/
cp -r /path/to/this/repo/hoon/* .
cp /path/to/this/repo/desk.bill .

# 3. For quick testing with embedded content:
# Edit lib/blackjack-static.hoon and replace the placeholders
# with your actual HTML, CSS, and JS

# OR for file-based loading:
mkdir -p app/blackjack/img
cp /path/to/this/repo/index.html app/blackjack/
cp /path/to/this/repo/style.css app/blackjack/
cp /path/to/this/repo/game.js app/blackjack/
cp /path/to/this/repo/img/sprites.png app/blackjack/img/

# 4. Back on your ship
|commit %blackjack
|install our %blackjack

# 5. Access the game
# Visit: http://localhost:8080/blackjack
```

### What You Should See

1. The game interface loads in your browser
2. All styles are applied (Windows 3.1 look)
3. Chips and cards appear correctly
4. Game functions work (betting, hitting, standing, etc.)

### If Something Goes Wrong

**App won't compile:**
```
|commit %blackjack
# Read the error messages carefully
```

**404 errors:**
```
# Check binding
:blackjack +dbug
```

**Sprites not loading:**
- Temporarily use an external URL for the sprite image
- Or convert to base64 (see NOCKAPP_DEPLOYMENT.md)

### File Loading vs Embedded

**For Development → Use File Loading**
- Edit `lib/blackjack-static.hoon`
- Uncomment the scry-based arms
- Comment out the embedded cords
- Easier to iterate

**For Distribution → Use Embedded**
- Edit `lib/blackjack-static.hoon`
- Replace placeholders with actual content
- Use triple-quote syntax: `'''content'''`
- Self-contained desk

### Next: Phase 2

Once this works, you can:
1. Add POST endpoints for game actions
2. Move deck shuffling to Hoon
3. Store game state on Urbit
4. Use HTMX for seamless server updates

See NOCKAPP_DEPLOYMENT.md for full details.
