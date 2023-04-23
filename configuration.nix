{ config, pkgs, lib, ... }:

let
  variables = {
    ethInterface = "enp1s0";
    email = "bossley.samuel@gmail.com";
    domain = "sam.bossley.us";
    hostname = "webserver";
    userHome = /home/nixos;
    rsyncPort = 873;
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.allowedUsers = [ "@wheel" ];

  boot.loader = {
    grub = {
      enable = true;
      version = 2;
      device = "/dev/vda";
    };
    timeout = 2;
  };

  networking = {
    hostName = variables.hostname;
    useDHCP = false; # False recommended for security
    interfaces.${variables.ethInterface}.useDHCP = true;
  };

  services.timesyncd.enable = true;
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users.mutableUsers = false;
  users.users.nixos = {
    isNormalUser = true;
    initialPassword = "test1234!";
    extraGroups = [ "wheel" ];
    home = (builtins.toString variables.userHome);
    openssh.authorizedKeys.keys = lib.strings.splitString "\n" (builtins.readFile ./keys.pub);
  };
  environment.defaultPackages = lib.mkForce [ ]; # Remove default packages for security
  environment.systemPackages = with pkgs; [
    vim
    git
    rsync
  ];
  environment.shellInit = ''
    umask 0077
  '';

  security = {
    sudo.enable = false;
    doas = {
      enable = true;
      extraRules = [
        { groups = [ "wheel" ]; noPass = true; keepEnv = true; }
      ];
    };
    lockKernelModules = true; # Disable loading kernel modules after boot
  };

  services.openssh = {
    enable = true;
    allowSFTP = false;
    passwordAuthentication = false;
    permitRootLogin = "no";
    forwardX11 = false;
    extraConfig = ''
      AuthenticationMethods publickey
    '';
  };
  services.sshguard.enable = true;

  # Automatically garbage collect nix
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  # Reduce systemd journaling
  services.journald.extraConfig = ''
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

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # OpenSSH (automatically allowed but explicitly adding for sanity)
      80 # HTTP
      443 # HTTPS
      variables.rsyncPort # Rsync
    ];
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = variables.email;
  };
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "${variables.domain}" = {
        forceSSL = true;
        enableACME = true;
        root = "/var/www/${variables.domain}";
        extraConfig = ''
          # security headers
          location / {
            add_header X-Frame-Options "sameorigin";
            add_header X-XSS-Protection "1";
            add_header X-Content-Type-Options "nosniff";
            add_header X-Permitted-Cross-Domain-Policies "none";
            add_header Strict-Transport-Security "max-age=31536000";
            add_header Content-Security-Policy "default-src * data:; script-src https: 'unsafe-inline' 'unsafe-eval'; style-src https: 'unsafe-inline'";
            add_header Referrer-Policy "no-referrer-when-downgrade";
            add_header Feature-Policy "camera 'none'; fullscreen 'self'; geolocation 'none'; microphone 'none'";
          }

          # static asset caching
          location ~* .(?:css|js|woff)$ {
            expires 1y;
            add_header Cache-Control "public, no-transform";
          }
        '';
      };
    };
  };

  services.rsyncd = {
    enable = true;
    port = variables.rsyncPort;
  };

  system.stateVersion = "22.05"; # required
}
