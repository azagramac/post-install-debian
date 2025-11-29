## añadir usuario a sudo
usermod -aG sudo,dialout,video,tty,plugdev $USER

## Driver Sound Blaster Z
# Descargar .bin de https://mega.nz/file/hcQVDDJL#B3QkvwyUkHSDwN-7C9tKndipYyuGQioQMO64oyvCEEU
sudo cp -rf ctefx-desktop.bin /usr/lib/firmware/

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
Suites: deb-multimedia
Components: trixie main non-free
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
EOF

## Actualizar repositorios
sudo apt update && sudo apt upgrade -y

## Añadir a GRUB /etc/default/grub
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet amdgpu.ppfeaturemask=0xffffffff amd_pstate=passive zswap.enabled=1"|' /etc/default/grub
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
UUID=$ROOT_UUID	/	ext4	relatime,errors=remount-ro	0	1

# swap, /swapfile
/swapfile	none	swap	sw	0	0

# boot, /boot
UUID=$BOOT_UUID	/boot	ext4	relatime	0	2

# EFI, /boot/efi
UUID=$EFI_UUID	/boot/efi	vfat	umask=0077	0	1

# Home, /home
UUID=$HOME_UUID	/home	ext4	relatime	0	2

# NFS
$IP_NAS:/volume1/folder    /mnt/nas/folder	nfs	rw,vers=4,noatime,hard,x-systemd.automount,x-systemd.idle-timeout=300,_netdev	0	0
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

## microcode
sudo sed -i 's/^blacklist microcode/#blacklist microcode/' /etc/modprobe.d/amd64-microcode-blacklist.conf
sudo sed -i 's/^blacklist microcode/#blacklist microcode/' /etc/modprobe.d/intel-microcode-blacklist.conf

## Crear sysctl.conf en /etc/sysctl.d/custom-kernel.conf
sudo tee /etc/sysctl.d/custom-kernel.conf > /dev/null <<'EOF'
# VM settings
vm.max_map_count = 2147483642
vm.swappiness = 10
fs.file-max = 100000

# Networking - Buffers y rendimiento para enlace gigabit sólido
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432

# Incrementar tamaño de cola para evitar pérdida en picos
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 1024

# TCP tweaks para reducir TIME_WAIT y mejorar reutilización
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# Rango de puertos locales para conexiones efímeras
net.ipv4.ip_local_port_range = 1024 65535

# Kernel panic después de 30 segundos
kernel.panic = 30
EOF

## Rules /etc/udev/rules.d/
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
# These rules refer: https://developer.android.com/studio/run/device.html
# and include many suggestions from Arch Linux, GitHub and other Communities.
# Latest version can be found at: https://github.com/M0Rf30/android-udev-rules

# check the syntax of this file using:
#  grep -v ^# 51-android.rules \
#    | grep -Ev ^ \
#    | grep -Ev ^SUBSYSTEM==usb, ATTR{idVendor}==[0-9a-f]{4}, ATTR{idProduct}==[0-9a-f]{4}, ENV{adb_user}=yes \
#    | grep -Ev ^SUBSYSTEM==usb, ATTR{idVendor}==[0-9a-f]{4}, ENV{adb_user}=yes

# Skip this section below if this device is not connected by USB
SUBSYSTEM!="usb", GOTO="android_usb_rules_end"

## OnePlus 8T
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="d00d", MODE="0666", GROUP="plugdev"

LABEL="android_usb_rules_begin"

## Google
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ENV{adb_user}="yes"
SUBSYSTEM=="usb", ATTR{idVendor}=="04da", ENV{adb_user}="yes"

## Qualcomm
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="6769", ENV{adb_user}="yes"
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="9025", ENV{adb_user}="yes"

# Enable device as a user device if found
ENV{adb_user}=="yes", MODE="0660", GROUP="plugdev", TAG+="uaccess"

LABEL="android_usb_rules_end"
EOF

sudo tee /etc/udev/rules.d/60-arduino.rules > /dev/null <<'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", MODE:="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

## Fichero hosts
sudo tee /etc/hosts > /dev/null <<'EOF'
127.0.0.1	localhost
127.0.1.1	debian.local	debian

## Local


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

## Actualizar repositorios y sistema
sudo apt update && sudo apt upgrade -y

## Instalar paquetes
sudo apt install -y build-essential git dkms make cmake linux-headers-$(uname -r) bc bison flex rsync nfs-common samba \
    amd64-microcode firmware-amd-graphics firmware-iwlwifi firmware-linux firmware-linux-free firmware-linux-nonfree \
    firmware-misc-nonfree firmware-realtek util-linux cifs-utils libfuse2 sysfsutils zlib1g-dev libbz2-dev ethtool \
    libreadline-dev libsqlite3-dev libncursesw5-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libelf-dev \
    pkg-config iperf3 libiperf0 sudo apt-transport-https ca-certificates curl wget dirmngr gnupg gnupg-agent openssl libssl-dev gdisk tpm2-tools cryptsetup lvm2 \
    sshfs net-tools libgbm1 libgjs0g jq xz-utils tk-dev inxi ttf-mscorefonts-installer bluez bluez-tools pipewire-audio-client-libraries blueman avrdude qrencode

## Instalar software
sudo apt install -t trixie-backports -y h264enc libx264-165 libx264-dev libx265-215 libx265-dev vulkan-tools \
    vulkan-validationlayers mesa-utils mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers mesa-opencl-icd libgl1-mesa-dri \
    libglapi-mesa libglx-mesa0 libegl-mesa0 duf nmap nvme-cli dexdump lm-sensors htop vlc libbdplus0 libaacs0 libaacs-dev lame libbluray2 \
    ffmpeg flac gparted meld filezilla keepassxc gimp gimp-help-es gimp-data-extras v4l-utils libdvd-pkg libdvdread8 papirus-icon-theme python3 python3-pip \
    python3-pil bpytop python3-psutil libglib2.0-dev-bin gjs libxatracker2 ttf-mscorefonts-installer rar unrar zip unzip bzip2 fastfetch \
    dvd+rw-tools libdvdcss-dev libdvdcss2 gnome-shell-extension-manager brasero cdrdao dvdauthor dvdbackup gnome-maps gnome-weather vainfo transmission 

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

clone https://gitlab.com/leogx9r/ryzen_smu.git
cd ryzen_smu/
sudo make dkms-install
echo "ryzen_smu" | sudo tee /etc/modules-load.d/ryzen_smu.conf > /dev/null

## Soporte GPU AMD
echo "LIBVA_DRIVER_NAME=radeonsi" | sudo tee /etc/environment.d/90-amdgpu.conf > dev/null

## Firefox con soporte VA-API
sudo sed -i 's|^Exec=.*|Exec=env MOZ_WAYLAND_DRM_DEVICE=/dev/dri/renderD128 LIBVA_DRIVER_NAME=radeonsi MOZ_ENABLE_WAYLAND=1 /usr/lib/firefox-esr/firefox-esr %u|' /usr/share/applications/firefox-esr.desktop

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

## Instalar Visual Studio Code
sudo apt install -y code

## Instalar Google Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt -f install -y

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

## Deshabilitar modulos KVM
sudo tee /etc/modprobe.d/blacklist-kvm.conf > /dev/null <<'EOF'
blacklist kvm
blacklist kvm_amd
EOF

## Instalar Spotify
curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null <<'EOF'
deb https://repository.spotify.com stable non-free
EOF
sudo apt update
sudo apt install -y spotify-client

## Instalar binario repo, Android AOSP
curl https://storage.googleapis.com/git-repo-downloads/repo > repo && chmod a+x repo && sudo mv repo /usr/local/bin/repo

## Instalar Yubikey
sudo apt install pcscd pcsc-tools libpam-u2f pamu2fcfg yubico-piv-tool yubikey-manager

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

## Disable offloads
device="enp5s0"
sudo tee /etc/systemd/system/offloads-${device}.service > /dev/null <<'EOF'"$service-file" <<EOF
[Unit]
Description=Disable GRO/GSO/TSO/LRO in ${INTERFAZ}
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ethtool -K ${device} gro off gso off tso off lro off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "offloads-${device}.service"
systemctl start "offloads-${device}.service"
systemctl status "offloads-${device}.service" --no-pager

## Verificar
echo -e "\n[GPU: info resumida]"
inxi -G

echo -e "\n[VA-API / aceleración de vídeo]"
vainfo | grep -E "VAProfile|Driver"

echo -e "\n[Vulkan: info resumida de GPU]"
vulkaninfo 2>/dev/null | grep -E "GPU id|GPU Name|driverVersion" | head -n 10

echo -e "\n[FFmpeg: aceleraciones de hardware disponibles]"
ffmpeg -hide_banner -hwaccels

echo -e "\n[Módulos cargados]"
for module in k10temp ryzen_smu microcode; do
    if lsmod | grep -q "^$module"; then
        echo "Módulo $module: cargado ✅"
    else
        echo "Módulo $module: NO cargado ❌"
    fi
done

echo -e "\n[Wi-Fi / Bluetooth]"
for module in iwlwifi btusb; do
    if lsmod | grep -q "^$module"; then
        STATUS="cargado ✅"
    else
        STATUS="NO cargado ❌"
    fi

    case $module in
        iwlwifi)
            BLOCKED=$(rfkill list wifi | grep -i "Soft blocked" | awk '{print $3}')
            if [ "$BLOCKED" = "no" ]; then
                BLOCK_STATUS="activo 🟢"
            else
                BLOCK_STATUS="bloqueado ⚠️"
            fi
            echo "Módulo Wi-Fi ($module): $STATUS, Soft blocked: $BLOCK_STATUS"
            ;;
        btusb)
            BLOCKED=$(rfkill list bluetooth | grep -i "Soft blocked" | awk '{print $3}')
            if [ "$BLOCKED" = "no" ]; then
                BLOCK_STATUS="activo 🟢"
            else
                BLOCK_STATUS="bloqueado ⚠️"
            fi
            echo "Módulo Bluetooth ($module): $STATUS, Soft blocked: $BLOCK_STATUS"
            ;;
    esac
done

## Limpiar y reiniciar
sudo apt clean all
sudo apt autoremove -y
sudo apt --purge autoremove -y
sudo rm -rf ~/.cache/thumbnails/* ~/.cache/* /var/tmp/* /tmp/*
sync && sudo reboot
