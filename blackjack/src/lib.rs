use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

use nockapp::noun::slab::NounSlab;
use nockapp::utils::make_tas;
use nockapp::NockApp;
use nockvm::noun::{Noun, D, T, YES, NO};
use tracing::info;

pub mod tx_driver;

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
/// This would call the gRPC endpoints to get the server's current notes
/// For now, this is a placeholder that would be implemented similar to the wallet's update_balance_grpc_private
pub async fn update_balance_from_chain(
    _nockapp: &mut NockApp,
    _config: &BlackjackConfig,
) -> Result<()> {
    // TODO: Implement gRPC balance querying
    // This would:
    // 1. Connect to the gRPC endpoint from config
    // 2. Query balance for server's wallet_pkh
    // 3. Parse the response into a balance update noun
    // 4. Poke it into the kernel with tag 'update-balance-grpc'

    info!("Balance update from chain (not yet implemented)");

    Ok(())
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
