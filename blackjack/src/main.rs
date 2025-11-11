use std::error::Error;
use std::fs;

use blackjack::{BlackjackConfig, init_with_config};
use nockapp::http_driver;
use nockapp::kernel::boot;
use nockapp::NockApp;
use tracing::{info, warn};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let cli = boot::default_boot_cli(false);
    boot::init_default_tracing(&cli);

    // Load configuration from TOML file
    let config_path = "blackjack-config.toml";
    let config = match BlackjackConfig::load(config_path) {
        Ok(cfg) => {
            info!("Successfully loaded config from {}", config_path);
            cfg
        }
        Err(e) => {
            warn!("Failed to load config from {}: {}", config_path, e);
            warn!("Falling back to hardcoded config (for development only)");
            // Fallback to hardcoded config for development
            BlackjackConfig {
                server: blackjack::ServerConfig {
                    wallet_pkh: "9yPePjfWAdUnzaQKyxcRXKRa5PpUzKKEwtpECBZsUYt9Jd7egSDEWoV".to_string(),
                    private_key: "PLACEHOLDER_PRIVKEY".to_string(),
                    public_key: "PLACEHOLDER_PUBKEY".to_string(),
                },
                blockchain: blackjack::BlockchainConfig {
                    confirmation_blocks: 3,
                    enable_blockchain: false,
                },
                game: blackjack::GameConfig {
                    initial_bank: 1000,
                    max_history_entries: 20,
                },
                grpc: blackjack::GrpcConfig {
                    endpoint: "http://127.0.0.1:50051".to_string(),
                    client_type: "private".to_string(),
                },
            }
        }
    };

    // Load kernel
    let kernel = fs::read("out.jam").map_err(|e| format!("Failed to read out.jam: {}", e))?;

    // Setup NockApp
    let mut nockapp: NockApp = boot::setup(&kernel, cli, &[], "http-server", None)
        .await
        .map_err(|e| format!("Kernel setup failed: {}", e))?;

    // Initialize with config (poke config into kernel)
    if let Err(e) = init_with_config(&mut nockapp, &config).await {
        warn!("Failed to initialize with config: {}", e);
        warn!("Continuing with default kernel state");
    }

    // TODO: Query and update balance from Nockchain gRPC
    // if config.blockchain.enable_blockchain {
    //     update_balance_from_chain(&mut nockapp, &config).await?;
    // }

    // Add HTTP driver and run
    nockapp.add_io_driver(http_driver()).await;
    info!("Starting blackjack HTTP server...");
    nockapp.run().await.expect("Failed to run app");

    Ok(())
}
