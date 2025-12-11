use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

use nockapp::noun::slab::NounSlab;
use nockapp::utils::make_tas;
use nockapp::NockApp;
use nockchain_math::noun_ext::NounMathExt;
use nockvm::noun::{Noun, D, T, YES, NO};
use nockvm_macros::tas;
use tracing::info;

/// Configuration for the Blackjack server
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct BlackjackConfig {
    pub server: ServerConfig,
    pub blockchain: BlockchainConfig,
    pub game: GameConfig,
    pub grpc: GrpcConfig,
}

/// Secrets loaded from secrets.toml
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SecretsConfig {
    pub server: ServerConfig,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ServerConfig {
    pub wallet_pkh: String,
    pub private_key: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct BlockchainConfig {
    pub confirmation_blocks: u64,
    pub enable_blockchain: bool,
    pub dry_run: bool,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct GameConfig {
    pub initial_bank: u64,
    pub max_history_entries: u64,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct GrpcConfig {
    pub endpoint: String,
    pub client_type: String,
}

impl BlackjackConfig {
    /// Load configuration from config and secrets TOML files
    pub fn load<P: AsRef<Path>>(config_path: P) -> Result<Self> {
        // Load main config
        let config_contents = fs::read_to_string(config_path.as_ref())
            .with_context(|| format!("Failed to read config file: {:?}", config_path.as_ref()))?;

        // Determine secrets path (same directory as config)
        let secrets_path = config_path.as_ref()
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .join("secrets.toml");

        // Load secrets
        let secrets_contents = fs::read_to_string(&secrets_path)
            .with_context(|| format!("Failed to read secrets file: {:?}", secrets_path))?;

        let secrets: SecretsConfig = toml::from_str(&secrets_contents)
            .context("Failed to parse secrets TOML")?;

        // Parse main config without server section
        #[derive(Deserialize)]
        struct PartialConfig {
            blockchain: BlockchainConfig,
            game: GameConfig,
            grpc: GrpcConfig,
        }

        let partial: PartialConfig = toml::from_str(&config_contents)
            .context("Failed to parse TOML config")?;

        // Merge secrets into full config
        let config = BlackjackConfig {
            server: secrets.server,
            blockchain: partial.blockchain,
            game: partial.game,
            grpc: partial.grpc,
        };

        // Validate configuration
        config.validate()?;

        Ok(config)
    }

    /// Validate the configuration
    fn validate(&self) -> Result<()> {
        // Check that keys are not placeholder values
        if self.server.private_key.contains("REPLACE_WITH") {
            anyhow::bail!("Server private_key must be set in config file");
        }

        // Validate client_type
        let client_type = self.grpc.client_type.as_str();
        if client_type != "private" && client_type != "public" {
            anyhow::bail!("grpc.client_type must be 'private' or 'public', got: {}", client_type);
        }

        Ok(())
    }

    /// Convert config to a Hoon poke noun
    /// Format: [%init-config wallet-pkh=@t private-key=@t public-key=@t confirmation-blocks=@ud enable-blockchain=? initial-bank=@ud max-history=@ud]
    pub fn to_poke_noun(&self, slab: &mut NounSlab) -> Noun {
        let head = make_tas(slab, "init-config").as_noun();

        // Server config
        let wallet_pkh = make_tas(slab, &self.server.wallet_pkh).as_noun();
        let private_key = make_tas(slab, &self.server.private_key).as_noun();

        // Blockchain config
        let confirmation_blocks = D(self.blockchain.confirmation_blocks);
        let enable_blockchain = if self.blockchain.enable_blockchain {
            YES
        } else {
            NO
        };

        // Game config
        let initial_bank = D(self.game.initial_bank);
        let max_history = D(self.game.max_history_entries);

        // Build the noun: [head wallet-pkh private-key public-key confirmation-blocks enable-blockchain initial-bank max-history]
        let args = T(
            slab,
            &[
                wallet_pkh,
                private_key,
                confirmation_blocks,
                enable_blockchain,
                initial_bank,
                max_history,
            ],
        );

        T(slab, &[head, args])
    }
}

/// Initialize the blackjack server with configuration
pub async fn init_with_config(
    nockapp: &mut NockApp,
    config: &BlackjackConfig,
) -> Result<()> {
    use nockapp::wire::{SystemWire, Wire};

    // Create the config poke
    let mut slab = NounSlab::new();
    let config_noun = config.to_poke_noun(&mut slab);
    slab.set_root(config_noun);

    // Poke the config into the kernel
    let wire = SystemWire.to_wire();
    nockapp
        .poke(wire, slab)
        .await
        .unwrap();
        // .context("Failed to poke config into kernel")?;

    info!("Successfully initialized blackjack server with config");

    Ok(())
}

/// Update balance from Nockchain gRPC
/// Queries the blockchain for the server's current balance and updates the kernel
pub async fn update_balance_from_chain(
    nockapp: &mut NockApp,
    config: &BlackjackConfig,
) -> Result<()> {
    use nockapp::wire::{SystemWire, Wire};
    use nockchain_libp2p_io::tip5_util::tip5_hash_to_base58;
    use nockchain_types::common::Hash;
    use nockchain_wallet::Wallet;
    use nockapp_grpc::public_nockchain;

    info!("Querying balance from Nockchain gRPC...");

    // Parse the server's PKH and convert to first-name noun
    let server_hash = Hash::from_base58(&config.server.wallet_pkh)
        .map_err(|e| anyhow::anyhow!("Failed to parse server wallet_pkh: {}", e))?;

    info!("Parsed PKH hash: {}", server_hash.to_base58());

    // Convert PKH to lock root hash (which serves as the first-name for querying)
    // This uses tx_driver::create_simple_pkh_lock_root which creates a simple 1-of-1
    // PKH spend condition and hashes it with TIP5
    let first_name = tx_driver::create_simple_pkh_lock_root(&server_hash)
        .map_err(|e| anyhow::anyhow!("Failed to create first-name from PKH: {}", e))?;

    info!("Created first-name for query: {}", first_name.to_base58());

    // Connect to the gRPC endpoint
    let mut client = public_nockchain::PublicNockchainGrpcClient::connect(config.grpc.endpoint.clone())
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to Nockchain gRPC: {}", e))?;

    info!("Connected to Nockchain gRPC at {}", config.grpc.endpoint);

    // Query balance from blockchain
    let pubkeys = Vec::new(); // No v0 pubkeys
    let first_names = vec![first_name.to_base58()];

    let pokes = Wallet::update_balance_grpc_public(&mut client, pubkeys, first_names)
        .await
        .map_err(|e| anyhow::anyhow!("Failed to query balance from gRPC: {:?}", e))?;

    info!("Received {} balance update pokes from gRPC", pokes.len());

    // Calculate total balance from all pokes
    let total_balance = calculate_total_balance(&pokes)?;
    info!("Total balance for server PKH: {} nicks", total_balance);

    // Update the blackjack kernel with the new balance
    // Format: [%update-bank new-bank=@ud]
    let mut update_slab = NounSlab::new();
    let update_head = make_tas(&mut update_slab, "update-bank").as_noun();
    let bank_amount = D(total_balance);
    let update_noun = T(&mut update_slab, &[update_head, bank_amount]);
    update_slab.set_root(update_noun);

    // Poke the balance update into the kernel
    let wire = SystemWire.to_wire();
    nockapp
        .poke(wire, update_slab)
        .await
        .map_err(|e| anyhow::anyhow!("Failed to poke balance update into kernel: {:?}", e))?;

    info!("Successfully updated blackjack server balance to {} nicks", total_balance);

    Ok(())
}

/// Calculate total balance from balance update pokes
fn calculate_total_balance(pokes: &[NounSlab]) -> Result<u64> {
    use nockchain_types::tx_engine::v1::note::BalanceUpdate;
    use noun_serde::NounDecode;

    let mut total = 0u64;

    for poke in pokes {
        let root = unsafe { poke.root() };

        // The poke structure is [%update-balance-grpc (unit (unit balance-update))]
        let outer_cell = match root.as_cell()?.tail().as_cell() {
            Ok(cell) => cell,
            Err(_) => continue, // Null outer unit
        };

        let inner_cell = match outer_cell.tail().as_cell() {
            Ok(cell) => cell,
            Err(_) => continue, // Null inner unit
        };

        let balance_update_noun = inner_cell.tail();
        let balance_update = BalanceUpdate::from_noun(&balance_update_noun)
            .map_err(|e| anyhow::anyhow!("Failed to decode balance update: {:?}", e))?;

        // Sum up all note values
        for (_name, note) in balance_update.notes.0.iter() {
            let value = match note {
                nockchain_types::tx_engine::v1::note::Note::V0(v0_note) => {
                    v0_note.tail.assets.0 as u64
                }
                nockchain_types::tx_engine::v1::note::Note::V1(v1_note) => {
                    v1_note.assets.0 as u64
                }
            };
            total += value;
        }
    }

    Ok(total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_validation() {
        let mut config = BlackjackConfig {
            server: ServerConfig {
                wallet_pkh: "test".to_string(),
                private_key: "REPLACE_WITH_ACTUAL_PRIVATE_KEY".to_string(),
            },
            blockchain: BlockchainConfig {
                confirmation_blocks: 3,
                enable_blockchain: false,
                dry_run: true,
            },
            game: GameConfig {
                initial_bank: 1000,
                max_history_entries: 20,
            },
            grpc: GrpcConfig {
                endpoint: "http://127.0.0.1:50051".to_string(),
                client_type: "private".to_string(),
            },
        };

        // Should fail with placeholder keys
        assert!(config.validate().is_err());

        // Should succeed with real keys
        config.server.private_key = "real_key".to_string();
        assert!(config.validate().is_ok());
    }

    #[test]
    fn test_config_to_noun() {
        let config = BlackjackConfig {
            server: ServerConfig {
                wallet_pkh: "test_pkh".to_string(),
                private_key: "test_priv".to_string(),
            },
            blockchain: BlockchainConfig {
                confirmation_blocks: 3,
                enable_blockchain: true,
                dry_run: false,
            },
            game: GameConfig {
                initial_bank: 1000,
                max_history_entries: 20,
            },
            grpc: GrpcConfig {
                endpoint: "http://127.0.0.1:50051".to_string(),
                client_type: "private".to_string(),
            },
        };

        let mut slab = NounSlab::new();
        let _noun = config.to_poke_noun(&mut slab);

        // If we got here without panicking, the noun was constructed successfully
        assert!(true);
    }
}
