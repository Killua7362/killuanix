{ config, pkgs, inputs, ... }:
{
  programs.opencode = {
    enable = true;
    package = inputs.opencode-flake.packages.${pkgs.system}.default;
    settings = {
      autoupdate = true;
      provider = {
        gl4f = {
          npm = "@ai-sdk/openai-compatible";
          name = "Gl4f";
          options = {
            baseURL = "https://g4f.space/api/nvidia";
          };
          models = {
            "minimaxai/minimax-m2.1" = {
                name = "MiniMax aiii";
              };
          };
        };
      };
      mcp = {
      };
    };
  };
}
