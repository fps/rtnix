{ config, lib, pkgs, ... }:
let 
  rtnix = config.rtnix;

  # Some utility functions to extract infos from a kernel version string:
  makeKernelMajorVersion = 
    kernelVersion: 
      lib.head (lib.splitString "." kernelVersion);

  makeKernelBranch = 
    kernelVersion: 
      lib.concatStringsSep "." (lib.take 2 (lib.splitString "." kernelVersion));

  # Some utility functions to create URLs for kernel and patch versions;
  makeKernelUrl = 
    kernelVersion: 
      "mirror://kernel/linux/kernel/v${makeKernelMajorVersion kernelVersion}.x/linux-${kernelVersion}.tar.xz";

  makePatchUrl = 
    kernelVersion: patchVersion: 
      "https://cdn.kernel.org/pub/linux/kernel/projects/rt/${makeKernelBranch kernelVersion}/older/patch-${kernelVersion}-${patchVersion}.patch.gz";

  # This function is used to translate a string like linux_6.0 to linux_6_0 in the package overrides:
  dotToUnderscore = 
    s: 
      builtins.replaceStrings [ "." ] [ "_" ] s;
  
  # A small function to embellish the metadata with the kernel and patch urls:
  addUrlsToMetadata = 
    name: { kernelVersion, patchVersion, kernelModDirVersion ? kernelVersion + "-" + patchVersion, ... }@args: 
    { 
      patchUrl = makePatchUrl kernelVersion patchVersion; 
      kernelUrl = makeKernelUrl kernelVersion; 
      inherit kernelModDirVersion;
    } // args;

  metadata = 
    builtins.mapAttrs addUrlsToMetadata branch_metadata; 

  # The metadata as attribute set using the branch as attribute names:
  branch_metadata = 
    builtins.listToAttrs 
      (map (x: { name = makeKernelBranch x.kernelVersion; value = x; }) raw_metadata);

  rtExtraConfig4 = with lib.kernel; {
    PREEMPT = lib.mkForce yes;
    PREEMPT_RT_FULL = yes;
    PREEMPT_VOLUNTARY = lib.mkForce no;
    RT_GROUP_SCHED = lib.mkForce (option no)
  ;};

  rtExtraConfig5 = with lib.kernel; {
    EXPERT = yes;
    PREEMPT_RT = yes;
    PREEMPT_VOLUNTARY = lib.mkForce no;
  };

  # We use the newest RT kernels corresponding to the nixpkgs.linuxPackages for LTS kernels:
  raw_metadata = with lib.kernel; [
    { 
      kernelVersion = "4.9.319"; 
      kernelHash = "sha256-V6frcqPflkcwCz1yA6KMZ24Q8pn9qJaqnaHMkuwSRIQ="; 
      patchVersion = "rt195"; 
      patchHash = "sha256:0cmp4svgim2yp4g2mbpfmw11dp737q60x9gcq108r7pw3zzdg248"; 
      extraConfig = rtExtraConfig4;
    }
    { 
      kernelVersion = "4.14.296"; 
      kernelHash = "sha256-LdXNsnPhH3DZs+7bBREqfzTDyaXjcpdwxpNzv/Czm9g="; 
      patchVersion = "rt139"; 
      patchHash = "sha256:03i0z2nhb70jlgqkshhqsb1ksyih538hx2jngl4ci4rqf1qd2q5q"; 
      extraConfig = rtExtraConfig4;
    }
    { 
      kernelVersion = "4.19.255"; 
      kernelHash = "sha256-dzmSBj9MCVYmCv3ZRsdt3/772cJS6AC+YJRWlsAbikM="; 
      patchVersion = "rt113"; 
      patchHash = "sha256:0aq34azpjgfawswipk6ji3a4ynl447gqgwdxx7rpxjyzcva7vsh6"; 
      extraConfig = rtExtraConfig4 // (with lib.kernel; { XEN_TMEM = lib.mkForce module; });
    }
    { 
      kernelVersion = "5.4.209"; 
      kernelHash = "sha256-DoeRe8clqeO1TGdRuRnxLzILjVtQdYW7+lf/M1P6ts0="; 
      patchVersion = "rt77"; 
      patchHash = "sha256:120k5yjy9xj84mdz2h258ghjm6z4zaxn8dh8wz2631slvjv27w1k"; 
      extraConfig = rtExtraConfig5 // (with lib.kernel; { RT_GROUP_SCHED = lib.mkForce (option no); });
    } 
    { 
      kernelVersion = "5.10.152"; 
      kernelHash = "sha256-+gtcg6Tr/anwpSzGk2RutsJNut5sN+4tGLZu4t8V2KY="; 
      patchVersion = "rt75"; 
      patchHash = "sha256:0kbza7wwsvak8bv7l9hfzi0nsb31486p2khxj895vxvm8lrjd13w"; 
      extraConfig = rtExtraConfig5 // (with lib.kernel; { RT_GROUP_SCHED = lib.mkForce (option no); });
 
    } 
    { 
      kernelVersion = "5.15.73"; 
      kernelHash = "sha256-qCLwlSWuiANFOTmpHnPxgJejuirsc75P6asxSgExcV0="; 
      patchVersion = "rt52"; 
      patchHash = "sha256:0jn6rlhl3gj0qfq1b8jz9yjg0lmrygv2n8kg1ck4hp3al8ps141w"; 
      extraConfig = rtExtraConfig5;
    } 
    rec { 
      kernelVersion = "5.19"; 
      kernelModDirVersion = "5.19.0-" + patchVersion;
      kernelHash = "sha256-/yQMV5ue4a/8MYkX3gc5T8HDu0nawl7BKHNwwuFQBag="; 
      patchVersion = "rt10"; 
      patchHash = "sha256:18i5iyig8smb561gb54b1s8xmky2q134smpwci24f4cj6lljcdir"; 
      extraConfig = rtExtraConfig5;
    } 
    {
      kernelVersion = "6.0.5";
      kernelHash = "sha256-YTMu8itTxQwQ+qv7lliWp9GtTzOB8PiWQ8gg8opgQY4=";
      patchVersion = "rt14";
      patchHash = "sha256:01nmzddbg5qm52943xksn8pl2jwh9400x9831apgrl8mv4a4lfm5";
      extraConfig = rtExtraConfig5;
    }
  ];
in
{
  options.rtnix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    kernel.realtime = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    kernel.timerlat = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    kernel.version = lib.mkOption {
      type = lib.types.str;
      default = "6.0";
    };
  }; 

  config = 
    let 
      kernelData = metadata."${rtnix.kernel.version}";
    in
      {
        boot.kernelPatches = [ 
          (lib.mkIf (rtnix.enable && rtnix.kernel.realtime) {
            name = "preempt_rt";
            patch = builtins.fetchurl {
              url = kernelData.patchUrl;
              sha256 = kernelData.patchHash;
            };

            # extraConfig = kernelData.rtExtraConfig;
          })

          (lib.mkIf (rtnix.enable && rtnix.kernel.timerlat) {
            name = "timerlat_tracing";

            patch = null;

            extraConfig = ''
              TIMERLAT_TRACER y
            '';
          })
        ];

        boot.kernelPackages = 
          lib.mkIf (rtnix.enable && (rtnix.kernel.realtime || rtnix.kernel.timerlat))
            # We use the linuxPackage from nixpkgs that shares the kernel version:
            (pkgs.linuxPackagesFor (pkgs."linux_${dotToUnderscore rtnix.kernel.version}".override {
              argsOverride = rec {
                src = pkgs.fetchurl {
                  url = kernelData.kernelUrl;
                  sha256 = kernelData.kernelHash;
                };
                version = kernelData.kernelVersion;
                modDirVersion = kernelData.kernelModDirVersion;
                structuredExtraConfig = kernelData.extraConfig;
              };
            }));
      };
}
