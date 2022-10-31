let 
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  makeTest = import ./maketest.nix;
in
lib.crossLists 
  (enableRtnix: kernelVersion: enableRealtime: enableTimerlat: makeTest { inherit enableRtnix kernelVersion enableRealtime enableTimerlat; }) 
 
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
