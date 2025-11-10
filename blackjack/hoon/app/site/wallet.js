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
    }

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
        setStatus(`Deposit of $${amount} confirmed!`);
    }, 3000);

    updateTransactionList();
    saveState();
    setStatus(`Deposit of $${amount} pending confirmation (mock: 3 seconds)...`);

    // Clear inputs
    document.getElementById('send-amount').value = '';
}

// Mock: Cash out funds
function mockCashOut() {
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

    if (amount > availableBalance) {
        setStatus('Insufficient balance');
        return;
    }

    // Mock transaction
    const tx = {
        type: 'withdrawal',
        amount: amount,
        from: serverPkh || 'Server',
        to: destinationPkh,
        timestamp: new Date().toISOString(),
        status: 'pending',
        txHash: 'mock-' + Math.random().toString(36).substring(7)
    };

    transactionHistory.unshift(tx);
    availableBalance -= amount;

    // Simulate confirmation after 2 seconds
    setTimeout(() => {
        tx.status = 'confirmed';
        updateTransactionList();
        saveState();
        setStatus(`Withdrawal of $${amount} confirmed!`);
    }, 2000);

    updateDisplay();
    updateTransactionList();
    saveState();
    setStatus(`Withdrawal of $${amount} pending confirmation (mock: 2 seconds)...`);

    // Clear inputs
    document.getElementById('cashout-pkh').value = '';
    document.getElementById('cashout-amount').value = '';
}

// Update display
function updateDisplay() {
    document.getElementById('available-balance').textContent = `$${availableBalance}`;
    document.getElementById('betting-pool').textContent = `$${bettingPool}`;
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

        const statusClass = tx.status === 'confirmed' ? 'tx-confirmed' : 'tx-pending';
        const typeClass = tx.type === 'deposit' ? 'tx-deposit' : 'tx-withdrawal';

        const date = new Date(tx.timestamp);
        const timeStr = date.toLocaleTimeString();

        txDiv.innerHTML = `
            <div class="tx-header">
                <span class="tx-type ${typeClass}">${tx.type.toUpperCase()}</span>
                <span class="tx-amount">$${tx.amount}</span>
                <span class="tx-status ${statusClass}">${tx.status}</span>
            </div>
            <div class="tx-details">
                <div>Hash: <span class="tx-hash">${tx.txHash}</span></div>
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
        transactionHistory
    };
    localStorage.setItem('blackjack-wallet', JSON.stringify(data));
}

// Set status message
function setStatus(message) {
    document.getElementById('status-message').textContent = message;
}

// Start on page load
window.addEventListener('load', init);
