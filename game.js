// Server session tracking
let gameId = null;
let serverWalletPkh = null;

// Game State
const gameState = {
    deck: [],
    playerHand: [],
    dealerHand: [],
    bank: 1000,
    currentBet: 0,
    winLoss: 0,
    gameInProgress: false,
    dealerTurn: false
};

// Card suits and ranks
const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const rankValues = {
    'A': 11,
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    'J': 10,
    'Q': 10,
    'K': 10
};

// Initialize the game
async function initGame() {
    // Try to restore previous session from localStorage
    const savedGameId = localStorage.getItem('blackjack-gameId');
    const savedServerPkh = localStorage.getItem('blackjack-serverPkh');

    if (savedServerPkh) {
        serverWalletPkh = savedServerPkh;
    }

    if (savedGameId) {
        try {
            console.log('Attempting to restore session:', savedGameId);
            // Try to restore the session
            const response = await fetch(`/blackjack/api/${savedGameId}/status`);
            console.log('Restore response status:', response.status);
            if (response.ok) {
                const session = await response.json();
                console.log('Session data:', session);
                // Restore session
                gameId = savedGameId;
                gameState.bank = session.bank;
                gameState.currentBet = session.currentBet;
                gameState.gameInProgress = session.gameInProgress;
                gameState.playerHand = session.playerHand || [];
                gameState.dealerHand = session.dealerHand || [];
                gameState.dealerTurn = session.dealerTurn;
                gameState.winLoss = session.winLoss || 0;

                console.log('Restored gameState:', {
                    bank: gameState.bank,
                    currentBet: gameState.currentBet,
                    gameInProgress: gameState.gameInProgress,
                    dealerTurn: gameState.dealerTurn,
                    playerHandLength: gameState.playerHand.length,
                    dealerHandLength: gameState.dealerHand.length,
                    winLoss: gameState.winLoss
                });

                // Update button states based on game state
                console.log('Setting button states...');
                if (gameState.gameInProgress) {
                    console.log('Game in progress - enabling Hit/Stand, disabling Deal');
                    document.getElementById('hit-btn').disabled = false;
                    document.getElementById('stand-btn').disabled = false;
                    document.getElementById('deal-btn').disabled = true;
                } else if (gameState.currentBet > 0) {
                    console.log('Bet placed but no game - enabling Deal');
                    document.getElementById('deal-btn').disabled = false;
                } else {
                    console.log('No bet, no game - all buttons should be disabled or in default state');
                }

                updateDisplay();
                updateSessionInfo();
                setStatus(`Resumed session ${gameId.substring(0, 8)}... (Bank: ℕ${gameState.bank})`);
                return;
            } else {
                // Session no longer exists, clear it
                localStorage.removeItem('blackjack-gameId');
            }
        } catch (error) {
            console.error('Error restoring session:', error);
            localStorage.removeItem('blackjack-gameId');
        }
    }

    // No saved session or restore failed
    updateDisplay();
    setStatus('Welcome! Click "New Game" or place a bet to start playing.');
}

// Create and shuffle a deck
function createDeck() {
    const deck = [];
    for (const suit of suits) {
        for (const rank of ranks) {
            deck.push({ suit, rank });
        }
    }
    return shuffleDeck(deck);
}

// Fisher-Yates shuffle
function shuffleDeck(deck) {
    const shuffled = [...deck];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

// Calculate hand value
function calculateHandValue(hand) {
    let value = 0;
    let aces = 0;

    for (const card of hand) {
        value += rankValues[card.rank];
        if (card.rank === 'A') {
            aces++;
        }
    }

    // Adjust for aces if value is over 21
    while (value > 21 && aces > 0) {
        value -= 10;
        aces--;
    }

    return value;
}

// Render a card element
function renderCard(card, hidden = false) {
    const cardDiv = document.createElement('div');
    cardDiv.className = 'card';

    if (hidden) {
        cardDiv.classList.add('back');
    } else {
        cardDiv.classList.add(`${card.suit}-${card.rank}`);
    }

    return cardDiv;
}

// Drag state for card dragging effect
const dragState = {
    isDragging: false,
    card: null,
    placeholder: null,  // Placeholder to maintain spacing
    startX: 0,
    startY: 0,
    offsetX: 0,
    offsetY: 0,
    originalParent: null,
    originalPosition: null
};

// Initialize card dragging for player cards
function makeCardDraggable(cardElement, isPlayerCard) {
    if (!isPlayerCard) return; // Only player cards are draggable

    cardElement.style.cursor = 'grab';

    cardElement.addEventListener('mousedown', function(e) {
        e.preventDefault();

        // Store original position, parent, and sibling for exact reinsertion
        const rect = cardElement.getBoundingClientRect();
        const parent = cardElement.parentElement;
        const nextSibling = cardElement.nextSibling;

        dragState.originalPosition = {
            left: rect.left,
            top: rect.top,
            parent: parent,
            nextSibling: nextSibling
        };

        // Create invisible placeholder to maintain spacing
        const placeholder = document.createElement('div');
        placeholder.className = 'card card-placeholder';
        placeholder.style.width = rect.width + 'px';
        placeholder.style.height = rect.height + 'px';
        placeholder.style.visibility = 'hidden';  // Invisible but takes up space
        dragState.placeholder = placeholder;

        // Insert placeholder at card's position before removing card
        parent.insertBefore(placeholder, cardElement);

        // Calculate offset from mouse to card top-left
        dragState.offsetX = e.clientX - rect.left;
        dragState.offsetY = e.clientY - rect.top;

        // Move card to body with absolute positioning for dragging
        dragState.isDragging = true;
        dragState.card = cardElement;
        cardElement.style.position = 'fixed';
        cardElement.style.left = rect.left + 'px';
        cardElement.style.top = rect.top + 'px';
        cardElement.style.zIndex = '1000';
        cardElement.style.cursor = 'grabbing';
        cardElement.style.transition = 'none'; // Disable transitions during drag

        document.body.appendChild(cardElement);
    });
}

// Global mouse move handler
document.addEventListener('mousemove', function(e) {
    if (!dragState.isDragging || !dragState.card) return;

    e.preventDefault();

    // Update card position to follow mouse
    dragState.card.style.left = (e.clientX - dragState.offsetX) + 'px';
    dragState.card.style.top = (e.clientY - dragState.offsetY) + 'px';
});

// Global mouse up handler
document.addEventListener('mouseup', function(e) {
    if (!dragState.isDragging || !dragState.card) return;

    e.preventDefault();

    const card = dragState.card;
    const origPos = dragState.originalPosition;

    // Enable smooth transition for return animation
    card.style.transition = 'all 0.3s ease-out';
    card.style.left = origPos.left + 'px';
    card.style.top = origPos.top + 'px';
    card.style.cursor = 'grab';

    // After animation completes, return card to original position in parent
    setTimeout(() => {
        card.style.position = '';
        card.style.left = '';
        card.style.top = '';
        card.style.zIndex = '';
        card.style.transition = '';

        // Remove placeholder and insert card back at its position
        if (dragState.placeholder && dragState.placeholder.parentElement) {
            dragState.placeholder.parentElement.removeChild(dragState.placeholder);
        }

        // Insert card back at exact same position
        // The placeholder was at the original position, so use the stored nextSibling
        origPos.parent.insertBefore(card, origPos.nextSibling);

        // Reset drag state
        dragState.isDragging = false;
        dragState.card = null;
        dragState.placeholder = null;
        dragState.originalPosition = null;
    }, 300); // Match transition duration
});

// Update the display
function updateDisplay() {
    // Update bank and bet displays
    document.getElementById('bank-amount').textContent = `ℕ${gameState.bank}`;
    document.getElementById('current-bet').textContent = `ℕ${gameState.currentBet}`;
    document.getElementById('win-loss').textContent = `ℕ${gameState.winLoss >= 0 ? '+' : ''}${gameState.winLoss}`;

    // Update bet display
    updateBetDisplay();

    // Update hands
    updateHand('player');
    updateHand('dealer');
}

// Update the visual bet display with chips
function updateBetDisplay() {
    const betDisplay = document.getElementById('bet-display');
    betDisplay.innerHTML = '';

    if (gameState.currentBet === 0) {
        return;
    }

    // Break down bet into chips (largest first)
    let remaining = gameState.currentBet;
    const chipDenominations = [100, 50, 25, 10, 5, 1];
    const chipPositions = {
        100: '-801px -525px',
        50: '-756px -525px',
        25: '-711px -525px',
        10: '-801px -480px',
        5: '-756px -480px',
        1: '-711px -480px'
    };

    const chips = [];
    for (const denom of chipDenominations) {
        while (remaining >= denom) {
            chips.push(denom);
            remaining -= denom;
        }
    }

    // Display chips stacked with slight offset
    chips.forEach((denom, index) => {
        const chipDiv = document.createElement('div');
        chipDiv.className = 'bet-display-chip';
        chipDiv.style.backgroundPosition = chipPositions[denom];
        chipDiv.style.top = `${25 - index * 4}px`; // Stack chips with double spacing
        chipDiv.style.zIndex = index;
        betDisplay.appendChild(chipDiv);
    });
}

// Update a specific hand display
function updateHand(player) {
    const hand = player === 'player' ? gameState.playerHand : gameState.dealerHand;
    const handElement = document.getElementById(`${player}-hand`);
    const scoreElement = document.getElementById(`${player}-score`);

    handElement.innerHTML = '';

    hand.forEach((card, index) => {
        // Hide dealer's first card until dealer's turn
        const hidden = player === 'dealer' && index === 0 && !gameState.dealerTurn;
        const cardElement = renderCard(card, hidden);
        handElement.appendChild(cardElement);

        // Make player cards draggable for visual effect
        makeCardDraggable(cardElement, player === 'player');
    });

    // Calculate and display score
    if (hand.length > 0) {
        if (player === 'dealer' && !gameState.dealerTurn) {
            scoreElement.textContent = '?';
        } else {
            const value = calculateHandValue(hand);
            scoreElement.textContent = `Score: ${value}`;
        }
    } else {
        scoreElement.textContent = '';
    }
}

// Place a bet
function placeBet(amount) {
    if (gameState.gameInProgress) {
        setStatus('Cannot change bet during a game.');
        return;
    }

    // If this is the first bet after a hand ended, clear the hands
    // (The deal button being disabled indicates we're between hands with hands visible)
    if (document.getElementById('deal-btn').disabled && (gameState.playerHand.length > 0 || gameState.dealerHand.length > 0)) {
        gameState.playerHand = [];
        gameState.dealerHand = [];
        updateDisplay();
    }

    if (gameState.currentBet + amount > gameState.bank) {
        setStatus('Insufficient funds!');
        return;
    }

    gameState.currentBet += amount;
    updateDisplay();

    // Enable deal button if bet is placed
    if (gameState.currentBet > 0) {
        document.getElementById('deal-btn').disabled = false;
    }

    setStatus(`Bet placed: ℕ${gameState.currentBet}`);
}

// Clear the current bet
function clearBet() {
    if (gameState.gameInProgress) {
        setStatus('Cannot change bet during a game.');
        return;
    }

    gameState.currentBet = 0;
    updateDisplay();
    document.getElementById('deal-btn').disabled = true;
    setStatus('Bet cleared.');
}

// Start a new game (reset state)
async function startNewGame() {
    try {
        // Call server API to create new session
        const response = await fetch('/blackjack/api/session/create', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({})
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();

        // Update session and game state from server
        gameId = data.gameId;
        serverWalletPkh = data.serverWalletPkh;

        // Save to localStorage for persistence
        localStorage.setItem('blackjack-gameId', gameId);
        localStorage.setItem('blackjack-serverPkh', serverWalletPkh);

        gameState.bank = data.bank;  // Initial bank from server
        gameState.currentBet = 0;
        gameState.winLoss = data.winLoss;
        gameState.gameInProgress = false;
        gameState.dealerTurn = false;
        gameState.playerHand = [];
        gameState.dealerHand = [];
        gameState.deck = [];

        document.getElementById('deal-btn').disabled = true;
        document.getElementById('hit-btn').disabled = true;
        document.getElementById('stand-btn').disabled = true;
        document.getElementById('double-btn').disabled = true;
        document.getElementById('split-btn').disabled = true;
        document.getElementById('surrender-btn').disabled = true;

        updateDisplay();
        updateSessionInfo();
        setStatus(`New session created (${gameId.substring(0, 8)}...). Place your bet and click Deal.`);
    } catch (error) {
        console.error('Error starting new game:', error);
        setStatus('Error connecting to server: ' + error.message);
    }
}

// Deal initial hands
async function dealHand() {
    if (gameState.currentBet === 0) {
        setStatus('Please place a bet first.');
        return;
    }

    if (gameState.currentBet > gameState.bank) {
        setStatus('Insufficient funds!');
        return;
    }

    // Create session if needed
    if (!gameId) {
        // Save the current bet before creating session (startNewGame resets state)
        const savedBet = gameState.currentBet;
        await startNewGame();
        // Restore the bet after session creation
        gameState.currentBet = savedBet;
        updateDisplay();
    }

    // Optimistically update bank immediately for instant visual feedback
    const betAmount = gameState.currentBet;
    gameState.bank -= betAmount;
    updateDisplay();

    try {
        // Call server API to deal
        const response = await fetch(`/blackjack/api/${gameId}/deal`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                bet: betAmount
            })
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Deal response:', data);

        // Update game state from server (sync to actual values)
        gameState.gameInProgress = true;
        gameState.dealerTurn = false;
        gameState.bank = data.bank;  // Sync to server's bank (should match our optimistic update)
        gameState.winLoss = data.winLoss || 0;  // Sync win/loss from server

        // Parse hands from server response
        // Server returns hands as arrays of cards directly
        gameState.playerHand = data.playerHand || [];
        gameState.dealerHand = data.dealerHand || [];

        updateDisplay();

        // Check for blackjack (score 21)
        const playerValue = calculateHandValue(gameState.playerHand);

        if (playerValue === 21) {
            // Auto-stand on blackjack
            setTimeout(() => stand(), 1000);
            return;
        }

        // Enable player actions
        document.getElementById('hit-btn').disabled = false;
        document.getElementById('stand-btn').disabled = false;
        document.getElementById('deal-btn').disabled = true;

        // Enable double down if player has enough money
        if (gameState.bank >= gameState.currentBet) {
            document.getElementById('double-btn').disabled = false;
        }

        // Enable surrender
        document.getElementById('surrender-btn').disabled = false;

        // Enable split if player has matching cards and enough money
        if (gameState.playerHand.length === 2 &&
            gameState.playerHand[0].rank === gameState.playerHand[1].rank &&
            gameState.bank >= gameState.currentBet) {
            document.getElementById('split-btn').disabled = false;
        }

        setStatus(`Your turn. Score: ${playerValue}. Hit or Stand?`);

    } catch (error) {
        console.error('Error dealing:', error);
        setStatus('Error dealing cards: ' + error.message);
    }
}

// Disable special action buttons (double, split, surrender)
function disableSpecialActions() {
    document.getElementById('double-btn').disabled = true;
    document.getElementById('split-btn').disabled = true;
    document.getElementById('surrender-btn').disabled = true;
}

// Player hits
async function hit() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    // Disable special actions after first hit
    disableSpecialActions();

    try {
        // Call server API to hit
        const response = await fetch(`/blackjack/api/${gameId}/hit`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'}
        });

        if (!response.ok) {
            // Try to get error details from response
            let errorMessage = `Server error: ${response.status}`;
            try {
                const errorData = await response.json();
                console.error('Hit endpoint error response:', errorData);
                if (errorData.error) {
                    errorMessage = errorData.error;
                }
            } catch (e) {
                console.error('Could not parse error response');
            }
            throw new Error(errorMessage);
        }

        const data = await response.json();
        console.log('Hit response:', data);

        // Update player hand and bank from server
        gameState.playerHand = data.hand;
        gameState.bank = data.bank;
        gameState.winLoss = data.winLoss || 0;  // Sync win/loss from server
        updateDisplay();

        const playerValue = calculateHandValue(gameState.playerHand);

        if (data.busted) {
            // Bust - bank already updated from server, clear bet but keep hands visible

            gameState.dealerTurn = true;
            gameState.gameInProgress = false;
            gameState.currentBet = 0;
            updateDisplay();
            setStatus('Player busts! Place your bet for the next hand.');

            // Disable action buttons
            document.getElementById('hit-btn').disabled = true;
            document.getElementById('stand-btn').disabled = true;
            document.getElementById('deal-btn').disabled = true;
            disableSpecialActions();
        } else if (playerValue === 21) {
            // Auto-stand on 21
            setTimeout(() => stand(), 500);
        } else {
            setStatus(`Score: ${playerValue}. Hit or Stand?`);
        }

    } catch (error) {
        console.error('Error hitting:', error);
        setStatus('Error hitting: ' + error.message);
    }
}

// Player stands
async function stand() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    gameState.dealerTurn = true;

    // Disable player actions
    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;
    disableSpecialActions();

    setStatus('Dealer\'s turn...');

    try {
        // Call server API to stand (dealer plays and resolves)
        const response = await fetch(`/blackjack/api/${gameId}/stand`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'}
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Stand response:', data);

        // Update dealer hand and bank from server
        gameState.dealerHand = data.dealerHand;
        gameState.bank = data.bank;
        gameState.winLoss = data.winLoss || 0;  // Sync win/loss from server

        updateDisplay();

        // Display outcome
        const outcomeMessage = data.outcome.charAt(0).toUpperCase() + data.outcome.slice(1);
        setStatus(`${outcomeMessage}! Payout: ℕ${data.payout}. Place a bet to play again.`);

        // Reset for next round - clear bet but keep hands visible
        gameState.gameInProgress = false;
        gameState.currentBet = 0;
        // DON'T clear hands - they stay visible until next bet is placed

        // Disable action buttons
        document.getElementById('deal-btn').disabled = true;
        document.getElementById('hit-btn').disabled = true;
        document.getElementById('stand-btn').disabled = true;
        disableSpecialActions();

        // Update display to clear bet chips (cards remain visible)
        updateDisplay();

    } catch (error) {
        console.error('Error standing:', error);
        setStatus('Error standing: ' + error.message);
    }
}

// Player cashes out (placeholder for future implementation)
function cashOut() {
    setStatus('Cash Out feature coming soon!');
}

// Player doubles down
async function doubleDown() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    // Check if player has enough money
    if (gameState.bank < gameState.currentBet) {
        setStatus('Insufficient funds to double down!');
        return;
    }

    // Disable all action buttons
    disableSpecialActions();
    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;

    setStatus('Doubling down...');

    try {
        // Call server API to double down
        const response = await fetch(`/blackjack/api/${gameId}/double`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'}
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Double down response:', data);

        // Update game state from server
        gameState.playerHand = data.playerHand || gameState.playerHand;
        gameState.dealerHand = data.dealerHand;
        gameState.bank = data.bank;
        gameState.winLoss = data.winLoss || 0;  // Sync win/loss from server

        updateDisplay();

        // Display outcome
        const outcomeMessage = data.outcome.charAt(0).toUpperCase() + data.outcome.slice(1);
        setStatus(`Doubled down! ${outcomeMessage}! Payout: ℕ${data.payout}. Place a bet to play again.`);

        // Reset for next round - clear bet but keep hands visible
        gameState.gameInProgress = false;
        gameState.currentBet = 0;
        // DON'T clear hands - they stay visible until next bet is placed

        // Disable action buttons
        document.getElementById('deal-btn').disabled = true;
        document.getElementById('hit-btn').disabled = true;
        document.getElementById('stand-btn').disabled = true;
        disableSpecialActions();

        // Update display to clear bet chips (cards remain visible)
        updateDisplay();

    } catch (error) {
        console.error('Error doubling down:', error);
        setStatus('Error doubling down: ' + error.message);
    }
}

// Player splits (basic implementation for same-rank cards)
function split() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    // Check if split is valid
    if (gameState.playerHand.length !== 2 ||
        gameState.playerHand[0].rank !== gameState.playerHand[1].rank) {
        setStatus('Cannot split - need two cards of same rank!');
        return;
    }

    // Check if player has enough money
    if (gameState.bank < gameState.currentBet) {
        setStatus('Insufficient funds to split!');
        return;
    }

    // For now, just show a message that split is not fully implemented
    // Full implementation would require tracking multiple hands
    setStatus('Split feature coming soon! (Requires multi-hand support)');
    disableSpecialActions();
}

// Player surrenders
function surrender() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    // Disable all action buttons
    disableSpecialActions();
    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;

    gameState.dealerTurn = true;

    // Return half the bet
    const halfBet = Math.floor(gameState.currentBet / 2);
    gameState.bank += halfBet;
    gameState.winLoss -= halfBet;

    updateDisplay();
    endRound(`Surrendered. Lost ℕ${halfBet}.`);
}

// Dealer plays according to rules
function playDealerHand() {
    const dealerValue = calculateHandValue(gameState.dealerHand);

    if (dealerValue < 17) {
        // Dealer must hit
        gameState.dealerHand.push(gameState.deck.pop());
        updateDisplay();
        setTimeout(playDealerHand, 1000);
    } else if (dealerValue > 21) {
        // Dealer busts
        resolveWin('Dealer busts! You win!');
    } else {
        // Compare hands
        const playerValue = calculateHandValue(gameState.playerHand);

        if (playerValue > dealerValue) {
            resolveWin('You win!');
        } else if (playerValue < dealerValue) {
            resolveLoss('Dealer wins.');
        } else {
            resolvePush();
        }
    }
}

// Resolve player win
function resolveWin(message) {
    const winAmount = gameState.currentBet * 2;
    gameState.bank += winAmount;
    gameState.winLoss += gameState.currentBet;
    endRound(message);
}

// Resolve blackjack (pays 3:2)
function resolveBlackjack() {
    const winAmount = Math.floor(gameState.currentBet * 2.5);
    gameState.bank += winAmount;
    gameState.winLoss += Math.floor(gameState.currentBet * 1.5);
    endRound('Blackjack! You win!');
}

// Resolve push (tie)
function resolvePush() {
    gameState.bank += gameState.currentBet;
    endRound('Push (tie).');
}

// Resolve player loss
function resolveLoss(message) {
    gameState.winLoss -= gameState.currentBet;
    endRound(message);
}

// End the current round
function endRound(message) {
    gameState.gameInProgress = false;
    gameState.currentBet = 0;  // Clear bet visually
    // DON'T clear hands - they stay visible until next bet is placed

    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;
    document.getElementById('double-btn').disabled = true;
    document.getElementById('split-btn').disabled = true;
    document.getElementById('surrender-btn').disabled = true;
    document.getElementById('deal-btn').disabled = true;

    updateDisplay();
    setStatus(message + ' Place your bet for the next hand.');

    // Check if player has enough money to continue
    if (gameState.bank < 1) {
        setStatus(message + ' Game over! You\'re out of money. Click New Game to restart.');
    }
}

// Set status message
function setStatus(message) {
    document.getElementById('status-message').textContent = message;
}

// Update session info display
function updateSessionInfo() {
    const sessionInfoEl = document.getElementById('session-info');
    if (gameId) {
        sessionInfoEl.textContent = `Session: ${gameId.substring(0, 12)}...`;
    } else {
        sessionInfoEl.textContent = '';
    }
}

// Initialize on page load
window.addEventListener('DOMContentLoaded', initGame);
