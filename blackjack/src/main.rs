use std::error::Error;
use std::fs;

use blackjack::{BlackjackConfig, init_with_config};
use clap::Parser;
use kernels::wallet::KERNEL as WALLET_KERNEL;
use nockapp::{http_driver, one_punch_driver, NockAppError};
use nockapp::driver::Operation;
use nockapp::kernel::boot;
use nockapp::kernel::boot::NockStackSize;
use nockapp::noun::slab::NounSlab;
use nockapp::NockApp;
use nockchain_wallet::Wallet;
use nockvm::noun::{D, T};
use nockvm_macros::tas;
use tracing::{info, warn};
use zkvm_jetpack::hot::produce_prover_hot_state;

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
                    // public_key: "PLACEHOLDER_PUBKEY".to_string(),
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

    let mut nockapp: NockApp = boot::setup(&kernel, cli.clone(), &[], "blackjack", None)
        .await
        .map_err(|e| format!("Kernel setup failed: {}", e))?;

    // Initialize with config (poke config into kernel)
    if let Err(e) = init_with_config(&mut nockapp, &config).await {
        warn!("Failed to initialize with config: {}", e);
        warn!("Continuing with default kernel state");
    }

        // Set up wallet client.
    let prover_hot_state = produce_prover_hot_state();
    let wallet_kernel = boot::setup(
        WALLET_KERNEL,
        cli.clone(),
        prover_hot_state.as_slice(),
        "tx-driver-wallet",
        None,
    )
    .await
    .map_err(|e| NockAppError::OtherError(format!("Kernel setup failed: {}", e)))?;

    let wallet = Wallet::new(wallet_kernel);

    rustls::crypto::aws_lc_rs::default_provider()
        .install_default()
        .expect("default provider already set elsewhere");

    let args = tx_driver::Args::parse();

    info!("Starting tx-driver");

    let mut boot_config = boot::default_boot_cli(false);
    boot_config.stack_size = NockStackSize::Tiny;

    info!("Adding IO drivers");

    // Prepare the initial poke to trigger the tx effect
    let mut poke_slab = NounSlab::new();
    let cause_noun = T(&mut poke_slab, &[D(tas!(b"born")), D(0x0)]);
    poke_slab.set_root(cause_noun);

    // Get the gRPC target from command line args
    let grpc_target = args.connection.target();
    let dry_run = args.dry_run;

    nockapp
        .add_io_driver(one_punch_driver(poke_slab, Operation::Poke))
        .await;
    nockapp
        .add_io_driver(tx_driver::tx_driver(grpc_target, wallet, dry_run))
        .await;


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
