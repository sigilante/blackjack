use tracing::{debug, error, info};

use nockapp::nockapp::driver::{make_driver, IODriverFn};
use nockapp::NounExt;

/// Stub transaction driver for testing
///
/// This driver receives transaction effects from the Hoon kernel and
/// immediately returns fake transaction hashes for testing the full flow.
///
/// Effect format from Hoon:
/// [%tx %send game-id src-pkh src-privkey src-first-name trg-pkh amount]
pub fn tx_driver() -> IODriverFn {
    make_driver(|handle| async move {
        info!("tx_driver initialized (stub mode)");

        loop {
            tokio::select! {
                eff = handle.next_effect() => {
                    match eff {
                        Ok(eff) => {
                            if let Err(e) = handle_tx_effect(eff, &handle).await {
                                error!("tx_driver error: {}", e);
                            }
                        }
                        Err(e) => {
                            error!("Error receiving effect: {:?}", e);
                        }
                    }
                }
            }
        }
    })
}

/// Handle a transaction effect from the kernel
async fn handle_tx_effect(
    eff: nockapp::nockapp::driver::Effect,
    handle: &nockapp::nockapp::driver::Handle,
) -> anyhow::Result<()> {
    info!("tx_driver received effect");

    unsafe {
        let noun = eff.root();

        // Parse the effect: [%tx [%send ...]]
        if let Ok(cell) = noun.as_cell() {
            let head = cell.head();
            let tail = cell.tail();

            // Check if head is %tx
            if !head.eq_bytes(b"tx") {
                debug!("Ignoring non-tx effect");
                return Ok(());
            }

            // Parse tail: [%send ...]
            if let Ok(tail_cell) = tail.as_cell() {
                let send_tag = tail_cell.head();
                let params = tail_cell.tail();

                if !send_tag.eq_bytes(b"send") {
                    debug!("Ignoring non-send tx effect");
                    return Ok(());
                }

                // Parse parameters: [game-id src-pkh src-privkey src-first-name trg-pkh amount]
                let (game_id, src_pkh, trg_pkh, amount) = parse_params(params)?;

                info!("Parsed tx effect:");
                info!("  game-id: {}", game_id);
                info!("  src-pkh: {}", src_pkh);
                info!("  trg-pkh: {}", trg_pkh);
                info!("  amount: {}", amount);

                // Generate a fake transaction hash
                let tx_hash = format!("stub-tx-{}-{}",
                    &game_id[..std::cmp::min(8, game_id.len())],
                    chrono::Utc::now().timestamp()
                );

                info!("Generated stub tx hash: {}", tx_hash);

                // Simulate blockchain submission delay (1 second)
                tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;

                // Poke back with success
                poke_tx_result(handle, &game_id, Ok(&tx_hash)).await?;

                info!("Successfully poked tx-sent response for game {}", game_id);
            }
        }
    }

    Ok(())
}

/// Parse transaction parameters from the params noun
fn parse_params(
    params: nockvm::noun::Noun,
) -> anyhow::Result<(String, String, String, u64)> {
    unsafe {
        // Parameters are in a tuple: [game-id src-pkh src-privkey src-first-name trg-pkh amount]
        // We need to extract game-id, src-pkh, trg-pkh, and amount

        let mut current = params;
        let mut values = Vec::new();

        // Extract up to 6 values from the tuple
        for _ in 0..6 {
            if let Ok(cell) = current.as_cell() {
                values.push(cell.head());
                current = cell.tail();
            } else {
                break;
            }
        }

        if values.len() < 6 {
            anyhow::bail!("Not enough parameters in tx effect");
        }

        // Extract strings from atoms
        let game_id = atom_to_string(values[0])?;
        let src_pkh = atom_to_string(values[1])?;
        let trg_pkh = atom_to_string(values[4])?;
        let amount_str = atom_to_string(values[5])?;
        let amount: u64 = amount_str.parse()
            .map_err(|e| anyhow::anyhow!("Failed to parse amount: {}", e))?;

        Ok((game_id, src_pkh, trg_pkh, amount))
    }
}

/// Convert a noun atom to a string
fn atom_to_string(noun: nockvm::noun::Noun) -> anyhow::Result<String> {
    unsafe {
        if let Ok(atom) = noun.as_atom() {
            let bytes = atom.as_bytes();
            String::from_utf8(bytes.to_vec())
                .map_err(|e| anyhow::anyhow!("Failed to convert atom to UTF-8 string: {}", e))
        } else {
            anyhow::bail!("Expected atom, got cell")
        }
    }
}

/// Poke the kernel with transaction result
async fn poke_tx_result(
    handle: &nockapp::nockapp::driver::Handle,
    game_id: &str,
    result: Result<&str, &str>,
) -> anyhow::Result<()> {
    use nockapp::noun::slab::NounSlab;
    use nockapp::utils::make_tas;
    use nockvm::noun::T;

    let mut slab = NounSlab::new();

    let response = match result {
        Ok(tx_hash) => {
            // [%tx-sent game-id tx-hash]
            let head = make_tas(&mut slab, "tx-sent").as_noun();
            let game_id_noun = make_tas(&mut slab, game_id).as_noun();
            let tx_hash_noun = make_tas(&mut slab, tx_hash).as_noun();

            T(&mut slab, &[head, game_id_noun, tx_hash_noun])
        }
        Err(error) => {
            // [%tx-fail game-id error]
            let head = make_tas(&mut slab, "tx-fail").as_noun();
            let game_id_noun = make_tas(&mut slab, game_id).as_noun();
            let error_noun = make_tas(&mut slab, error).as_noun();

            T(&mut slab, &[head, game_id_noun, error_noun])
        }
    };

    slab.set_root(response);

    // Poke the kernel
    handle.poke(slab).await
        .map_err(|e| anyhow::anyhow!("Failed to poke tx result back to kernel: {}", e))?;

    Ok(())
}
