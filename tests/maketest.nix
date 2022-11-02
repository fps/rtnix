# To test a particular combination run for example:
#
# nix-build tests/maketest.nix --argstr kernelVersion 6.0 --arg enableRtnix true --arg enableRealtime true --arg enableTimerlat true

{ kernelVersion, enableRealtime, enableTimerlat }:
let 
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
in
  pkgs.nixosTest({
    name = "rtnix" + "-${kernelVersion}" + (lib.optionalString enableRealtime "-rt") + (lib.optionalString enableTimerlat "-timerlat");

    nodes.machine =
      { config, pkgs, ... }:
      { imports = [ ../default.nix ];

        rtnix.enable = true;
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
      if not "PREEMPT RT" and not "PREEMPT_RT" in result:
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
