{
  pkgs,
  config,
  lib,
  ...
}: let
  vmName = "activity-ubuntu";
  diskPath = "${config.home.homeDirectory}/VMs/${vmName}.qcow2";

  domainXml = pkgs.writeText "${vmName}.xml" ''
    <domain type='kvm'>
      <name>${vmName}</name>
      <memory unit='GiB'>6</memory>
      <vcpu placement='static'>4</vcpu>
      <os>
        <type arch='x86_64' machine='pc-q35-9.2'>hvm</type>
        <boot dev='hd'/>
      </os>
      <cpu mode='host-passthrough' check='none' migratable='on'/>
      <features>
        <acpi/>
        <apic/>
      </features>
      <clock offset='utc'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <devices>
        <emulator>/usr/bin/qemu-system-x86_64</emulator>
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap'/>
          <source file='${diskPath}'/>
          <target dev='vda' bus='virtio'/>
        </disk>
        <interface type='network'>
          <source network='default'/>
          <model type='virtio'/>
        </interface>
        <graphics type='spice' autoport='yes'>
          <listen type='address' address='127.0.0.1'/>
        </graphics>
        <video>
          <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
        </video>
        <input type='tablet' bus='usb'/>
        <input type='keyboard' bus='ps2'/>
        <channel type='unix'>
          <target type='virtio' name='org.qemu.guest_agent.0'/>
        </channel>
        <memballoon model='virtio'/>
      </devices>
    </domain>
  '';
in {
  home.activation.defineActivityVm = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if command -v virsh &> /dev/null; then
      $DRY_RUN_CMD virsh define ${domainXml} || true
    fi
  '';
}
