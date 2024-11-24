self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (lib) mkIf mapAttrs';
  cfg = config.services.watgbridge;

  package = self.packages."${system}".watgbridge;
in
{
  options = {
    services.watgbridge = import ../commonOptions.nix {
      inherit lib package;
      forNixos = true;
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = false;
        message = "The NixOS module is not complete yet. Use home-manager module for now if possible.";
      }
    ];

    environment.systemPackages = [ cfg.commonSettings.package or package ];

    systemd.services = mapAttrs' (
      key: settings:
      let

        instanceName = (
          if settings.name != null then "watgbridge-${settings.name}" else "watgbridge-${key}"
        );
        watgbridgePackage = (
          if settings.package != null then settings.package else cfg.commonSettings.package
        );

        command =
          "${watgbridgePackage}/bin/watbridge"
          + (if settings.configPath != null then " ${settings.configPath}" else "");

        maxRuntime = (
          if settings.maxRuntime != null then settings.maxRuntime else cfg.commonSettings.maxRuntime
        );

        after = (if settings.requires != null then settings.requires else cfg.commonSettings.requires);

        user = (if settings.user != null then settings.user else cfg.commonSettings.user);

        group = (if settings.group != null then settings.group else cfg.commonSettings.group);

      in
      {
        name = instanceName;

        value = mkIf settings.enable {
          description = "WaTgBridge service for '${instanceName}'";
          documentation = "https://github.com/akshettrj/watgbridge";
          after = [ "network.target" ] ++ lib.optionals (after != null) after;
          script = command;

          wantedBy = [ "default.target" ];

          serviceConfig =
            {
              Restart = "on-failure";
            }
            // (lib.optionalAttrs (settings.workingDirectory != null) {
              WorkingDirectory = settings.workingDirectory;
            })
            // (lib.optionalAttrs (maxRuntime != null) {
              RuntimeMaxSec = maxRuntime;
            })
            // (lib.optionalAttrs (user != null) {
              User = user;
            })
            // (lib.optionalAttrs (group != null) {
              Group = group;
            });
        };
      }
    );
  };
}
