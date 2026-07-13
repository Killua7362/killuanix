# RTK (Rust Token Killer) — CLI proxy that compresses verbose dev-command
# output before it reaches an LLM, cutting token consumption 60-90%.
# Not in nixpkgs; built from the upstream git tag. Single crate, no git deps,
# so the committed Cargo.lock drives vendoring (no cargoHash to maintain).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.43.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${version}";
    hash = "sha256-n5bkPPsrdM4fE5ltocTjlq+JwRgp39yib6S79fci4m4=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  # Tests hit the filesystem / expect a configured environment; skip in sandbox.
  doCheck = false;

  meta = {
    description = "CLI proxy that reduces LLM token consumption 60-90% on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    mainProgram = "rtk";
  };
}
