# Blackjack NockApp - Phase 1 Deployment Guide

This guide covers deploying the blackjack game as a NockApp that serves static files.

## Phase 1 Overview

In Phase 1, we're serving the existing browser-based game through Urbit:
- **Server**: Hoon app serves HTML, CSS, JS, and images
- **Game Logic**: Still runs client-side in JavaScript
- **State**: Managed in browser, not on Urbit (yet)

## File Structure

```
blackjack/
├── hoon/
│   ├── app/
│   │   └── blackjack.hoon          # Main Gall agent
│   ├── lib/
│   │   └── blackjack-static.hoon   # Static file serving
│   └── sur/
│       └── blackjack.hoon          # Type definitions
├── desk.bill                        # Auto-start configuration
├── index.html                       # Browser game files (existing)
├── style.css
├── game.js
└── img/
    └── sprites.png
```

## Deployment Methods

### Method 1: Embedded Content (Simplest)

**For quick testing - manually embed files in Hoon**

1. **Edit `hoon/lib/blackjack-static.hoon`**:
   - Replace the placeholder `index-html` with your actual HTML
   - Replace the placeholder `style-css` with your actual CSS
   - Replace the placeholder `game-js` with your actual JavaScript
   - Use Hoon's triple-quote syntax: `'''your content here'''`

2. **For the sprite image**, you have options:
   - **Option A**: Convert to base64 and embed
   - **Option B**: Temporarily reference from external CDN
   - **Option C**: Use file loading (see Method 2)

### Method 2: File Loading (Recommended for Development)

**Load files from desk at runtime**

1. **Create desk directory structure**:
   ```bash
   mkdir -p /path/to/your/desk/app/blackjack/
   ```

2. **Copy static files to desk**:
   ```bash
   cp index.html /path/to/your/desk/app/blackjack/index.html
   cp style.css /path/to/your/desk/app/blackjack/style.css
   cp game.js /path/to/your/desk/app/blackjack/game.js
   cp img/sprites.png /path/to/your/desk/app/blackjack/sprites.png
   ```

3. **Edit `hoon/lib/blackjack-static.hoon`**:
   - Comment out the embedded versions
   - Uncomment the file loading versions (lines 21-37)
   - Adjust the scry paths to match your desk structure

4. **Note**: Clay (Urbit's filesystem) requires files to have specific naming:
   - `index.html` → stored as `index.html` in desk
   - Accessed via scry: `/app/blackjack/index/html`
   - The path drops the `.` and treats extension as final path element

## Installation Steps

### 1. Create a New Desk

On your Urbit ship:

```
|merge %blackjack our %base
|mount %blackjack
```

### 2. Copy Hoon Files

Copy the `hoon/` directory contents to your mounted desk:

```bash
# From your blackjack project directory
cp -r hoon/* /path/to/pier/blackjack/
cp desk.bill /path/to/pier/blackjack/
```

### 3. Commit Changes

```
|commit %blackjack
```

### 4. Install the Desk

```
|install our %blackjack
```

### 5. Start the App

```
|start %blackjack
```

The app should auto-start if listed in `desk.bill`, but you can manually start it with the command above.

## Accessing the Game

Once running, access your game at:

```
http://localhost:8080/blackjack
```

Or from your ship URL:
```
https://your-ship.arvo.network/blackjack
```

## Troubleshooting

### App Won't Start

Check for Hoon syntax errors:
```
|commit %blackjack
```

Look for error messages in the output.

### 404 Errors

1. **Verify binding**: Check that Eyre bound the path
   ```
   |pass [%e %disconnect [~ /blackjack]]
   |pass [%e %connect [~ /blackjack] %blackjack]
   ```

2. **Check app status**:
   ```
   :blackjack +dbug
   ```

### Content Not Loading

1. **If using file loading**: Verify files are in the correct desk location
2. **If using embedded content**: Check that the content is properly escaped in Hoon
3. **Check Content-Type headers**: Make sure they match the file types

### Sprite Image Issues

The PNG sprite is the trickiest part. For Phase 1:

**Quick fix**: Update `style.css` and `game.js` to reference a temporary external sprite:
```css
.card {
    background-image: url('https://your-cdn.com/sprites.png');
}
```

**Proper fix**: Convert PNG to base64:
```bash
base64 img/sprites.png > sprites.b64.txt
```

Then embed in Hoon as a cord and decode when serving.

## Next Steps: Phase 2

Once Phase 1 is working, Phase 2 will add:
- Server-side deck shuffling in Hoon
- POST endpoints for game actions (`/api/deal`, `/api/hit`, etc.)
- Game state stored on Urbit
- JavaScript updated to call Hoon endpoints via fetch()

## File Reference

### Key Hoon Files

**`hoon/app/blackjack.hoon`** - Main Gall agent
- Handles HTTP requests
- Routes to static content
- Will eventually handle game logic

**`hoon/lib/blackjack-static.hoon`** - Static content
- Contains embedded or loaded files
- Exports: `index-html`, `style-css`, `game-js`, `sprites-png`

**`hoon/sur/blackjack.hoon`** - Type definitions
- Data structures for cards, hands, game state
- Used in Phase 2+ for server-side logic

## Development Tips

1. **Use file loading during development** - easier to iterate
2. **Test locally first** - use Python server to verify game works
3. **Switch to embedded for distribution** - no external file dependencies
4. **Check the dojo** - errors will show up there when you commit

## Questions?

- Check logs: `|verb` in dojo to see HTTP requests
- Debug state: `:blackjack +dbug` to inspect app state
- Review: Look at the nockup HTTP server template for examples

---

**Current Status**: Phase 1 template ready
**Next Task**: Choose deployment method and populate static files
**Goal**: See your game running at `http://localhost:8080/blackjack`
