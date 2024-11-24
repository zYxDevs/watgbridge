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

          maxRuntime = (
            if settings.maxRuntime != null then settings.maxRuntime else cfg.commonSettings.maxRuntime
          );

          requires = (if settings.requires != null then settings.requires else cfg.commonSettings.requires);

        in
        {

          name = instanceName;

          value = mkIf settings.enable {
            Unit =
              {
                Description = "WaTgBridge service for '${instanceName}'";
                Documentation = "https://github.com/akshettrj/watbridge";
                After = [ "network.target" ];
              }
              // lib.optionalAttrs (requires != null) {
                Requires = requires;
              };

            Service =
              {
                ExecStart =
                  ''${watgbridgePackage}/bin/watbridge''
                  + (lib.optionalString (settings.configPath != null) ''"${settings.configPath}"'');
                Restart = "on-failure";
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
