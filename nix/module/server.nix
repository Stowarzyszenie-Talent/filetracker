{ pkgs, lib, config, ... }:

{
  options.services.filetracker = {
    enable = lib.mkEnableOption "filetracker server";

    package = lib.mkPackageOption pkgs "Filetracker" {
      default = [ "python310Packages" "filetracker" ];
    };

    listenAddress = lib.mkOption {
      default = "0.0.0.0";
      description = "The address that filetracker-server will listen on";
      type = lib.types.str;
    };

    port = lib.mkOption {
      default = 9999;
      description = "The port that filetracker-server will listen on";
      type = lib.types.port;
    };

    ensureFiles = lib.mkOption {
      default = { };
      description = "Files that should be added to filetracker after start";
      type = lib.types.attrsOf lib.types.path;
    };

    workers = lib.mkOption {
      default = "auto";
      description = "The number of gunicorn workers to spawn";
      type = with lib.types; oneOf [ (strMatching "auto") ints.positive ];
    };

    separateStdoutFromJournal = lib.mkOption {
      default = false;
      description = ''
        Redirect the filetracker server's stdout to a file in /var/log/sio2.
        You have to ensure that directory exists and rotate the logs yourself,
        unless you use talentsio, which does the former.
      '';
      type = lib.types.bool;
    };
  };

  config =
    let
      cfg = config.services.filetracker;
      python = cfg.package.pythonModule;

      createEnsureService = remotePath: localPath:
        let
          systemdEscapedPath = builtins.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" remotePath);
          serviceName = "filetracker-put-${systemdEscapedPath}";
        in
        lib.nameValuePair serviceName {
          enable = true;
          description = "Filetracker ensure ${remotePath}";
          after = [ "filetracker.service" ];
          # We want to "stop" if ft is stopped, so we will run again when ft starts.
          partOf = [ "filetracker.service" ];
          # We need to start on creation, hence the "multi-user.target".
          wantedBy = [ "multi-user.target" "filetracker.service" ];

          environment = {
            REMOTE_PATH = remotePath;
            SOURCE_PATH = localPath;
            FILETRACKER_MEDIA_ROOT = "/var/lib/filetracker";
            FILETRACKER_URL = "http://${cfg.listenAddress}:${builtins.toString cfg.port}";
          };

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "true";
            ExecStart = "${python.withPackages (pp: [ pp.filetracker ])}/bin/python3 ${../filetracker-ensure.py}";
          };
        };
    in
    lib.mkIf cfg.enable {
      users.extraUsers.filetracker = {
        isSystemUser = true;
        group = "filetracker";
      };
      users.extraGroups.filetracker = { };

      systemd.services = {
        filetracker = {
          enable = true;
          description = "Filetracker Server";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          script = ''
            exec ${cfg.package}/bin/filetracker-server \
              --workers ${if cfg.workers == "auto" then "$(nproc)" else builtins.toString cfg.workers} \
              -d /var/lib/filetracker \
              -l ${lib.escapeShellArg cfg.listenAddress} \
              -p ${builtins.toString cfg.port} \
              -D
          '';

          serviceConfig = {
            Type = "simple";
            ReadWritePaths = [ "/tmp" ];
            StateDirectory = "filetracker";
            User = "filetracker";
            Group = "filetracker";
            # S*stemd is retarded and tries to open the stdout file first
            #LogsDirectory = lib.mkIf cfg.separateStdoutFromJournal "sio2";
            StandardOutput = lib.mkIf cfg.separateStdoutFromJournal "append:/var/log/sio2/filetracker.log";

            PrivateTmp = true;
            ProtectSystem = "strict";
            RemoveIPC = true;
            NoNewPrivileges = true;
            RestrictSUIDSGID = true;
            ProtectKernelTunables = true;
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            PrivateDevices = true;
          };
        };
      } // (lib.mapAttrs' createEnsureService cfg.ensureFiles);
    };
}
