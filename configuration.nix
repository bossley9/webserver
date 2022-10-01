# See configuration.nix(5) for more information.
# vim: fdm=marker

{ config, pkgs, lib, ... }:

let
  variables = {
    ethInterface = "enp1s0";
    email = "bossley.samuel@gmail.com";
    domain = "sam.bossley.us";
    hostname = "webserver";
    userHome = /home/nixos;
  };

in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # boot {{{
  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/vda";
  };
  boot.loader.timeout = 2;
  # }}}

  # networking {{{
  networking.useDHCP = false; # False recommended for security
  networking.interfaces.${variables.ethInterface}.useDHCP = true;
  networking.hostName = variables.hostname;
  # }}}

  # localization {{{
  services.timesyncd.enable = true;
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
  # }}}

  # user space {{{
  users.mutableUsers = false;
  users.users.nixos = {
    isNormalUser = true;
    initialPassword = "test1234!";
    extraGroups = [ "wheel" ];
    home = (builtins.toString variables.userHome);
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };

  environment.defaultPackages = lib.mkForce []; # Remove default packages for security
  environment.systemPackages = with pkgs; [
    vim git
  ];

  environment.shellInit = ''
    umask 0077
  '';
  # }}}

  # security and access {{{
  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      { groups = [ "wheel" ]; noPass = true; keepEnv = true; }
    ];
  };
  nix.allowedUsers = [ "@wheel" ];
  security.lockKernelModules = true; # Disable loading kernel modules after boot

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
    allowSFTP = false;
    forwardX11 = false;
    extraConfig = ''
      AuthenticationMethods publickey
    '';
  };
  services.sshguard.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # OpenSSH (automatically allowed but explicitly adding for sanity)
      80 443 # HTTP and HTTPS
    ];
  };
  # }}}

  # optimization {{{
  # Automatically garbage collect nix
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  # Reduce systemd journaling
  services.journald.extraConfig =
  ''
    SystemMaxUse=250M
    MaxRetentionSec=7day
  '';
  services.cron = {
    enable = true;
    systemCronJobs = [
      # Reboot on Sundays at 3 AM
      "0 3 * * 0 root reboot"
    ];
  };
  # }}}

  # webserver {{{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = variables.email;
  services.nginx = {
    enable = true;
    virtualHosts = {
      "${variables.domain}" = {
        forceSSL = true;
        enableACME = true;
        root = "/var/www/${variables.domain}";
      };
    };
  };
  # }}}

  # required {{{
  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
  # }}}
}
