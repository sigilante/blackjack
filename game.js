// Server session tracking
let sessionId = null;

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
function initGame() {
    updateDisplay();
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

// Update the display
function updateDisplay() {
    // Update bank and bet displays
    document.getElementById('bank-amount').textContent = `$${gameState.bank}`;
    document.getElementById('current-bet').textContent = `$${gameState.currentBet}`;
    document.getElementById('win-loss').textContent = `$${gameState.winLoss >= 0 ? '+' : ''}${gameState.winLoss}`;

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
        handElement.appendChild(renderCard(card, hidden));
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

    setStatus(`Bet placed: $${gameState.currentBet}`);
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
        const response = await fetch('/blackjack/api/new-game', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'}
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();

        // Update session and game state from server
        sessionId = data.sessionId;
        gameState.bank = data.bank;
        gameState.currentBet = 0;
        gameState.winLoss = 0;
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
        setStatus(`New game started (Session: ${sessionId}). Place your bet and click Deal.`);
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
    if (!sessionId) {
        await startNewGame();
    }

    try {
        // Call server API to deal
        const response = await fetch('/blackjack/api/deal', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId,
                bet: gameState.currentBet
            })
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Deal response:', data);

        // Update game state from server
        gameState.gameInProgress = true;
        gameState.dealerTurn = false;
        gameState.bank = data.bank;  // Use bank from server (already has bet deducted)

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
        const response = await fetch('/blackjack/api/hit', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId
            })
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Hit response:', data);

        // Update player hand from server
        gameState.playerHand = data.hand;
        updateDisplay();

        const playerValue = calculateHandValue(gameState.playerHand);

        if (data.busted) {
            // Bust
            gameState.dealerTurn = true;
            updateDisplay();
            resolveLoss('Player busts!');
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
        const response = await fetch('/blackjack/api/stand', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sessionId: sessionId
            })
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Stand response:', data);

        // Update dealer hand and bank from server
        gameState.dealerHand = data.dealerHand;
        gameState.bank = data.bank;

        updateDisplay();

        // Display outcome
        const outcomeMessage = data.outcome.charAt(0).toUpperCase() + data.outcome.slice(1);
        setStatus(`${outcomeMessage}! Payout: $${data.payout}. Place a bet to play again.`);

        // Reset for next round
        gameState.gameInProgress = false;
        gameState.currentBet = 0;
        gameState.playerHand = [];
        gameState.dealerHand = [];

        // Disable action buttons
        document.getElementById('deal-btn').disabled = true;
        document.getElementById('hit-btn').disabled = true;
        document.getElementById('stand-btn').disabled = true;
        disableSpecialActions();

        // Update display to clear cards
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
function doubleDown() {
    if (!gameState.gameInProgress || gameState.dealerTurn) {
        return;
    }

    // Check if player has enough money
    if (gameState.bank < gameState.currentBet) {
        setStatus('Insufficient funds to double down!');
        return;
    }

    // Disable all action buttons except stand
    disableSpecialActions();
    document.getElementById('hit-btn').disabled = true;

    // Double the bet
    gameState.bank -= gameState.currentBet;
    gameState.currentBet *= 2;
    updateDisplay();

    // Draw exactly one card
    gameState.playerHand.push(gameState.deck.pop());
    updateDisplay();

    const playerValue = calculateHandValue(gameState.playerHand);

    if (playerValue > 21) {
        // Bust
        gameState.dealerTurn = true;
        updateDisplay();
        resolveLoss('Player busts!');
    } else {
        // Automatically stand after double down
        setStatus(`Doubled down to $${gameState.currentBet}. Score: ${playerValue}. Standing...`);
        setTimeout(() => stand(), 1000);
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
    endRound(`Surrendered. Lost $${halfBet}.`);
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
    gameState.currentBet = 0;

    document.getElementById('hit-btn').disabled = true;
    document.getElementById('stand-btn').disabled = true;
    document.getElementById('double-btn').disabled = true;
    document.getElementById('split-btn').disabled = true;
    document.getElementById('surrender-btn').disabled = true;

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

// Initialize on page load
window.addEventListener('DOMContentLoaded', initGame);
