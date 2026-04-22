# System-level sops secrets (NixOS).
#
# Mirrors modules/common/sops.nix (the Home Manager variant) but for NixOS
# secrets that need to exist before user-login — e.g. the LiteLLM container's
# API keys, read by systemd services running as root.
#
# Decrypted secrets land under /run/secrets/<name> with mode 0400, owned by root.
{...}: {
  sops = {
    age.keyFile = "/home/killua/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/personal.yaml;
    secrets = {
      nvidia_api_key = {};
      google_studio_key = {};
      mistral_api_key = {};
      mistral_codestral_api_key = {};
      icloud_email = {};
    };
  };
}
