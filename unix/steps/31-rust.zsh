# The Rust toolchain

update() {
  info 'Rust toolchain'
  (( $+commands[rustup] )) || { skip 'rustup not installed'; return }
  rustup update || todo+=('rustup update failed: read its output above')
}
