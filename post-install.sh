## añadir usuario a sudo
usermod -aG sudo,dialout,video,tty,plugdev $USER
reboot

## Driver Sound Blaster Z
# Descargar .bin de https://mega.nz/file/hcQVDDJL#B3QkvwyUkHSDwN-7C9tKndipYyuGQioQMO64oyvCEEU
sudo cp -rf ctefx-desktop.bin /usr/lib/firmware/

pactl list cards short
# $ pactl list cards short
# 50      alsa_card.pci-0000_06_00.0      alsa
# 51      alsa_card.pci-0000_0d_00.1      alsa
# 52      alsa_card.usb-Apple__Inc._EarPods_L24GG2R127-00 alsa
# $ pactl list cards short | awk '$1 == 50 {print $2}'

mkdir -p ~/.config/pipewire/pipewire.conf.d
tee ~/.config/pipewire/pipewire.conf.d/90-clock-rate.conf > /dev/null <<'EOF'
context.properties = {
    default.clock.rate          = 192000
    default.clock.allowed-rates = [ 44100 48000 96000 192000 ]
}
EOF

mkdir -p ~/.config/wireplumber/wireplumber.conf.d
tee ~/.config/wireplumber/wireplumber.conf.d/60-soundblaster-192khz.conf > /dev/null <<'EOF'
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "alsa_card.pci-0000_06_00.0"
      }
    ]
    actions = {
      update-props = {
        audio.format = "S32LE"
        audio.rate = 192000
        audio.channels = 2
        api.alsa.period-size = 1024
        api.alsa.headroom = 0
        session.suspend-timeout-seconds = 0
      }
    }
  }
]
EOF

## Instalar vim
sudo apt update && sudo apt install -y vim

## Repositorios
sudo tee /etc/apt/sources.list > /dev/null <<'EOF'
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
EOF

sudo tee /etc/apt/sources.list.d/debian-backports.sources > /dev/null <<'EOF'
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

## Añadir llaves
wget https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb
sudo dpkg -i deb-multimedia-keyring_2024.9.1_all.deb

sudo tee /etc/apt/sources.list.d/debian-multimedia.sources > /dev/null <<'EOF'
Types: deb deb-src
URIs: https://www.deb-multimedia.org
Suites: trixie
Components: main non-free
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
EOF

sudo tee /etc/apt/preferences.d/debian-multimedia.pref > /dev/null <<'EOF'
Package: *
Pin: origin "www.deb-multimedia.org"
Pin-Priority: 50
EOF

## Actualizar repositorios
sudo apt update && sudo apt upgrade -y

## Añadir a GRUB /etc/default/grub
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet amdgpu.ppfeaturemask=0xffffffff zswap.enabled=1 zswap.compressor=lzo"|' /etc/default/grub
sudo update-grub

## Establecer SepaceFun theme
sudo update-alternatives --set desktop-theme /usr/share/desktop-base/spacefun-theme
sudo dpkg-reconfigure desktop-base

## crear swap
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

## añadir al /etc/fstab, verificar /dev/nvme1n1pX
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme1n1p3)
BOOT_UUID=$(blkid -s UUID -o value /dev/nvme1n1p1)
EFI_UUID=$(blkid -s UUID -o value /dev/nvme1n1p2)
HOME_UUID=$(blkid -s UUID -o value /dev/nvme1n1p4)

sudo cp /etc/fstab /etc/fstab.bak.$(date +%F-%T) && sudo tee /etc/fstab > /dev/null <<EOF
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# Linux, /
UUID=$ROOT_UUID       /               ext4    defaults,noatime,errors=remount-ro      0       1

# /boot
UUID=$BOOT_UUID       /boot           ext4    defaults        0       2

# /boot/efi
UUID=$EFI_UUID                                  /boot/efi       vfat    umask=0077      0       1

# Home, /home
UUID=$HOME_UUID	                                /home	ext4	    defaults,noatime	      0	      2

# /opt/games
UUID=4c9404ef-18de-4718-ac93-65b17156271d       /opt/games      ext4    defaults,noatime        0       2

# swap
UUID=b589268d-9b53-438d-a2c5-7b414744cb7b       none            swap    sw              0       0

# cd-rom
/dev/sr0                                        /media/cdrom0   udf,iso9660 user,noauto 0       0

# NFS
$IP_NAS:/volume1/folder                         /mnt/nas/folder	nfs	rw,vers=4,noatime,hard,x-systemd.automount,x-systemd.idle-timeout=300,_netdev	0	0
EOF

## Añadir blacklist
sudo tee /etc/modprobe.d/blacklist-gpu.conf  > /dev/null <<'EOF'
# Blacklist de controladores gráficos que no se usan

# NVIDIA proprietary drivers
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm

# NVIDIA legacy / framebuffer
blacklist rivafb
blacklist rivatv
blacklist nvidiafb

# Driver libre de NVIDIA (nouveau)
blacklist nouveau
options nouveau modeset=0

# Intel GPU drivers
blacklist i915
blacklist intel_agp
blacklist intel_gtt
EOF

sudo tee /etc/modprobe.d/amdgpu.conf  > /dev/null <<'EOF'
options amdgpu si_support=1 cik_support=0
options amdgpu dc=1
EOF

## microcode
sudo rm -rf /etc/modprobe.d/amd64-microcode-blacklist.conf
sudo rm -rf /etc/modprobe.d/intel-microcode-blacklist.conf

## Deshabilitar modulos KVM
sudo tee /etc/modprobe.d/blacklist-kvm.conf > /dev/null <<'EOF'
blacklist kvm
blacklist kvm_amd
EOF

## Crear sysctl.conf en /etc/sysctl.d/99-custom.conf
sudo tee /etc/sysctl.d/99-custom.conf > /dev/null <<'EOF'
# VM settings
vm.max_map_count = 2147483642
vm.swappiness = 10
fs.file-max = 2097152

# Networking - Buffers and performance for solid gigabit link
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr

# Increase queue size to prevent packet loss during spikes
net.core.default_qdisc = fq
net.core.netdev_max_backlog = 8192
net.core.somaxconn = 1024

# TCP tweaks to reduce TIME_WAIT and improve reuse
net.ipv4.tcp_max_tw_buckets = 200000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Local port range for ephemeral connections
net.ipv4.ip_local_port_range = 1024 65535

# Kernel panic after 60 seconds
kernel.panic = 60
EOF

## Soporte GPU AMD
sudo tee /etc/environment.d/90-amdgpu.conf > /dev/null <<'EOF'
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
EOF

## Rules /etc/udev/rules.d/
sudo tee /etc/udev/rules.d/10-eyetoy.rules > /dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="0x054c", ATTR{idProduct}=="0x0155", MODE="0660", GROUP="plugdev"
EOF

sudo tee /etc/udev/rules.d/20-ledger.rules > /dev/null <<'EOF'
# HW.1, Nano
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c|2b7c|3b7c|4b7c", TAG+="uaccess", TAG+="udev-acl"

# Blue, NanoS, Aramis, HW.2, Nano X, NanoSP, Stax, Ledger Test,
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", TAG+="uaccess", TAG+="udev-acl"

# Same, but with hidraw-based library (instead of libusb)
KERNEL=="hidraw*", ATTRS{idVendor}=="2c97", MODE="0666"
EOF

sudo tee /etc/udev/rules.d/50-power-save.rules > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="max_performance"
EOF

sudo tee /etc/udev/rules.d/51-android.rules > /dev/null <<'EOF'
## OnePlus 8T
SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", ATTR{idProduct}=="2769", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="d00d", MODE="0666", GROUP="plugdev"
EOF

sudo tee /etc/udev/rules.d/60-arduino.rules > /dev/null <<'EOF'
# ------------------------------------------------------------
# Arduino UNO Q
# ------------------------------------------------------------
# Operating mode
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0078", \
  MODE="0666", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", \
  ENV{ID_MM_CANDIDATE}="0"

# EDL mode
SUBSYSTEMS=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", \
  MODE="0666", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", \
  ENV{ID_MM_CANDIDATE}="0"

# ------------------------------------------------------------
# Arduino GIGA R1 WiFi (CDC ACM)
# ------------------------------------------------------------
SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0266", \
  MODE="0666", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", \
  ENV{ID_MM_CANDIDATE}="0"

SUBSYSTEM=="usb", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0366", \
  MODE="0666", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", \
  ENV{ID_MM_CANDIDATE}="0"

# ------------------------------------------------------------
# STM32 DFU (GIGA / STM32H7)
# ------------------------------------------------------------
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", \
  MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"

# ------------------------------------------------------------
# Arduino UNO
# ------------------------------------------------------------
SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0043", \
  MODE="0666", GROUP="dialout", TAG+="uaccess"

# ------------------------------------------------------------
# CH340
# ------------------------------------------------------------
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", \
  MODE="0666", GROUP="dialout", TAG+="uaccess"
EOF

sudo tee /etc/udev/rules.d/70-yubikey.rules > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0407", MODE="0666"
EOF

sudo tee /etc/udev/rules.d/80-ps3-memcard.rules > /dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="02ea", MODE="0666", GROUP="plugdev"
EOF

sudo tee /etc/udev/rules.d/90-xgecu-t48.rules > /dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="a466", ATTR{idProduct}=="0a53", MODE="0666", GROUP="plugdev"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

## Fichero hosts
sudo tee /etc/hosts > /dev/null <<'EOF'
127.0.0.1	localhost
127.0.1.1	localhost	debian

## Local
xxx.xxx.xxx.xxx
xxx.xxx.xxx.xxx
xxx.xxx.xxx.xxx
xxx.xxx.xxx.xxx
xxx.xxx.xxx.xxx

## DNS Cloudflare
1.1.1.1		one.one.one.one
1.0.0.1
1.1.1.2		security.cloudflare-dns.com
1.0.0.2
1.1.1.3		family.cloudflare-dns.com
1.0.0.3
2606:4700:4700::1111
2606:4700:4700::1001
2606:4700:4700::1112
2606:4700:4700::1002
2606:4700:4700::1113
2606:4700:4700::1003

## NTP
time.cloudflare.com	162.159.200.1
time.google.com		216.239.35.8

## IPv6
# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

## Disable offloads
device="enp5s0"
sudo tee /etc/systemd/system/offloads-${device}.service > /dev/null <<'EOF'"$service-file" <<EOF
[Unit]
Description=Disable GRO/GSO/TSO/LRO on ${device}
Wants=sys-subsystem-net-devices-${device}.device
After=sys-subsystem-net-devices-${device}.device

[Service]
Type=oneshot
ExecStartPre=/usr/bin/bash -c 'until ip link show ${device}; do sleep 1; done'
ExecStart=/usr/bin/ethtool -K ${device} gro off gso off tso off lro off sg off tx-gso-partial off
RemainAfterExit=yes

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "offloads-${device}.service"
systemctl start "offloads-${device}.service"
systemctl status "offloads-${device}.service" --no-pager

## Actualizar repositorios y sistema
sudo apt update && sudo apt upgrade -y

## Instalar paquetes
sudo apt install -y build-essential cmake pkg-config dkms linux-headers-$(uname -r) bc bison flex rsync \
    libelf-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev libxml2-dev \
    libxmlsec1-dev libffi-dev liblzma-dev libssl-dev tk-dev

sudo apt install -y python3 python3-pip python3-pil python3-psutil \
    libglib2.0-dev-bin gjs dexdump

sudo apt install -y amd64-microcode firmware-amd-graphics firmware-iwlwifi firmware-linux \
    firmware-linux-free firmware-linux-nonfree firmware-misc-nonfree firmware-realtek util-linux ethtool

sudo apt install -y nfs-common samba cifs-utils sshfs net-tools iperf3 libiperf0 nmap \
    lm-sensors htop bpytop v4l-utils

sudo apt install -y libfuse2 sysfsutils
sudo apt install -y cryptsetup lvm2 tpm2-tools gdisk
sudo apt install -y dfu-util dfu-programmer avrdude
sudo apt install -y ca-certificates curl wget dirmngr gnupg openssl
sudo apt install -y sudo jq xz-utils inxi qrencode
sudo apt install -y libgbm1 libgjs0g bluez bluez-tools pipewire-audio-client-libraries blueman
sudo apt install -y ttf-mscorefonts-installer
sudo apt install -y duf nvme-cli gparted smartmontools
sudo apt install -y code

sudo apt install -y vulkan-tools gamemode vulkan-validationlayers \
    mesa-utils mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers mesa-opencl-icd \
    libgl1-mesa-dri libglapi-mesa libglx-mesa0 libegl-mesa0 libxatracker2 vainfo

sudo apt install -y h264enc libx264-165 libx264-dev libx265-215 libx265-dev \
    lame ffmpeg flac vlc libbdplus0 libaacs0 libaacs-dev libbluray2

sudo apt install -y libdvd-pkg libdvdread8 libdvdcss-dev libdvdcss2 \
    dvd+rw-tools brasero cdrdao dvdauthor dvdbackup

sudo apt install -y meld filezilla keepassxc gimp gimp-help-es gimp-data-extras transmission fastfetch
sudo apt install -y pcscd pcsc-tools libpam-u2f pamu2fcfg yubico-piv-tool yubikey-manager

## Instalar Google Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt -f install -y

## Instalar software mediante backports
# sudo apt install -t trixie-backports <paquete>
# example: sudo apt install -t trixie-backports -y ffmpeg

# Backports recomendado:
# sudo apt install -t trixie-backports -y \
#     mesa-va-drivers \
#     mesa-vdpau-drivers \
#     mesa-vulkan-drivers \
#     mesa-opencl-icd \
#     libgl1-mesa-dri \
#     libglapi-mesa \
#     libglx-mesa0 \
#     libegl-mesa0 \
#     libxatracker2

## Configurar libdvd-pkg DVD
dpkg-reconfigure libdvd-pkg

## Configurar sensores
sudo sensors-detect --auto
echo "k10temp" | sudo tee /etc/modules-load.d/k10temp.conf > /dev/null

## Instalar Java JDK
wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz
sudo mkdir -p /usr/lib/jvm
sudo tar -xvf jdk-21_linux-x64_bin.tar.gz -C /usr/lib/jvm/
JDK_DIR=$(tar -tf jdk-21_linux-x64_bin.tar.gz | head -1 | cut -f1 -d"/")
sudo ln -sfn /usr/lib/jvm/$JDK_DIR /usr/lib/jvm/default-java
update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/default-java/bin/java" 1
update-alternatives --install "/usr/bin/javac" "javac" "/usr/lib/jvm/default-java/bin/javac" 1
update-alternatives --install "/usr/bin/jar" "jar" "/usr/lib/jvm/default-java/bin/jar" 1
update-ca-certificates -f

## Instalar Flatpak
sudo apt install flatpak -y
sudo apt install gnome-software-plugin-flatpak
sudo -u $USER flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

## Opcional
clone https://gitlab.com/leogx9r/ryzen_smu.git
cd ryzen_smu/
sudo make dkms-install
echo "ryzen_smu" | sudo tee /etc/modules-load.d/ryzen_smu.conf > /dev/null

## Firefox con soporte VA-API
sudo tee /usr/share/applications/firefox.desktop > /dev/null <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Exec=env MOZ_WAYLAND_DRM_DEVICE=/dev/dri/renderD128 LIBVA_DRIVER_NAME=radeonsi MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox/firefox %u
Terminal=false
X-MultipleArgs=false
Icon=firefox
StartupWMClass=firefox
Categories=GNOME;GTK;Network;WebBrowser;
MimeType=application/json;application/pdf;application/rdf+xml;application/rss+xml;application/x-xpinstall;application/xhtml+xml;application/xml;audio/flac;audio/ogg;audio/webm;image/avif;image/gif;image/jpeg;image/png;image/svg+xml;image/webp;text/html;text/xml;video/ogg;video/webm;x-scheme-handler/chrome;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/mailto;
StartupNotify=true
Actions=new-window;new-private-window;open-profile-manager;

Name=Firefox
Name[en_GB]=Firefox
Name[es_ES]=Firefox

Comment=Fast and private browser
Comment[en_GB]=Fast and private browser
Comment[es_ES]=Navegador rápido y privado

GenericName=Web Browser
GenericName[en_GB]=Web Browser
GenericName[es_ES]=Navegador web

Keywords=Internet;WWW;Browser;Web;Explorer;
Keywords[en_GB]=Internet;WWW;Browser;Web;Explorer;
Keywords[es_ES]=Internet;WWW;Navegador;Web;Explorador;

X-GNOME-FullName=Mozilla Firefox
X-GNOME-FullName[en_GB]=Mozilla Firefox
X-GNOME-FullName[es_ES]=Mozilla Firefox

[Desktop Action new-window]
Exec=env MOZ_WAYLAND_DRM_DEVICE=/dev/dri/renderD128 LIBVA_DRIVER_NAME=radeonsi MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox/firefox --new-window %u
Name=Open a New Window
Name[en_GB]=Open a New Window
Name[es_ES]=Abrir en nueva ventana

[Desktop Action new-private-window]
Exec=env MOZ_WAYLAND_DRM_DEVICE=/dev/dri/renderD128 LIBVA_DRIVER_NAME=radeonsi MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox/firefox --private-window %u
Name=Open New Private Window
Name[en_GB]=Open New Private Window
Name[es_ES]=Abrir en nueva ventana privada

[Desktop Action open-profile-manager]
Exec=env MOZ_WAYLAND_DRM_DEVICE=/dev/dri/renderD128 LIBVA_DRIVER_NAME=radeonsi MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox/firefox --ProfileManager
Name=Open Profile Manager
Name[en_GB]=Open Profile Manager
Name[es_ES]=Abrir administrador de perfiles
EOF

sudo tee /usr/share/applications/com.google.Chrome.desktop > /dev/null <<'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome

GenericName=Web Browser
GenericName[en]=Web Browser
GenericName[es]=Navegador web

Comment=Access the Internet
Comment[en]=Access the Internet
Comment[es]=Accede a Internet

Exec=/usr/bin/google-chrome-stable \
--ozone-platform=wayland \
--enable-features=UseOzonePlatform,VaapiVideoDecoder \
--ignore-gpu-blocklist \
--enable-gpu-rasterization \
--enable-threaded-scrolling \
--enable-zero-copy \
--enable-accelerated-video-decode \
--disable-features=Vulkan,VulkanFromANGLE \
--disable-background-timer-throttling \
--disable-renderer-backgrounding \
--disable-backgrounding-occluded-windows \
--js-flags="--max-old-space-size=4096"

StartupNotify=true
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/xhtml+xml;application/xml;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/google-chrome;
Actions=new-window;new-private-window;
NoDisplay=false

[Desktop Action new-window]
Name=New Window
Name[en]=New Window
Name[es]=Nueva ventana
Exec=/usr/bin/google-chrome-stable \
--ozone-platform=wayland \
--enable-features=UseOzonePlatform,VaapiVideoDecoder \
--ignore-gpu-blocklist \
--enable-gpu-rasterization \
--enable-threaded-scrolling \
--enable-zero-copy \
--enable-accelerated-video-decode \
--disable-features=Vulkan,VulkanFromANGLE \
--js-flags="--max-old-space-size=4096"

[Desktop Action new-private-window]
Name=New Incognito Window
Name[en]=New Incognito Window
Name[es]=Nueva ventana de incógnito
Exec=/usr/bin/google-chrome-stable \
--incognito \
--ozone-platform=wayland \
--enable-features=UseOzonePlatform,VaapiVideoDecoder \
--ignore-gpu-blocklist \
--enable-gpu-rasterization \
--enable-threaded-scrolling \
--disable-features=Vulkan,VulkanFromANGLE \
--js-flags="--max-old-space-size=4096"
EOF

sudo tee /usr/share/applications/antigravity.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Antigravity
Comment=Google Antigravity
Exec=/usr/share/antigravity/antigravity %F
Icon=${HOME}/.antigravity/google-antigravity.png
Type=Application
StartupNotify=false
StartupWMClass=Antigravity
Categories=Development;Utility;
MimeType=application/x-antigravity-workspace;
Actions=new-empty-window;
Keywords=vscode;

[Desktop Action new-empty-window]
Name=New Empty Window
Name[es]=Nueva ventana vacía
Exec=/usr/share/antigravity/antigravity --new-window %F
Icon=${HOME}/.antigravity/google-antigravity.png
EOF

## CoreCtrl
sudo apt install -y corectrl
sudo tee /etc/polkit-1/rules.d/90-corectrl.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helperkiller.init") &&
        subject.local == true &&
        subject.active == true &&
        subject.isInGroup("$USER")) {
            return polkit.Result.YES;
    }
})
EOF

## Instalar VirtualBox
wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
sudo tee /etc/apt/sources.list.d/virtualbox-oracle.list > /dev/null <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib non-free
EOF
sudo apt update && sudo apt install -y virtualbox-7.2
wget https://download.virtualbox.org/virtualbox/7.2.0/Oracle_VirtualBox_Extension_Pack-7.2.0.vbox-extpack
sudo VBoxManage extpack install --replace Oracle_VirtualBox_Extension_Pack-7.2.0.vbox-extpack --accept-license=eb31505e56e9b4d0fbca139104da41ac6f6b98f8e78968bdf01b1f3da3c4f9ae
VBoxManage list extpacks
sudo usermod -aG vboxusers $USER

## Instalar Spotify
curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null <<'EOF'
deb https://repository.spotify.com stable non-free
EOF
sudo apt update
sudo apt install -y spotify-client

## Instalar binario repo, Android AOSP
curl https://storage.googleapis.com/git-repo-downloads/repo > repo && chmod a+x repo && sudo mv repo /usr/local/bin/repo

## Instalar Wireshark
sudo apt install -y wireshark
sudo addgroup -quiet -system wireshark
sudo chown root:wireshark /usr/bin/dumpcap
sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
sudo usermod -aG wireshark $USER
sudo dpkg-reconfigure wireshark-common

## Instalar Firefox y Thunderbird
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null <<'EOF'
deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main
EOF
sudo tee /etc/apt/preferences.d/mozilla > /dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
sudo apt update && sudo apt install -y firefox thunderbird firefox-l10n-es-es thunderbird-l10n-es-es

## Configuracion Gnome
sudo -u $USER gsettings set org.gnome.desktop.interface clock-show-weekday true
sudo -u $USER gsettings set org.gnome.desktop.interface clock-format '24h'
sudo -u $USER gsettings set org.gnome.desktop.interface enable-hot-corners true
sudo -u $USER gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'
sudo -u $USER gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
sudo -u $USER gsettings set org.gnome.desktop.peripherals.mouse speed 0.5
sudo -u $USER gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
sudo -u $USER gsettings set org.gnome.desktop.session idle-delay 900
sudo -u $USER gsettings set org.gnome.mutter center-new-windows true

## Verificar
#!/bin/bash

echo -e "\n========== GPU =========="
inxi -G

echo -e "\n========== VA-API / ACELERACIÓN DE VÍDEO =========="
if command -v vainfo >/dev/null 2>&1; then
    vainfo 2>/dev/null | grep -E 'Driver version|VAProfile' || \
        echo "No se pudo obtener información de VA-API"
else
    echo "vainfo no está instalado"
fi

echo -e "\n========== VULKAN =========="
if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo 2>/dev/null |
        grep -E 'GPU id|deviceName|driverVersion' |
        head -n 15
else
    echo "vulkaninfo no está instalado"
fi

echo -e "\n========== FFMPEG / ACELERACIÓN HARDWARE =========="
if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -hide_banner -hwaccels
else
    echo "ffmpeg no está instalado"
fi

echo -e "\n========== MICROCODE =========="

# El microcode NO es un módulo.
if grep -q '^CONFIG_MICROCODE=y' /boot/config-"$(uname -r)" 2>/dev/null; then
    echo "Soporte de microcode en kernel: integrado ✅"
else
    echo "Soporte de microcode en kernel: no encontrado ⚠"
fi

MICROCODE=$(grep -m1 'microcode' /proc/cpuinfo | awk '{print $3}')

if [ -n "$MICROCODE" ]; then
    echo "Microcode CPU: $MICROCODE ✅"
else
    echo "Microcode CPU: no detectado ❌"
fi

if dmesg 2>/dev/null | grep -qi 'microcode'; then
    dmesg 2>/dev/null | grep -i 'microcode' | tail -n 3
else
    echo "No se encontró información de microcode en dmesg"
fi

echo -e "\n========== MÓDULOS CPU =========="

for module in k10temp ryzen_smu; do
    if lsmod | grep -q "^${module}[[:space:]]"; then
        echo "Módulo $module: cargado ✅"
    else
        echo "Módulo $module: NO cargado ⚠"
    fi
done

echo -e "\n========== WI-FI / BLUETOOTH =========="

check_rfkill() {
    local type="$1"
    local name="$2"

    if ! command -v rfkill >/dev/null 2>&1; then
        echo "rfkill no está instalado"
        return
    fi

    local blocked
    blocked=$(rfkill list "$type" 2>/dev/null |
        grep -i "Soft blocked" |
        awk '{print $3}' |
        head -n 1)

    if [ "$blocked" = "no" ]; then
        echo "$name: activo 🟢"
    elif [ "$blocked" = "yes" ]; then
        echo "$name: Soft blocked ⚠"
    else
        echo "$name: estado no detectado"
    fi
}

for module in iwlwifi btusb; do
    if lsmod | grep -q "^${module}[[:space:]]"; then
        echo "Módulo $module: cargado ✅"
    else
        echo "Módulo $module: NO cargado ⚠"
    fi
done

check_rfkill wifi "Wi-Fi"
check_rfkill bluetooth "Bluetooth"

echo -e "\n========== FIN =========="

## Limpiar y reiniciar
sudo apt clean
sudo apt autoremove --purge -y
rm -rf ~/.cache/thumbnails/*
sudo systemd-tmpfiles --clean
sync
sudo reboot
