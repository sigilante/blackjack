# Testing Server Integration

## Quick Test Steps

### 1. Build and Run
```bash
cd /home/user/blackjack
nockup build blackjack
nockup run blackjack
```

### 2. Open Browser
Navigate to: `http://127.0.0.1:8080/blackjack`

### 3. Open Browser Console
Press `F12` to open DevTools, go to Console tab

### 4. Test Flow

1. **Click "New Game"**
   - Console should show: `New game started (Session: 0)`
   - Look for: `POST /blackjack/api/new-game`
   - Response should have: `{sessionId: 0, bank: 1000}`

2. **Place a bet** (click chip buttons, e.g., $10)
   - "Deal" button should enable

3. **Click "Deal"**
   - Console should show: `Deal response: {...}`
   - Cards should appear on screen
   - Look for: `POST /blackjack/api/deal`
   - Response should have: `{playerHand: [[...]], dealerHand: [[...]], ...}`

4. **Click "Hit"**
   - New card should appear
   - Console should show: `Hit response: {...}`
   - Look for: `POST /blackjack/api/hit`
   - Response should have: `{newCard: {...}, hand: [...], score: X, busted: false}`

5. **Click "Stand"** (or keep hitting)
   - Dealer cards appear
   - Outcome displayed
   - Bank balance updates
   - Console should show: `Stand response: {...}`
   - Look for: `POST /blackjack/api/stand`
   - Response should have: `{dealerHand: [...], outcome: "win/loss/push", payout: X, bank: Y}`

## Expected Server Logs

Look for these in the terminal where `nockup run` is running:

```
"Received request: %'POST' '/blackjack/api/new-game'"
"Matched route: /blackjack/api/new-game" (if implemented)

"Received request: %'POST' '/blackjack/api/deal'"
"Deal endpoint processing..."

"Received request: %'POST' '/blackjack/api/hit'"
"Hit endpoint processing..."

"Received request: %'POST' '/blackjack/api/stand'"
"Stand endpoint processing..."
```

## What to Check

### ✅ Success Indicators
- [ ] New Game creates session (ID shown in status)
- [ ] Deal shows 2 player cards, 2 dealer cards
- [ ] Hit adds cards to player hand
- [ ] Stand shows all dealer cards
- [ ] Outcome is calculated (win/loss/push)
- [ ] Bank balance updates correctly
- [ ] Can play multiple rounds

### ⚠️ Known Issues (Ignore for Now)
- Session ID is always 0 (JSON parsing not implemented)
- Same shuffle every time (randomization not implemented)
- No validation errors (validation not implemented)

## Debugging

If something doesn't work:

### Check Browser Console
- Look for JavaScript errors
- Check API responses (expand objects)
- Verify data structure matches expectations

### Check Server Logs
- Are requests reaching the server?
- Are routes matching?
- Any Hoon runtime errors?

### Common Issues

1. **404 errors**: Routes not matching
   - Check URLs: `/blackjack/api/new-game` not `/api/new-game`

2. **500 errors**: Server-side error
   - Check Hoon logs for error messages
   - May be type conversion issues

3. **Cards not rendering**: Data format mismatch
   - Check console log of API response
   - Verify card format: `{suit: "hearts", rank: "A"}`

4. **Empty hands**: Array indexing issue
   - Server returns `playerHand: [[cards]]` (list of lists)
   - Client expects `playerHand: [cards]` (single list)
   - Check line 297 in game.js: `data.playerHand[0]`

## Next Steps After Testing

If basic flow works:
1. Implement JSON parsing (session ID)
2. Implement randomization (+tog)
3. Add validation (bet amounts, session checks)
4. Test edge cases (blackjack, bust, split, etc.)
