use anyhow::{Context, Result};
use nockapp::io_drivers::{IoDriver, IoDriverTask};
use nockapp::noun::slab::NounSlab;
use nockapp::utils::make_tas;
use nockapp::wire::{SystemWire, Wire};
use nockapp::NockApp;
use nockvm::noun::{Noun, D, T};
use nockvm::interpreter::Context as NockContext;
use nockvm::jets::util::slot;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{info, warn, error};

/// Stub transaction driver for testing
///
/// This driver receives transaction effects from the Hoon kernel and
/// immediately returns fake transaction hashes for testing the full flow.
///
/// Effect format from Hoon:
/// [%tx %send game-id src-pkh src-privkey src-first-name trg-pkh amount]
pub fn tx_driver() -> IoDriver {
    IoDriver::new(
        "tx_driver",
        Box::new(|_task: IoDriverTask| {
            Box::pin(async move {
                info!("tx_driver initialized (stub mode)");
                Ok(())
            })
        }),
        Box::new(move |effect_noun, nockapp_handle| {
            Box::pin(async move {
                if let Err(e) = handle_tx_effect(effect_noun, nockapp_handle).await {
                    error!("tx_driver error: {}", e);
                }
            })
        }),
    )
}

/// Handle a transaction effect from the kernel
async fn handle_tx_effect(effect_noun: Noun, nockapp: Arc<Mutex<NockApp>>) -> Result<()> {
    info!("tx_driver received effect");

    // Parse the effect: [%tx tx-effect]
    // tx-effect: [%send game-id src-pkh src-privkey src-first-name trg-pkh amount]

    let mut ctx = NockContext::new();

    // Extract head: should be %tx
    let head = slot(effect_noun, 2, &mut ctx)
        .context("Failed to get effect head")?;

    let head_str = atom_to_string(head)?;
    if head_str != "tx" {
        warn!("Ignoring non-tx effect: {}", head_str);
        return Ok(());
    }

    // Extract tail: [%send ...]
    let tail = slot(effect_noun, 3, &mut ctx)
        .context("Failed to get effect tail")?;

    // Extract %send tag
    let send_tag = slot(tail, 2, &mut ctx)
        .context("Failed to get send tag")?;

    let send_tag_str = atom_to_string(send_tag)?;
    if send_tag_str != "send" {
        warn!("Ignoring non-send tx effect: {}", send_tag_str);
        return Ok(());
    }

    // Extract parameters: [game-id src-pkh src-privkey src-first-name trg-pkh amount]
    let params = slot(tail, 3, &mut ctx)
        .context("Failed to get parameters")?;

    // game-id is at position 2 in params tuple
    let game_id_noun = slot(params, 2, &mut ctx)
        .context("Failed to extract game-id")?;
    let game_id = atom_to_string(game_id_noun)?;

    // src-pkh at position 6
    let src_pkh_noun = slot(params, 6, &mut ctx)
        .context("Failed to extract src-pkh")?;
    let src_pkh = atom_to_string(src_pkh_noun)?;

    // trg-pkh at position 14
    let trg_pkh_noun = slot(params, 14, &mut ctx)
        .context("Failed to extract trg-pkh")?;
    let trg_pkh = atom_to_string(trg_pkh_noun)?;

    // amount at position 15
    let amount_noun = slot(params, 15, &mut ctx)
        .context("Failed to extract amount")?;
    let amount_str = atom_to_string(amount_noun)?;
    let amount: u64 = amount_str.parse()
        .context("Failed to parse amount as number")?;

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
    poke_tx_result(nockapp, &game_id, Ok(&tx_hash)).await?;

    info!("Successfully poked tx-sent response for game {}", game_id);

    Ok(())
}

/// Poke the kernel with transaction result
async fn poke_tx_result(
    nockapp: Arc<Mutex<NockApp>>,
    game_id: &str,
    result: Result<&str, &str>,
) -> Result<()> {
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

    // Poke the kernel with system wire
    let wire = SystemWire.to_wire();
    let mut app = nockapp.lock().await;
    app.poke(wire, slab).await
        .context("Failed to poke tx result back to kernel")?;

    Ok(())
}

/// Convert a noun atom to a string
fn atom_to_string(noun: Noun) -> Result<String> {
    if let Ok(atom) = noun.as_atom() {
        let bytes = atom.as_bytes();
        String::from_utf8(bytes.to_vec())
            .context("Failed to convert atom to UTF-8 string")
    } else {
        anyhow::bail!("Expected atom, got cell")
    }
}
