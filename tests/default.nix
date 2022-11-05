let 
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  makeTest = import ./maketest.nix;
in
builtins.map 
  (with lib; options: 
    makeTest { kernelVersion = (elemAt options 0); enableRealtime = (elemAt options 1); enableTimerlat = (elemAt options 2); }) 
 
    #version realtime timerlat
    [ 
      [ "4.9"   true  false ] 
      [ "4.14"  true  false ]
      [ "4.19"  true  false ]
      [ "5.4"   true  false ]
      [ "5.10"  true  false ]
      [ "5.15"  true  false ]
      [ "6.0"   true  false ]
      [ "6.0"   true  true  ]
    ] 
