// Watcher state
let currentSessionId = null;
let refreshInterval = null;
let sessionsListRefreshInterval = null;  // For auto-refreshing sessions list
let lastSessionState = null; // Track last rendered state for change detection

// Card suits and ranks (same as game.js)
const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const rankValues = {
    'A': 11, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6,
    '7': 7, '8': 8, '9': 9, '10': 10, 'J': 10, 'Q': 10, 'K': 10
};

// Initialize
async function init() {
    await refreshSessions();

    // Auto-refresh sessions list every 10 seconds to catch new sessions
    sessionsListRefreshInterval = setInterval(refreshSessions, 10000);

    // Set up refresh button listener (in addition to onclick)
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Refresh button clicked via event listener');
            refreshSessions();
        });
    }

    // Set up session selector listener
    document.getElementById('session-selector').addEventListener('change', async (e) => {
        const gameId = e.target.value;
        if (gameId) {
            lastSessionState = null; // Reset state when changing sessions
            await loadSession(gameId);
            // Auto-refresh every 4 seconds when watching a session
            if (refreshInterval) clearInterval(refreshInterval);
            refreshInterval = setInterval(() => loadSession(gameId), 4000);
        } else {
            if (refreshInterval) clearInterval(refreshInterval);
            lastSessionState = null;
            clearDisplay();
        }
    });
}

// Make refreshSessions globally accessible for onclick handler
window.refreshSessions = refreshSessions;

// Refresh the sessions list
async function refreshSessions() {
    console.log('refreshSessions() called');
    try {
        console.log('Fetching /blackjack/api/sessions...');
        const response = await fetch('/blackjack/api/sessions');
        console.log('Response status:', response.status);
        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Received data:', data);
        const selector = document.getElementById('session-selector');

        // Save current selection
        const currentSelection = selector.value;

        // Clear and rebuild options
        selector.innerHTML = '<option value="">-- Select a session --</option>';

        data.sessions.forEach(session => {
            console.log('Adding session:', session);
            const option = document.createElement('option');
            option.value = session.gameId;
            option.textContent = `${session.gameId.substring(0, 8)}... (${session.status}, ℕ${session.bank}, ${session.dealsMade} deals)`;
            selector.appendChild(option);
        });

        // Restore selection if it still exists
        if (currentSelection && data.sessions.some(s => s.gameId === currentSelection)) {
            selector.value = currentSelection;
        }

        if (data.sessions.length === 0) {
            setStatus('No active sessions found. Start a game in the Game tab to create a session.');
        } else {
            setStatus(`Found ${data.sessions.length} session(s)`);
        }
    } catch (error) {
        console.error('Error fetching sessions:', error);
        setStatus('Error fetching sessions: ' + error.message);
    }
}

// Load and display a specific session
async function loadSession(gameId) {
    try {
        const response = await fetch(`/blackjack/api/${gameId}/status`);
        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const session = await response.json();
        currentSessionId = gameId;

        // Create state fingerprint for change detection
        const stateFingerprint = JSON.stringify({
            status: session.status,
            bank: session.bank,
            currentBet: session.currentBet,
            playerHand: session.playerHand,
            dealerHand: session.dealerHand,
            dealerTurn: session.dealerTurn,
            historyLength: (session.history || []).length
        });

        // Check if state has changed
        if (lastSessionState === stateFingerprint) {
            return; // No changes, skip DOM updates
        }
        lastSessionState = stateFingerprint;

        // Update info displays
        document.getElementById('game-id-display').textContent = gameId.substring(0, 12) + '...';
        document.getElementById('status-display').textContent = session.status;
        document.getElementById('bank-amount').textContent = `ℕ${session.bank}`;
        document.getElementById('current-bet').textContent = `ℕ${session.currentBet}`;

        // Update hands
        updateHand('player', session.playerHand || [], true);  // Always show all player cards
        updateHand('dealer', session.dealerHand || [], !session.gameInProgress || session.dealerTurn);  // Show all dealer cards when game ended

        // Update history
        updateHistory(session.history || []);

        setStatus(`Watching session: ${gameId.substring(0, 8)}...`);
    } catch (error) {
        console.error('Error loading session:', error);
        setStatus('Error loading session: ' + error.message);
    }
}

// Render a card element
function renderCard(card, hidden = false) {
    const cardDiv = document.createElement('div');
    cardDiv.className = 'card card-small';

    if (hidden) {
        cardDiv.classList.add('back');
    } else {
        cardDiv.classList.add(`${card.suit}-${card.rank}`);
    }

    return cardDiv;
}

// Render a tiny card for history
function renderTinyCard(card) {
    const cardDiv = document.createElement('div');
    cardDiv.className = 'card card-tiny';
    cardDiv.classList.add(`${card.suit}-${card.rank}`);
    return cardDiv;
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

    while (value > 21 && aces > 0) {
        value -= 10;
        aces--;
    }

    return value;
}

// Update a hand display
function updateHand(player, hand, showAll) {
    const handElement = document.getElementById(`${player}-hand`);
    const scoreElement = document.getElementById(`${player}-score`);

    handElement.innerHTML = '';

    if (hand.length === 0) {
        scoreElement.textContent = '';
        return;
    }

    hand.forEach((card, index) => {
        const hidden = player === 'dealer' && index === 0 && !showAll;
        const cardElement = renderCard(card, hidden);
        handElement.appendChild(cardElement);
    });

    if (showAll) {
        const value = calculateHandValue(hand);
        scoreElement.textContent = `Score: ${value}`;
    } else if (player === 'dealer') {
        scoreElement.textContent = '?';
    } else {
        const value = calculateHandValue(hand);
        scoreElement.textContent = `Score: ${value}`;
    }
}

// Update history display
function updateHistory(history) {
    const container = document.getElementById('history-container');

    if (history.length === 0) {
        container.innerHTML = '<div class="history-empty">No hands played yet</div>';
        return;
    }

    // Use DocumentFragment for efficient batch DOM operations
    const fragment = document.createDocumentFragment();

    history.forEach((entry, index) => {
        const historyEntry = document.createElement('div');
        historyEntry.className = 'history-entry';

        // Entry header with outcome
        const header = document.createElement('div');
        header.className = 'history-entry-header';

        const handNumber = document.createElement('span');
        handNumber.className = 'history-hand-number';
        handNumber.textContent = `#${history.length - index}`;

        const outcome = document.createElement('span');
        outcome.className = `history-outcome history-outcome-${entry.outcome}`;
        outcome.textContent = entry.outcome.toUpperCase();

        const bet = document.createElement('span');
        bet.className = 'history-bet';
        bet.textContent = `Bet: ℕ${entry.bet}`;

        const payout = document.createElement('span');
        payout.className = 'history-payout';
        payout.textContent = `Payout: ℕ${entry.payout}`;

        header.appendChild(handNumber);
        header.appendChild(outcome);
        header.appendChild(bet);
        header.appendChild(payout);
        historyEntry.appendChild(header);

        // Hands display
        const handsDiv = document.createElement('div');
        handsDiv.className = 'history-hands';

        // Player hand
        const playerHandDiv = document.createElement('div');
        playerHandDiv.className = 'history-hand';

        const playerLabel = document.createElement('span');
        playerLabel.className = 'history-hand-label';
        playerLabel.textContent = 'P:';
        playerHandDiv.appendChild(playerLabel);

        entry.playerHand.forEach(card => {
            playerHandDiv.appendChild(renderTinyCard(card));
        });

        const playerScore = document.createElement('span');
        playerScore.className = 'history-score';
        playerScore.textContent = calculateHandValue(entry.playerHand);
        playerHandDiv.appendChild(playerScore);

        handsDiv.appendChild(playerHandDiv);

        // Dealer hand
        const dealerHandDiv = document.createElement('div');
        dealerHandDiv.className = 'history-hand';

        const dealerLabel = document.createElement('span');
        dealerLabel.className = 'history-hand-label';
        dealerLabel.textContent = 'D:';
        dealerHandDiv.appendChild(dealerLabel);

        entry.dealerHand.forEach(card => {
            dealerHandDiv.appendChild(renderTinyCard(card));
        });

        const dealerScore = document.createElement('span');
        dealerScore.className = 'history-score';
        dealerScore.textContent = calculateHandValue(entry.dealerHand);
        dealerHandDiv.appendChild(dealerScore);

        handsDiv.appendChild(dealerHandDiv);

        historyEntry.appendChild(handsDiv);
        fragment.appendChild(historyEntry);
    });

    // Single DOM operation to replace all history
    container.innerHTML = '';
    container.appendChild(fragment);
}

// Clear the display
function clearDisplay() {
    document.getElementById('game-id-display').textContent = '-';
    document.getElementById('status-display').textContent = '-';
    document.getElementById('bank-amount').textContent = '$0';
    document.getElementById('current-bet').textContent = '$0';
    document.getElementById('player-hand').innerHTML = '';
    document.getElementById('dealer-hand').innerHTML = '';
    document.getElementById('player-score').textContent = '';
    document.getElementById('dealer-score').textContent = '';
    document.getElementById('history-container').innerHTML = '';
    setStatus('Select a session to watch');
}

// Set status message
function setStatus(message) {
    document.getElementById('status-message').textContent = message;
}

// Start on page load
window.addEventListener('load', init);
