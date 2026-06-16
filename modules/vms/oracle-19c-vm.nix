# Oracle Database 19c VM — libvirt domain backed by a qcow2 imported from the
# upstream Oracle 19c vagrant OVA. The OVA → qcow2 conversion is a one-shot
# performed by scripts/oracle-vm-import.sh; this module only defines the
# libvirt domain so virt-manager / virsh can manage it.
{
  pkgs,
  config,
  lib,
  ...
}: let
  vmName = "oracle-19c";
  diskPath = "${config.home.homeDirectory}/VMs/${vmName}.qcow2";

  domainXml = pkgs.writeText "${vmName}.xml" ''
    <domain type='kvm'>
      <name>${vmName}</name>
      <uuid>c0a8e1b2-19c0-4adb-9ec1-19c1a9ec19c0</uuid>
      <memory unit='GiB'>8</memory>
      <vcpu placement='static'>2</vcpu>
      <os>
        <type arch='x86_64' machine='q35'>hvm</type>
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
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap' io='native' cache='none'/>
          <source file='${diskPath}'/>
          <target dev='vda' bus='virtio'/>
        </disk>
        <interface type='network'>
          <source network='default'/>
          <model type='virtio'/>
        </interface>
        <graphics type='spice'>
          <listen type='none'/>
          <gl enable='yes'/>
          <streaming mode='all'/>
          <image compression='auto_glz'/>
        </graphics>
        <video>
          <model type='virtio' heads='1' primary='yes'>
            <acceleration accel3d='yes'/>
          </model>
        </video>
        <channel type='spicevmc'>
          <target type='virtio' name='com.redhat.spice.0'/>
        </channel>
        <input type='tablet' bus='usb'/>
        <input type='keyboard' bus='ps2'/>
        <channel type='unix'>
          <target type='virtio' name='org.qemu.guest_agent.0'/>
        </channel>
        <sound model='ich9'>
          <audio id='1'/>
        </sound>
        <audio id='1' type='spice'/>
        <memballoon model='virtio'/>
      </devices>
    </domain>
  '';
in {
  home.activation.defineOracle19cVm = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Same /dev/kvm guard as activity-vm: keep the activation safe on hosts
    # where KVM isn't available (no `exit` — HM concatenates activations).
    if [ -e /dev/kvm ]; then
      mkdir -p "$HOME/VMs"

      _xml_marker="$HOME/.vm-${vmName}-xml"
      if [ "$(cat "$_xml_marker" 2>/dev/null)" != "${domainXml}" ]; then
        ${pkgs.libvirt}/bin/virsh -c qemu:///system undefine ${vmName} &>/dev/null || true
        ${pkgs.libvirt}/bin/virsh -c qemu:///system define ${domainXml} &>/dev/null || true
        echo "${domainXml}" > "$_xml_marker"
      fi
    fi
  '';
}
