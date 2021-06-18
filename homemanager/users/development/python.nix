{ pkgs, config, inputs, ... }:

{
  home.packages = with pkgs; [
    python3
    python3.pkgs.ueberzug
    python3.pkgs.pdf2image
  ];
}
