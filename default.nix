{ config, lib, pkgs, ... }:
let 
  rtnix = config.rtnix;

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

    intelPStatePassive = lib.mkOption {
      type = lib.types.bool;
      default = false;
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

    setCpuDmaLatency = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    disableBoost = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    maxPerfPct = lib.mkOption {
      type = lib.types.int;
      default = 50;
    };

    minPerfPct = lib.mkOption {
      type = lib.types.int;
      default = 50;
    };

    setMinMaxPerfPct = lib.mkOption {
      type = lib.types.bool;
      default = false;
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

    boot.kernelPackages = lib.mkIf rtnix.kernel.realtime.enable pkgs.linuxPackages-rt_latest;

    boot.kernelParams = lib.mkMerge [
      (lib.mkIf rtnix.disableCStates [ "processor.max_cstate=0" "idle=poll" ]) 
      (lib.mkIf rtnix.intelPStatePassive [ "intel_pstate=passive" ])
    ];

    services.udev.extraRules = ''
      SUBSYSTEM=="sound", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="processPriorityTuning.service"
    '';

    systemd.services.setMinMaxPerfPct = lib.mkIf rtnix.setMinMaxPerfPct {
      enable = true;
      description = "Set intel_pstate min and max_perf_pct";
      wantedBy = [ "basic.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c \"echo ${builtins.toString rtnix.minPerfPct} > /sys/devices/system/cpu/intel_pstate/min_perf_pct && echo ${builtins.toString rtnix.maxPerfPct} > /sys/devices/system/cpu/intel_pstate/max_perf_pct\"";
        User = "root";
      };
    };

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
      rt-tests config.boot.kernelPackages.perf
    ];

    systemd.services.disableBoost = lib.mkIf rtnix.disableBoost {
      enable = true;
      description = "Disable processor boost";
      wantedBy = [ "basic.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c \"echo 0 > /sys/devices/system/cpu/cpufreq/boost\"";
        User = "root";
      };
    };
       
    systemd.services.setCpuDmaLatency = lib.mkIf rtnix.setCpuDmaLatency {
      enable = true;
      description = "Set CPU DMA latency";
      wantedBy = [ "basic.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c \"exec 3<> /dev/cpu_dma_latency; echo 0 >&3; while true; do sleep 1; done\"";
        User = "root";
      };
    };
 
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
