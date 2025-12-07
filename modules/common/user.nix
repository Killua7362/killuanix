{
  # User configuration that can be shared across systems
  userConfig = {
    username = "killua";
    email = "bhat7362@gmail.com";
    fullName = "Killua7362";

    # Common home directories
    homeDirectories = {
      linux = "/home/killua";
      mac = "/Users/killua";
    };

    # Common session variables
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "xterm-256color";
      COLORTERM = "truecolor";
      LANGUAGE = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      LANG = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";
    };

    # SSH keys
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHneczMjHD8zJgu5j73XDS8C+4+/XqIRSsoBEZqJaEVR bhat7362@gmail.com"
    ];
  };
}
