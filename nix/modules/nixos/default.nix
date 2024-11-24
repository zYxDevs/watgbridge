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

  package = self.packages."${system}".watgbridge;
in
{
  options = {
    services.watgbridge = import ../commonOptions.nix {
      inherit lib package;
      forNixos = true;
    };
  };

  config =
    let
      cfg = config.services.watgbridge;
    in
    mkIf cfg.enable {
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

          after = (if settings.after != null then settings.after else cfg.commonSettings.after);

          user = (if settings.user != null then settings.user else cfg.commonSettings.user);

          group = (if settings.group != null then settings.group else cfg.commonSettings.group);

        in
        {
          name = instanceName;

          value = mkIf settings.enable {
            description = "WaTgBridge service for '${instanceName}'";
            documentation = [ "https://github.com/akshettrj/watgbridge" ];
            after = [ "network.target" ] ++ lib.optionals (after != null) after;
            script = command;

            wantedBy = [ "default.target" ];

            serviceConfig =
              {
                Restart = "on-failure";
                RuntimeDirectory = instanceName;
                StateDirectory = instanceName;
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
      ) cfg.instances;
    };
}
