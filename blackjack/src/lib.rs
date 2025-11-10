use std::error::Error;

use clap::{arg, command, Parser, Subcommand};
use nockapp::driver::Operation;
use nockapp::kernel::boot;
use nockapp::noun::slab::NounSlab;
use nockapp::utils::make_tas;
use nockapp::{file_driver, markdown_driver, AtomExt, NockApp};
use nockapp_grpc::private_nockapp::grpc_listener_driver;
use nockvm::noun::{D, T};
use nockvm_macros::tas;
use tracing::info;
use zkvm_jetpack::hot::produce_prover_hot_state;

// The point of this library is to facilitate requesting Nockchain state and building transactions using the wallet.
