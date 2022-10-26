#
# To run:
#
#    nix-build tests/default.nix
#

let 
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
in
lib.crossLists 
  (enableRtnix: kernelVersion: enableRealtime: enableTimerlat: 
    pkgs.nixosTest({
      name = "rtnix" + "-${kernelVersion}" + (lib.optionalString enableRealtime "-rt") + (lib.optionalString enableTimerlat "-timerlat");
  
      nodes.machine =
        { config, pkgs, ... }:
        { imports = [ ../default.nix ];
  
          rtnix.enable = enableRtnix;
          rtnix.kernel.version = kernelVersion;
          rtnix.kernel.realtime = enableRealtime;
          rtnix.kernel.timerlat = enableTimerlat;
        };
  
      testScript = ''
        machine.start()
        machine.wait_for_unit("default.target")
      '' 
      + (lib.optionalString enableRealtime ''
        result = machine.succeed("uname -v")
        print(result)
        if not "PREEMPT RT" or not "PREEMPT_RT" in result:
            raise Exception("Realtime not enabled")
      '')
      + (lib.optionalString enableTimerlat ''
        result = machine.succeed("zcat /proc/config.gz | grep TIMERLAT")
        print(result)
        if not "CONFIG_TIMERLAT_TRACER=y" in result:
            raise Exception("Missing timerlat tracing")
      '')
      + ''
        print("PASSED")
      '';
    })
  ) 
 
  # The combinations we test (gets expanded by lib.crossLists above):
  [ 
    # rtnix.enable:
    [ true ] 

    # rtnix.kernel.version:
    [ "4.9" "4.14" "4.19" "5.4" "5.10" "5.15" "5.19" "6.0" ] 

    # rtnix.kernel.realtime: 
    [ true ] 

    # rtnix.kernel.timerlat:
    [ true false ] 
  ]
