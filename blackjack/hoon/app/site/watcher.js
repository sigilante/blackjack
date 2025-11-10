// Watcher state
let currentSessionId = null;
let refreshInterval = null;

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

    // Set up session selector listener
    document.getElementById('session-selector').addEventListener('change', async (e) => {
        const gameId = e.target.value;
        if (gameId) {
            await loadSession(gameId);
            // Auto-refresh every 2 seconds when watching a session
            if (refreshInterval) clearInterval(refreshInterval);
            refreshInterval = setInterval(() => loadSession(gameId), 2000);
        } else {
            if (refreshInterval) clearInterval(refreshInterval);
            clearDisplay();
        }
    });
}

// Refresh the sessions list
async function refreshSessions() {
    try {
        const response = await fetch('/blackjack/api/sessions');
        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        const selector = document.getElementById('session-selector');

        // Save current selection
        const currentSelection = selector.value;

        // Clear and rebuild options
        selector.innerHTML = '<option value="">-- Select a session --</option>';

        data.sessions.forEach(session => {
            const option = document.createElement('option');
            option.value = session.gameId;
            option.textContent = `${session.gameId.substring(0, 8)}... (${session.status}, $${session.bank}, ${session.handsPlayed} hands)`;
            selector.appendChild(option);
        });

        // Restore selection if it still exists
        if (currentSelection && data.sessions.some(s => s.gameId === currentSelection)) {
            selector.value = currentSelection;
        }

        setStatus(`Found ${data.sessions.length} session(s)`);
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

        // Update info displays
        document.getElementById('game-id-display').textContent = gameId.substring(0, 12) + '...';
        document.getElementById('status-display').textContent = session.status;
        document.getElementById('bank-amount').textContent = `$${session.bank}`;
        document.getElementById('current-bet').textContent = `$${session.currentBet}`;

        // Update hands
        updateHand('player', session.playerHand || [], !session.dealerTurn);
        updateHand('dealer', session.dealerHand || [], session.dealerTurn);

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
    container.innerHTML = '';

    if (history.length === 0) {
        container.innerHTML = '<div class="history-empty">No hands played yet</div>';
        return;
    }

    history.forEach((entry, index) => {
        const historyEntry = document.createElement('div');
        historyEntry.className = 'history-entry';

        // Entry header with outcome
        const header = document.createElement('div');
        header.className = 'history-entry-header';
        header.innerHTML = `
            <span class="history-hand-number">#${history.length - index}</span>
            <span class="history-outcome history-outcome-${entry.outcome}">${entry.outcome.toUpperCase()}</span>
            <span class="history-bet">Bet: $${entry.bet}</span>
            <span class="history-payout">Payout: $${entry.payout}</span>
        `;
        historyEntry.appendChild(header);

        // Hands display
        const handsDiv = document.createElement('div');
        handsDiv.className = 'history-hands';

        // Player hand
        const playerHandDiv = document.createElement('div');
        playerHandDiv.className = 'history-hand';
        playerHandDiv.innerHTML = '<span class="history-hand-label">P:</span>';
        entry.playerHand.forEach(card => {
            playerHandDiv.appendChild(renderTinyCard(card));
        });
        playerHandDiv.innerHTML += `<span class="history-score">${calculateHandValue(entry.playerHand)}</span>`;
        handsDiv.appendChild(playerHandDiv);

        // Dealer hand
        const dealerHandDiv = document.createElement('div');
        dealerHandDiv.className = 'history-hand';
        dealerHandDiv.innerHTML = '<span class="history-hand-label">D:</span>';
        entry.dealerHand.forEach(card => {
            dealerHandDiv.appendChild(renderTinyCard(card));
        });
        dealerHandDiv.innerHTML += `<span class="history-score">${calculateHandValue(entry.dealerHand)}</span>`;
        handsDiv.appendChild(dealerHandDiv);

        historyEntry.appendChild(handsDiv);
        container.appendChild(historyEntry);
    });
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
