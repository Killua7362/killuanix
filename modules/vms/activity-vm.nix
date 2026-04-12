# Work Ubuntu VM — auto-provisioned with Ubuntu 24.04 Server + cloud-init
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  vmName = "work-ubuntu";
  diskPath = "${config.home.homeDirectory}/VMs/${vmName}.qcow2";
  sharedDir = "${config.home.homeDirectory}/Documents/shared";
  sshKeys = inputs.self.commonModules.user.userConfig.sshKeys;
  sshKeysYaml = lib.concatMapStringsSep "\n" (k: "      - ${k}") sshKeys;
  sshKeysFlat = lib.concatStringsSep "\\n" sshKeys;
  # Password hash for 'work123' (generated via: openssl passwd -6 -salt saltsalt work123)
  passwordHash = "$6$saltsalt$UOADXqK5Ga0joxzEtYtGDIbCoNQW7mObI83DF7jYmIkK2YwkLVw88JM/YylNjgz58VZlkb3pCgP0PcWeZeTUv1";

  # Ubuntu 24.04.2 Server ISO — repacked to add 'autoinstall' kernel param (skips confirmation prompt)
  ubuntuIsoOriginal = pkgs.fetchurl {
    url = "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso";
    sha256 = "sha256-1tqww6ZXmIUBtL128Sl8BT33EOBuDDrs5g3q0k8nC00=";
  };

  ubuntuIso =
    pkgs.runCommand "ubuntu-24.04.2-autoinstall.iso" {
      nativeBuildInputs = [pkgs.xorriso];
    } ''
      # Extract grub.cfg, patch it, and repack in-place
      cp ${ubuntuIsoOriginal} work.iso
      chmod +w work.iso

      # Extract grub.cfg
      xorriso -indev work.iso -osirrox on -extract /boot/grub/grub.cfg grub.cfg 2>/dev/null

      # Add 'autoinstall' before '---' on linux lines
      sed -i 's|---|autoinstall ---|g' grub.cfg

      # Also set timeout to 1 second so it boots the default entry quickly
      sed -i 's/set timeout=.*/set timeout=1/' grub.cfg

      # Write patched grub.cfg back into the ISO
      xorriso -indev work.iso -outdev "$out" -map grub.cfg /boot/grub/grub.cfg -boot_image any replay
    '';

  # Cloud-init user-data with autoinstall
  # Built via runCommand to avoid Nix ''string $-escaping issues with password hash
  userData = pkgs.runCommand "user-data" {} ''
    cat > $out << 'USERDATA'
    #cloud-config
    autoinstall:
      version: 1
      locale: en_US.UTF-8
      keyboard:
        layout: us
      identity:
        hostname: work-ubuntu
        username: user
        password: "${passwordHash}"
      ssh:
        install-server: true
        allow-pw: true
      packages:
        - openssh-server
        - qemu-guest-agent
        - xdotool
        - spice-vdagent
      late-commands:
        - "curtin in-target -- systemctl enable ssh"
        - "curtin in-target -- systemctl enable qemu-guest-agent"
        - "curtin in-target -- mkdir -p /home/user/.ssh"
        - "curtin in-target -- chmod 700 /home/user/.ssh"
        - "printf '${sshKeysFlat}\n' | curtin in-target -- tee /home/user/.ssh/authorized_keys"
        - "curtin in-target -- chmod 600 /home/user/.ssh/authorized_keys"
        - "curtin in-target -- chown -R 1000:1000 /home/user/.ssh"
        - "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /target/etc/ssh/sshd_config"
      network:
        network:
          version: 2
          ethernets:
            all:
              match:
                name: "en*"
              dhcp4: false
              addresses:
                - 192.168.122.100/24
              routes:
                - to: default
                  via: 192.168.122.1
              nameservers:
                addresses:
                  - 1.1.1.1
                  - 8.8.8.8
    USERDATA
  '';

  metaData = pkgs.writeText "meta-data" ''
    instance-id: work-ubuntu-001
    local-hostname: work-ubuntu
  '';

  # Cloud-init seed ISO
  # Volume label "CIDATA" is required for cloud-init detection
  seedIso =
    pkgs.runCommand "seed.iso" {
      nativeBuildInputs = [pkgs.cdrkit];
    } ''
      mkdir -p cidata
      cp ${userData} cidata/user-data
      cp ${metaData} cidata/meta-data
      # Vendor-data with autoinstall marker suppresses the "Continue with autoinstall?" prompt
      echo -e '#cloud-config\nautoinstall:\n  version: 1' > cidata/vendor-data
      genisoimage -output $out -volid CIDATA -joliet -rock cidata/
    '';

  domainXml = pkgs.writeText "${vmName}.xml" ''
    <domain type='kvm'>
      <name>${vmName}</name>
      <memory unit='GiB'>6</memory>
      <vcpu placement='static'>4</vcpu>
      <memoryBacking>
        <source type='memfd'/>
        <access mode='shared'/>
      </memoryBacking>
      <os>
        <type arch='x86_64' machine='q35'>hvm</type>
        <boot dev='hd'/>
        <boot dev='cdrom'/>
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
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${ubuntuIso}'/>
          <target dev='sda' bus='sata'/>
          <readonly/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${seedIso}'/>
          <target dev='sdb' bus='sata'/>
          <readonly/>
        </disk>
        <interface type='network'>
          <source network='default'/>
          <model type='virtio'/>
        </interface>
        <filesystem type='mount' accessmode='passthrough'>
          <driver type='virtiofs'/>
          <source dir='${sharedDir}'/>
          <target dir='host-shared'/>
        </filesystem>
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
  home.activation.defineWorkVm = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Ensure directories exist
    mkdir -p "$HOME/VMs"
    mkdir -p "${sharedDir}"

    # Create disk if not exists
    if [ ! -f "${diskPath}" ]; then
      ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${diskPath}" 40G
    fi

    # Define/update the VM (use full path — virsh may not be in PATH during activation)
    # Try define first (works for new VMs and updates existing ones with same UUID)
    # Only undefine+redefine if plain define fails (UUID mismatch)
    if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system define ${domainXml} 2>/dev/null; then
      ${pkgs.libvirt}/bin/virsh -c qemu:///system undefine ${vmName} 2>/dev/null || true
      ${pkgs.libvirt}/bin/virsh -c qemu:///system define ${domainXml} || true
    fi
  '';
}
