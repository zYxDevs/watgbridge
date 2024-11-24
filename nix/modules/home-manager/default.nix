self:
(
  {
    lib,
    config,
    pkgs,
    ...
  }:
  let
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (lib) mapAttrs' mkIf;
    cfg = config.services.watgbridge;

    package = self.packages."${system}".watgbridge;
  in
  {
    options = {
      services.watgbridge = import ../commonOptions.nix {
        inherit lib package;
        forNixos = false;
      };
    };

    config = mkIf cfg.enable {
      home.packages = [ cfg.commonSettings.package or package ];

      systemd.user.services = mapAttrs' (
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

        in
        {

          name = instanceName;

          value = mkIf settings.enable {
            Unit = {
              Description = "WaTgBridge service for '${instanceName}'";
              Documentation = "https://github.com/akshettrj/watbridge";
              After = [ "network.target" ] ++ lib.optionals (after != null) after;
            };

            Service =
              {
                ExecStart = command;
                Restart = "on-failure";
                RuntimeDirectory = instanceName;
                StateDirectory = instanceName;
              }
              // (lib.optionalAttrs (maxRuntime != null) {
                RuntimeMaxSec = maxRuntime;
              })
              // (lib.optionalAttrs (settings.workingDirectory != null) {
                WorkingDirectory = settings.workingDirectory;
              });

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

        }
      ) cfg.instances;
    };
  }
)
