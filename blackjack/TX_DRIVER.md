# Transaction Driver Implementation

## Current Status: **STUB MODE**

The current implementation is a **stub driver** for testing the full Hoon ↔ Rust ↔ Browser flow without requiring blockchain integration.

## What the Stub Does

1. **Receives** transaction effects from Hoon kernel
2. **Parses** the effect to extract game-id, amount, PKHs
3. **Generates** a fake transaction hash: `stub-tx-{game-id-prefix}-{timestamp}`
4. **Waits** 1 second (simulating blockchain submission delay)
5. **Pokes back** with `[%tx-sent game-id tx-hash]`

## Effect Format

### From Hoon → Rust

```hoon
[%tx %send
  game-id         @t    :: Session identifier
  src-pkh         @t    :: Server's PKH (base58)
  src-privkey     @t    :: Server's private key (base58)
  src-first-name  hash  :: Calculated first-name (256-bit)
  trg-pkh         @t    :: Player's PKH (base58)
  amount          @t    :: Amount in nicks (as cord)
]
```

### From Rust → Hoon (Success)

```hoon
[%tx-sent
  game-id  @t  :: Session identifier
  tx-hash  @t  :: Transaction hash
]
```

### From Rust → Hoon (Failure)

```hoon
[%tx-fail
  game-id  @t  :: Session identifier
  error    @t  :: Error message
]
```

## Testing the Flow

1. Start the server:
   ```bash
   cd blackjack
   cargo run
   ```

2. Navigate to wallet page in browser
3. Create a game session
4. Enter cashout details and click "Cash Out"
5. Watch the logs:
   ```
   tx_driver received effect
   Parsed tx effect:
     game-id: ...
     src-pkh: 9yPeP...
     trg-pkh: ...
     amount: 1000
   Generated stub tx hash: stub-tx-12345678-1234567890
   Successfully poked tx-sent response for game ...
   ```

6. Browser should automatically receive the hash after ~1 second

## Replacing the Stub

To implement the real transaction driver, replace `src/tx_driver.rs` with code that:

### 1. Query Blockchain for UTXOs

```rust
async fn get_server_notes(grpc_client: &GrpcClient, src_pkh: &str) -> Result<Vec<Note>> {
    // Query blockchain via gRPC
    // Return server's available notes (UTXOs)
}
```

### 2. Select Notes to Spend

```rust
fn select_notes(notes: Vec<Note>, amount: u64, fee: u64) -> Result<Vec<Note>> {
    // Simple greedy selection:
    // - Sort notes by value
    // - Select smallest set that covers amount + fee
    // - Return selected notes
}
```

### 3. Build Transaction

```rust
async fn build_transaction(
    selected_notes: Vec<Note>,
    src_privkey: &str,
    trg_pkh: &str,
    amount: u64,
) -> Result<RawTx> {
    // 1. Create spends from selected notes
    // 2. Sign each spend with src_privkey (schnorr signature)
    // 3. Create output seeds:
    //    - Player seed: [trg_pkh, amount]
    //    - Change seed: [src_pkh, remaining_value]
    // 4. Serialize to raw-tx format
    // 5. Return raw transaction
}
```

### 4. Submit to Blockchain

```rust
async fn submit_transaction(grpc_client: &GrpcClient, raw_tx: RawTx) -> Result<String> {
    // 1. Submit via gRPC
    // 2. Get transaction hash
    // 3. Return hash
}
```

### 5. Full Implementation Skeleton

```rust
async fn handle_tx_effect(effect_noun: Noun, nockapp: Arc<Mutex<NockApp>>) -> Result<()> {
    // Parse effect (same as stub)
    let tx_effect = parse_tx_effect(effect_noun)?;

    // Get gRPC client from config
    let grpc_client = get_grpc_client().await?;

    match process_transaction(&grpc_client, tx_effect).await {
        Ok(tx_hash) => {
            poke_tx_result(nockapp, &game_id, Ok(&tx_hash)).await?;
        }
        Err(e) => {
            error!("Transaction failed: {}", e);
            poke_tx_result(nockapp, &game_id, Err(&e.to_string())).await?;
        }
    }

    Ok(())
}

async fn process_transaction(
    client: &GrpcClient,
    tx_effect: TxEffect,
) -> Result<String> {
    // 1. Query notes
    let notes = get_server_notes(client, &tx_effect.src_pkh).await?;

    // 2. Select notes
    let selected = select_notes(notes, tx_effect.amount, FEE)?;

    // 3. Build transaction
    let raw_tx = build_transaction(
        selected,
        &tx_effect.src_privkey,
        &tx_effect.trg_pkh,
        tx_effect.amount,
    ).await?;

    // 4. Submit to blockchain
    let tx_hash = submit_transaction(client, raw_tx).await?;

    Ok(tx_hash)
}
```

## Dependencies for Real Implementation

Add to `Cargo.toml`:

```toml
[dependencies]
# Existing...
chrono = "0.4"

# For real tx_driver:
tonic = "0.11"           # gRPC client
prost = "0.12"           # Protobuf
bs58 = "0.5"             # Base58 encoding/decoding
sha2 = "0.10"            # Hashing (if needed)
# Use existing nockchain-types for transaction types
```

## Noun Slot Reference

For parsing the effect tuple `[%tx %send ...]`:

- Slot 2: `%tx` tag
- Slot 3: `[%send ...]`
- Slot 3/2: `%send` tag
- Slot 3/3: Parameters tuple
  - Slot 3/3/2: game-id
  - Slot 3/3/6: src-pkh
  - Slot 3/3/7: src-privkey
  - Slot 3/3/12: src-first-name (hash, 256 bits)
  - Slot 3/3/14: trg-pkh
  - Slot 3/3/15: amount

Use `slot(noun, axis, &mut ctx)` to extract values.

## Error Handling

Always poke back with either success or failure:

```rust
// Success
poke_tx_result(nockapp, &game_id, Ok(&tx_hash)).await

// Failure
poke_tx_result(nockapp, &game_id, Err("Insufficient funds")).await
```

The Hoon kernel handles errors gracefully and logs them.

## Testing Strategy

1. **Stub mode** (current): Test full flow with fake hashes
2. **Local blockchain**: Test with local nockchain node
3. **Testnet**: Test with fakenet test network
4. **Mainnet**: Deploy with real funds

Keep the stub driver available for testing by using a config flag:

```toml
[blockchain]
enable_blockchain = false  # Use stub
# enable_blockchain = true  # Use real tx_driver
```
