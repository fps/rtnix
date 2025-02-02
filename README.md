Take a look at the [source](default.nix)

# Example usage

Check this repository out relative to your `configuration.nix`, add `./rtnix` to your `imports` and then add some configuration to your `configuration.nix`. For example:

```
rtnix.kernel.realtime.enable = true;
rtnix.tuningProcesses = [ "irq/.*xhci" "irq/.*snd_intel_hda" ];
```

This should accomplish:

1. Rebuild your kernel with `PREEMPT_RT` enabled
2. Setup the processes matching the pattern `"irq/.*xhci"` to have `SCHED_FIFO` at priority 90
3. Setup the processes matching the patterh `"irq/.*snd_intel_hda"` to have `SCHED_FIFO` at priority 89
4. Setup the `PAM` limits to allow users belonging to the `realtime` group to do all kind of funky things

