// Wallet state
let serverPkh = null;
let availableBalance = 1000; // Mock starting balance
let bettingPool = 0;
let transactionHistory = [];

// Initialize wallet
async function init() {
    // Try to fetch server PKH from a session
    await loadServerPkh();

    // Load from localStorage if available
    const saved = localStorage.getItem('blackjack-wallet');
    if (saved) {
        const data = JSON.parse(saved);
        availableBalance = data.availableBalance || 1000;
        bettingPool = data.bettingPool || 0;
        transactionHistory = data.transactionHistory || [];

        // Restore PKH and private key if saved
        if (data.playerPkh) {
            document.getElementById('player-pkh-input').value = data.playerPkh;
        }
        if (data.playerPrivateKey) {
            document.getElementById('player-private-key').value = data.playerPrivateKey;
        }
    }

    // Set up auto-save for PKH and private key fields
    document.getElementById('player-pkh-input').addEventListener('change', saveWalletData);
    document.getElementById('player-private-key').addEventListener('change', saveWalletData);

    updateDisplay();
    updateTransactionList();
}

// Load server PKH
async function loadServerPkh() {
    try {
        // Try to create a session just to get the server PKH
        const response = await fetch('/blackjack/api/session/create', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'}
        });

        if (response.ok) {
            const data = await response.json();
            serverPkh = data.serverWalletPkh;
            document.getElementById('server-pkh').textContent = serverPkh;
        }
    } catch (error) {
        console.error('Error loading server PKH:', error);
        document.getElementById('server-pkh').textContent = 'Error loading';
    }
}

// Copy server PKH to clipboard
function copyServerPkh() {
    if (!serverPkh) {
        setStatus('Server PKH not loaded');
        return;
    }

    navigator.clipboard.writeText(serverPkh).then(() => {
        setStatus('Server PKH copied to clipboard');
    }).catch(err => {
        setStatus('Failed to copy: ' + err.message);
    });
}

// Mock: Send funds to server
function mockSendFunds() {
    const playerPkh = document.getElementById('player-pkh-input').value.trim();
    const amount = parseInt(document.getElementById('send-amount').value) || 0;

    if (!playerPkh) {
        setStatus('Please enter your PKH');
        return;
    }

    if (amount <= 0) {
        setStatus('Please enter a valid amount');
        return;
    }

    // Mock transaction
    const tx = {
        type: 'deposit',
        amount: amount,
        from: playerPkh,
        to: serverPkh || 'Server',
        timestamp: new Date().toISOString(),
        status: 'pending',
        txHash: 'mock-' + Math.random().toString(36).substring(7)
    };

    transactionHistory.unshift(tx);

    // Simulate confirmation after 3 seconds
    setTimeout(() => {
        tx.status = 'confirmed';
        availableBalance += amount;
        updateDisplay();
        updateTransactionList();
        saveState();
        setStatus(`Deposit of ℕ${amount} confirmed!`);
    }, 3000);

    updateTransactionList();
    saveState();
    setStatus(`Deposit of ℕ${amount} pending confirmation (mock: 3 seconds)...`);

    // Clear inputs
    document.getElementById('send-amount').value = '';
}

// Cash out funds from game session
async function mockCashOut() {
    const destinationPkh = document.getElementById('cashout-pkh').value.trim();
    const amount = parseInt(document.getElementById('cashout-amount').value) || 0;

    if (!destinationPkh) {
        setStatus('Please enter destination PKH');
        return;
    }

    if (amount <= 0) {
        setStatus('Please enter a valid amount');
        return;
    }

    // Get current game session from localStorage
    const gameId = localStorage.getItem('blackjack-gameId');
    if (!gameId) {
        setStatus('No active game session. Please start a game first.');
        return;
    }

    setStatus(`Requesting cashout of ℕ${amount}...`);

    try {
        // Call the cashout endpoint
        const response = await fetch('/blackjack/api/wallet/cashout', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                gameId: gameId,
                playerPkh: destinationPkh,
                amount: amount
            })
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `Server error: ${response.status}`);
        }

        const data = await response.json();
        console.log('Cashout response:', data);

        if (!data.success) {
            throw new Error(data.error || 'Cashout failed');
        }

        // Create transaction record
        const tx = {
            type: 'withdrawal',
            amount: amount,
            from: serverPkh || 'Game Server',
            to: destinationPkh,
            timestamp: new Date().toISOString(),
            status: data.txReady ? 'submitting' : 'prepared',
            txHash: data.txHash || null,
            gameId: gameId,
            newBank: data.newBank
        };

        transactionHistory.unshift(tx);

        // Update available balance to match the new bank from the game
        availableBalance = data.newBank;

        updateDisplay();
        updateTransactionList();
        saveState();

        setStatus(data.message || 'Cashout initiated - awaiting blockchain confirmation...');

        // Clear inputs
        document.getElementById('cashout-pkh').value = '';
        document.getElementById('cashout-amount').value = '';

        // If transaction is ready, start polling for tx hash
        if (data.txReady) {
            pollForTxHash(gameId, tx);
        }

    } catch (error) {
        console.error('Cashout error:', error);
        setStatus('Cashout failed: ' + error.message);
    }
}

// Poll for transaction hash after cashout
async function pollForTxHash(gameId, tx) {
    const maxAttempts = 30; // Poll for up to 30 seconds
    const pollInterval = 1000; // Check every 1 second
    let attempts = 0;

    const poll = async () => {
        try {
            const response = await fetch(`/blackjack/api/${gameId}/status`);

            if (!response.ok) {
                console.error('Failed to poll status:', response.status);
                return;
            }

            const data = await response.json();

            // Check if we got a transaction hash
            if (data.cashoutTxHash && data.cashoutTxHash !== 'null') {
                // Update the transaction record
                tx.txHash = data.cashoutTxHash;
                tx.status = 'confirmed';

                updateTransactionList();
                saveState();

                setStatus(`Transaction confirmed! Hash: ${data.cashoutTxHash}`);
                return; // Stop polling
            }

            // Continue polling if we haven't exceeded max attempts
            attempts++;
            if (attempts < maxAttempts) {
                setTimeout(poll, pollInterval);
            } else {
                setStatus('Transaction submitted - check status endpoint for hash');
                tx.status = 'pending';
                updateTransactionList();
                saveState();
            }

        } catch (error) {
            console.error('Error polling for tx hash:', error);
            // Continue polling despite errors
            attempts++;
            if (attempts < maxAttempts) {
                setTimeout(poll, pollInterval);
            }
        }
    };

    // Start polling
    poll();
}

// Update display
function updateDisplay() {
    document.getElementById('available-balance').textContent = `ℕ${availableBalance}`;
    document.getElementById('betting-pool').textContent = `ℕ${bettingPool}`;
}

// Update transaction list
function updateTransactionList() {
    const container = document.getElementById('transaction-list');

    if (transactionHistory.length === 0) {
        container.innerHTML = '<div class="no-transactions">No transactions yet</div>';
        return;
    }

    container.innerHTML = '';

    transactionHistory.forEach(tx => {
        const txDiv = document.createElement('div');
        txDiv.className = 'transaction-entry';

        // Determine status class based on transaction state
        let statusClass;
        if (tx.status === 'confirmed') {
            statusClass = 'tx-confirmed';
        } else if (tx.status === 'submitting' || tx.status === 'pending' || tx.status === 'ready') {
            statusClass = 'tx-pending';
        } else {
            statusClass = 'tx-prepared';
        }

        const typeClass = tx.type === 'deposit' ? 'tx-deposit' : 'tx-withdrawal';

        const date = new Date(tx.timestamp);
        const timeStr = date.toLocaleTimeString();

        // Display hash or status message
        const hashDisplay = tx.txHash
            ? `<span class="tx-hash">${tx.txHash}</span>`
            : '<span class="tx-hash-pending">Awaiting confirmation...</span>';

        txDiv.innerHTML = `
            <div class="tx-header">
                <span class="tx-type ${typeClass}">${tx.type.toUpperCase()}</span>
                <span class="tx-amount">ℕ${tx.amount}</span>
                <span class="tx-status ${statusClass}">${tx.status}</span>
            </div>
            <div class="tx-details">
                <div>Hash: ${hashDisplay}</div>
                <div>Time: ${timeStr}</div>
            </div>
        `;

        container.appendChild(txDiv);
    });
}

// Save state to localStorage
function saveState() {
    const data = {
        availableBalance,
        bettingPool,
        transactionHistory,
        playerPkh: document.getElementById('player-pkh-input').value,
        playerPrivateKey: document.getElementById('player-private-key').value
    };
    localStorage.setItem('blackjack-wallet', JSON.stringify(data));
}

// Alias for backwards compatibility
function saveWalletData() {
    saveState();
}

// Set status message
function setStatus(message) {
    document.getElementById('status-message').textContent = message;
}

// Start on page load
window.addEventListener('load', init);
