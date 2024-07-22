{ config, lib, pkgs, ... }:
let 
  rtnix = config.rtnix;
  pkgs_master = import /home/fps/src/nix/master/nixpkgs {};

  in
{
  options.rtnix = {
    kernel.realtime.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tuningMaxPriority = lib.mkOption {
      type = lib.types.int;
      default = 90;
    };

    disableCStates = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tuningProcesses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = lib.mdDoc "A list of regex strings passed to pgrep to determine the PIDs of processes that are set to SCHED_FIFO with priorities tuningMaxPriority, tuningMaxPriority - 1, ...";
      default = [ ];
    };

    powerManagementTuning = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  }; 

  config =  {
    users.groups.realtime = {};

    security.pam.loginLimits = [
      { domain = "@realtime"; item = "memlock"; type = "-"   ; value = "unlimited"; }
      { domain = "@realtime"; item = "rtprio" ; type = "-"   ; value = "99"       ; }
      { domain = "@realtime"; item = "nofile" ; type = "soft"; value = "99999"    ; }
      { domain = "@realtime"; item = "nofile" ; type = "hard"; value = "99999"    ; }
    ];

    boot.kernelPackages = lib.mkIf rtnix.kernel.realtime.enable pkgs_master.linuxPackages-rt_latest;

    boot.kernelParams = lib.mkIf rtnix.disableCStates [ "processor.max_cstate=1" "idle=poll" ];

    services.udev.extraRules = ''
      SUBSYSTEM=="sound", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="processPriorityTuning.service"
    '';

    systemd.services.processPriorityTuning = {
      enable = true;
      description = "Tune process priorities";
      # wantedBy = [ "-.mount" ];
      # after = [ "-.mount" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.imap0 (i: x: "${pkgs.bash}/bin/bash -c 'for pid in $(${pkgs.procps}/bin/pgrep \'" + x + "\'); do echo Tuning: \'" + x + "\' \"with pid(s): $pid\"...; ${pkgs.util-linux}/bin/chrt --pid -f " + (builtins.toString (rtnix.tuningMaxPriority - i)) + " $pid; done'") rtnix.tuningProcesses;
        User = "root";
      };
    };

    environment.systemPackages = with pkgs; [ 
      rt-tests
    ];

    systemd.services.powerManagementTuning = lib.mkIf rtnix.powerManagementTuning
      (let powerTuning = pkgs.writeShellScript "powerTuning.sh" ''
        ${pkgs.findutils}/bin/find /sys/devices/ -maxdepth 5 -path '*/pci*/power/control' -exec ${pkgs.bash}/bin/bash -c "echo tuning {}; echo on > {};" \;
      ''; in
      {
        enable = true;
        description = "Power management tuning in sysfs";
        wantedBy = [ "basic.target" ];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${powerTuning}";
          User = "root";
        };
      });
  };
}
