{ pkgs, lib, config, ... }:

{
  options = {
    services.filetracker-cache-cleaner = {
      enable = lib.mkEnableOption "filetracker cache cleaner";

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = ''
          Cache directories to clean.
          Note that the "filetracker" user should have read/write access to these directories.
        '';
      };

      dates = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = ''
          How often or when the filetracker cache cleaner is run.

          For more information on the format consult systemd.time(7), specifically the section "CALENDAR EVENTS".
        '';
      };

      persistent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          If true, systemd will store the time the cache cleaner was run, when the system is powered on systemd will check if the timer would've been triggered while the computer was powered off and if so, trigger the timer.
        '';
      };

      sizeLimit = lib.mkOption {
        type = lib.types.strMatching "([0-9]+[BKMGT])+";
        description = ''
          The size limit for the filetracker cache.
        '';
      };

      cleaningLevel = lib.mkOption {
        type = lib.types.ints.between 0 100;
        default = 50;
        description = ''
          Percent of cache size limit that should *NOT* be deleted while cleaning the cache.
          Files are deleted from oldest to newest.
        '';
      };
    };
  };

  config =
    let
      cfg = config.services.filetracker-cache-cleaner;
    in
    lib.mkIf cfg.enable {
      systemd.services.filetracker-cache-cleaner = {
        enable = true;
        description = "Filetracker cache cleaner";

        serviceConfig = {
          ExecStart = ''
            ${pkgs.filetracker}/bin/filetracker-cache-cleaner \
              -o \
              -s ${lib.escapeShellArg cfg.sizeLimit} \
              -p ${builtins.toString cfg.cleaningLevel} \
              -c ${lib.escapeShellArgs cfg.paths}
          '';
        };
      };

      systemd.timers.filetracker-cache-cleaner = {
        enable = true;
        description = "Filetracker cache cleaner";

        timerConfig = {
          OnCalendar = cfg.dates;
          Persistent = cfg.persistent;
          Unit = "filetracker-cache-cleaner.service";
        };
      };
    };
}

