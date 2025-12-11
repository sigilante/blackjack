use nockvm_macros::tas;
fn main() {
    let leaf = tas!(b"leaf");
    let hash = tas!(b"hash");
    println!("leaf tag: 0x{:x} ({})", leaf, leaf);
    println!("hash tag: 0x{:x} ({})", hash, hash);
}
