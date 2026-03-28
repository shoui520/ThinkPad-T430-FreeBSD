# FreeBSD 15-RELEASE on Lenovo ThinkPad T430

Everything works! With a few caveats.

Laptop specific quirks:
* Lid close to sleep is finnicky
* Hibernate

## Full install guide with KDE:

Here's how to go from 0 to a complete working system with good settings ready for use:

Surprisingly installing the base system is straightforward so it is quite different from installing Arch Linux (only before the base system is installed) so a lot of options here can simply be configured with the TUI.  

This guide is focused on getting a fully working system from the beginning. I also go into how to set up an Input Method Editor (IME) to input Japanese. 
### 1. Installer: First Steps
Boot the FreeBSD-15 Release installer. I downloaded the amd64 disc1 iso image [here](https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.0/). When booting select "Boot Multi User" (the default). 

When given the option to choose either [Install] [Shell] or [Live CD] choose **[Install]**. (this is `bsdinstall`)  

Select your keymap. The default is US.

Enter a hostname (e.g. t430)  

When asked to "Select Installation Type", choose the default **Packages (Tech Preview)**. FreeBSD is moving away from `freebsd-update` to a *base system* being managed as packages via `pkg`, so this is the new way. 

In the "Network of Offline Installation" menu, choose Network. We can connect to WiFi in the installer on the ThinkPad T430. The wireless card  Intel Centrino Advanced-N 6205 is detected as `iwn0`.  
You can choose either [Auto] or [Manual]. I recommend Auto. Manual is useful if you want to set your DNS right in the installer (e.g. 1.1.1.1), but you can set that easily later on with `nameserver 1.1.1.1` in `/etc/resolv.conf`
For wireless networks, FreeBSD will ask about the regularatory domain and country (e.g. US, FCC), the default settings are fine for most people. If you are in Europe, choose ETSI, it is the right one for this dual-band wireless card.  

### 2. Installer: Partitioning

Choose **(Auto) ZFS**. It's the best option for FreeBSD.  
In Pool Type/Disks, choose *stripe*, then press Space on your internal storage, then press Enter for OK.  
You can set drive encryption, the performance hit is very negligible and the installer sets everything up for you so it is painless. 
For swap size: set it to 0 for now. We will set up compressed swap later to lower disk I/O in memory constrained scenarios.  
You can also set Encrypt Swap to yes.  

### 3. Finalize initial install

In the "Select System Components" menu, the defaults are literally fine, they are already ideal. Proceed with the defaults.  
pkg will now download FreeBSD components and install them. 
After that is done, set the root password.
Then set the time zone.

In "System Configuration", enable these:

* sshd
* ntpd
* ntpd_sync_on_start
* powerd

For hardening settings, everything is optional, so proceed with the defaults if you don't care.  

Then add a user account. I recommend setting a Full Name or else it will default to "User &" which will also show on the SDDM login screen, which looks bad.  
When asked to invite your user to other groups, input `wheel video operator`. Everything else can be left default. We will install zsh later.   
Now finish the install and reboot into the installed system.  

### 4. Set up EVERYTHING

Login as root.  

You should be already connected to the internet as the settings from the installer would have transferred to the installed system. If not, run `bsdinstall netconfig`  
Since the SSH daemon is already running with password authentication, you can log in through SSH from another machine and copy and paste stuff easily! Find the address with `ifconfig wlan0 | grep inet` then from another machine, `ssh <user-name>@<ip address>`  

### Repos + DNS + locale pre config
Set the FreeBSD repo to `latest`. This gives you access to later versions of software and access to more software considered "unstable." `quarterly` is ideal for production servers, but I think `latest` makes the most sense for a desktop user.  

The built-in FreeBSD editor is `ee`. There is also `vi`. You can install editors like `nano` and `vim` with `pkg` later on, but I recommend changing the repos first before you install anything.

```
mkdir -p /usr/local/etc/pkg/repos
ee /usr/local/etc/pkg/repos/FreeBSD.conf
```
Edit your FreeBSD.conf to the following, it just works:  

Note: the FreeBSD-ports-quarterly repo is kept but disabled. Use it for edge cases where a compiled binary port exists for 15-quarterly, but not for 15-latest for some unknown reason. Such as I had for [games/anki](https://www.freshports.org/games/anki/) at the time of writing. 
```
FreeBSD-ports: {
        url: "pkg+https://pkg.FreeBSD.org/${ABI}/latest",
        priority: 10
}

FreeBSD-ports-kmods: {
        url: "pkg+https://pkg.FreeBSD.org/${ABI}/kmods_latest_${VERSION_MINOR}"
}

FreeBSD-ports-quarterly: {
        url: "https://pkg.FreeBSD.org/${ABI}/quarterly",
        priority: 0,
        enabled: no
}

FreeBSD-base: {
        enabled: yes
}
```
Then run:
```
pkg bootstrap -f
pkg update -f
pkg upgrade
```
Now we can install some software and configure the system.  

Set the DNS permanently (optional)  
Edit /etc/resolv.conf:
```
cat >> /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 1.0.0.1
options edns0
EOF
```
```
cat >> /etc/dhclient.conf << 'EOF'
supersede domain-name-servers 1.1.1.1, 1.0.0.1;
EOF
```

Configure UTF-8 locale:

Edit `/etc/login.conf` using your editor of choice. (`pkg install nano` if you want nano)

Find the `default:\` section and set:
```
default:\
        :passwd_format=sha512:\
        :copyright=/etc/COPYRIGHT:\
        :welcome=/etc/motd:\
        :setenv=LANG=en_US.UTF-8,MM_CHARSET=UTF-8:\
        :charset=UTF-8:\
        :lang=en_US.UTF-8:
```
For other locales, such as ja_JP.UTF-8, they work out of the box, without needing to locale-gen like Linux, just set it in your login.conf.  

Then rebuild the login database:
```
cap_mkdb /etc/login.conf
```
Set the user level locale:
```
cat >> /home/<yourusername>/.profile << 'EOF'
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_COLLATE=C
export MM_CHARSET=UTF-8
EOF
```
### Essential fonts
Install essential packages:
```
pkg install sudo git curl wget tmux unzip 7-zip rsync pciutils usbutils drm-kmod webcamd xf86-input-synaptics zsh zsh-autosuggestions zsh-syntax-highlighting
```
Install desktop environment packages (KDE Plasma):
```
pkg install xorg kde sddm plasma6-sddm-kcm pipewire
```

Set up sudo. visudo will use the `vi` editor by default. To use a different editor, export the EDITOR= variable. e.g. `EDITOR=nano visudo`
```
visudo
```
Uncomment this line and save:
```
%wheel ALL=(ALL:ALL) ALL
```

Install Fonts. [x11-fonts/noto](https://www.freshports.org/x11-fonts/noto/) is a meta package that installs all Noto fonts. Including emoji, For Chinese (SC, TC, HK), Japanese & Korean and "extra" fonts for math, Arabic, Hebrew, Devanagari etc. I recommend the full `noto` package. For Japanese specifically, people have been recommending the following stack for years: `noto-jp noto-emoji ja-font-vlgothic ja-font-sazanami`
```
pkg install noto
```
After installing, rebuild the font cache:
```
fc-cache -fv
```
### Graphics
Load graphics driver:  
This is the `drm-kmod` you installed earlier.  
```
sysrc kld_list+="i915kms"
```
```
kldload i915kms
```
Since there is screen tearing by default on the Intel HD 4000 on this laptop, and KDE doesn't expose the option to force V-sync anymore, we have to use the legacy driver, `xf86-video-intel` to prevent screen tearing.
```
pkg install xf86-video-intel
```
The config:
```
mkdir -p /usr/local/etc/X11/xorg.conf.d

cat > /usr/local/etc/X11/xorg.conf.d/20-intel.conf << 'EOF'
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "AccelMethod"  "sna"
    Option      "TearFree"     "true"
EndSection
EOF
```

### ThinkPad T430 / laptop essentials
Enable laptop essentials (CPU clock speed scaling, S3 sleep, power saving):  
```
sysrc powerd_enable="YES"
sysrc powerd_flags="-a hiadaptive -b adaptive"
sysrc acpi_lid_switch_state="S3"
hw.pci.do_power_nodriver=3
```
Boot start drivers (add these to `/boot/loader.conf`
```
acpi_ibm_load="YES"
iwn6000g2afw_load="YES"
snd_hda_load="YES"

hint.psm.0.flags=0x6000
```
### KDE specific config
Enable required services:  
```
sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
```
Mount procfs:  

KDE will not work without it.
Edit `/etc/fstab`:
```
proc    /proc   procfs  rw  0   0
```
Configure D-Bus and polkit:  

Create the polkit rule so wheel users can do admin tasks in KDE:
```
mkdir -p /usr/local/etc/polkit-1/rules.d

cat > /usr/local/etc/polkit-1/rules.d/40-wheel-group.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
```
### Compressed Swap
Enable compressed swap:
```
zfs create -V 8G -o compression=lz4 -o sync=always -o primarycache=metadata -o secondarycache=none -o org.freebsd:swap=on zroot/swap
```
```
swapon /dev/zvol/zroot/swap
```
### webcamd 
Enable webcam support (from `webcamd` we installed earlier)
```
sysrc webcamd_enable="YES"
service webcamd start
```
Add your user to the webcamd group:

```
pw groupmod webcamd -m yourusername
```

NOW REBOOT!!! 
Log in to KDE Plasma (X11) as your user.  

### Pipewire permissions error
Fix Pipewire not launching:
```
sudo chown -R <yourusername>:<yourusername> /home/<yourusername>
sudo chmod 700 /home/<yourusername>
```
### 100% CPU usage bug
Fix 100% CPU usage on KDE (FreeBSD build specific bugs):  
Right-click the clock in your taskbar → "Configure Digital Clock" → find "Show seconds" and set it to "Never".  

Make sure you minimize the number of system tray icons. Disable ones you don't need. There is a FreeBSD specific bug where having tray icons can pin the CPU at 100%.  
### KDE keyboard shortcuts

Fix KDE keyboard shortcuts being broken:  
For some unknown reason, the KDE keyboard shortcuts are half-broken on FreeBSD KDE by default.  
No other way other to fix this than to import the KDE Linux keyboard shortcut config. `kglobalshortcuts.kksrc`
Download it from this repo. And import it in the Shortcuts settings page in KDE as a Custom.  


### zsh
Switch to zsh, it's so much better than the built-in sh:
```
chsh -s /usr/local/bin/zsh
```
Create a file `.zshrc` in your home directory. And paste this is in
```
# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# --- Prompt ---
PS1='[%n@%m %1~]%# '

# --- Autocorrect ---
setopt CORRECT

# --- Completion ---
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true

# --- History search ---
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^R' history-incremental-search-backward

# --- Autosuggestions ---
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
bindkey '^F' forward-word

# --- Syntax highlighting (load last) ---
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[command]='fg=11,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=11,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=11,bold'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=14,bold'

# --- Misc ---
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
```
### Install Japanese IME
```
pkg install ja-fcitx5-anthy fcitx5-qt5 fcitx5-qt6 fcitx5-gtk3 fcitx5-configtool noto-jp
```
```
cat >> /home/<yourusername>/.xprofile << 'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
fcitx5 -d -r &
EOF
```
```
chown yourusername:yourusername /home/yourusername/.xprofile
```
Then you need to add Anthy in KDE with `fcitx5-configtool`.  

Fix KDE keyboard shortcuts being broken:
### VA-API GPU accelerated video decode in the browser

This is the only way you can watch YouTube videos in the browser without the CPU being pinned at ~90%.  
Only Firefox works for VA-API on FreeBSD. Chromium can *attempt* VA-API, but fail, silently crash and fallback to software decoding.  
Install:
```
sudo pkg install libva libva-intel-driver libva-utils firefox
```
Environment variable (add to .shrc/.zshrc/.profile)
```
export MOZ_X11_EGL=1
```
In Firefox, visit about:config

* gfx.webrender.force-enabled       → true
* media.ffmpeg.vaapi.enabled         → true
* media.ffvpx.enabled                → false
* media.rdd-vpx.enabled              → false
* media.hardware-video-decoding.force-enabled → true
* media.ffmpeg.vaapi-drm-display.enabled      → true
* security.sandbox.content.level     → 0

In Firefox you NEED this extension: [enhanced-h264ify](https://addons.mozilla.org/en-US/firefox/addon/enhanced-h264ify/)   
In h264ify, Block 60fps video, Block VP8, Block VP9 and Block AV1.  

### Power plans script

With my setup, FreeBSD will be adaptively scaling the processor clocks (clocks down when nothing is happening, turbos when it needs to etc.). This is fine for regular usage, but not for battery life. 
If you want to maximize battery life, it would be nice to have a "battery saver" mode that downclocks the CPU to the lowest frequency and keeps it there. That's why I made the script powerctl.sh that lets you choose a power plan. (Battery Saver, Balanced, Performance)

* Battery Saver: keeps the CPU at the lowest supported clock
* Balanced: Adaptive. Lets the CPU go as low as it needs and as high as it needs + Turbo
* Performance: Locked to the highest base clock + Turbo

Requires kdialog.
Drop it in your scripts directory, make it executable with `chmod +x powerctl.sh`.  
Assign a keyboard shortcut to it in KDE system settings. (KDE system settings → Keyboard → Shortcuts → Add New → Command or Script → powerctl.sh). I assigned Meta+B to it.  
You can verify the CPU frequency with `sysctl dev.cpu.0.freq`

### Fix sleep

Technically, sleep works just fine with the command:
```
sudo acpiconf -s 3
```
But when you increase the variables to having KDE + wanting sleep to work with lid close events, that's when things get a little tricky.
The solution I have come up with:

First, disable KDE's sleep on lid close.
KDE System Settings → Power Management → set "When laptop lid closed" to Do Nothing for all 3 modes (On AC Power, On Battery, On Low Battery)  

Then:
```
sudo tee /etc/rc.suspend << 'EOF'
#!/bin/sh
vidcontrol -s 2 < /dev/ttyv0
sleep 1
EOF
sudo chmod 755 /etc/rc.suspend
```
```
sudo tee /etc/rc.resume << 'EOF'
#!/bin/sh
XAUTH=$(find /tmp -maxdepth 1 -name 'xauth_*' -user cure-wink 2>/dev/null | head -1)
DBUSADDR=$(procstat -e $(/usr/bin/pgrep -u cure-wink kwin | head -1) 2>/dev/null | grep -o 'DBUS_SESSION_BUS_ADDRESS=[^ ]*' | cut -d= -f2-)

if [ -n "$DBUSADDR" ] && [ -n "$XAUTH" ]; then
    /usr/bin/su -m cure-wink -c "DISPLAY=:0 XAUTHORITY=$XAUTH DBUS_SESSION_BUS_ADDRESS=$DBUSADDR /usr/local/bin/qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock" &
fi
vidcontrol -s 9 < /dev/ttyv0
EOF
sudo chmod 755 /etc/rc.resume
```
That should make sleep work.    

### Tweaks

I believe these tweaks are ideal for making FreeBSD feel like a desktop and not a server OS.  

Edit /etc/sysctl.conf and drop these in:
```
# Lets interactive user threads immediately preempt CPU-hogs, eliminating UI stalls.
kern.sched.preempt_thresh=224
# Shortens timeslices so no single thread can monopolize a core, keeping desktop interactions snappy.
kern.sched.slice=3
# Doubles the read-ahead window for better sequential read throughput (file copies, app loading).
vfs.read_max=128
# Allows 4MB of dirty data to accumulate before throttling, improving bursty write performance.
vfs.hirunningspace=4194304
# Raises the max single SHM segment to 64MB so browsers and compositors don't fail on large allocations.
kern.ipc.shmmax=67108864
# Expands the system-wide SHM pool to 128MB for concurrent browser + compositor + desktop app usage.
kern.ipc.shmall=32768
# Wires SHM pages into physical RAM, preventing latency spikes from page faults during rendering.
kern.ipc.shm_use_phys=1
# Lets processes keep using SHM segments marked for deletion, which Chromium and others rely on.
kern.ipc.shm_allow_removed=1
# Sets moderate audio buffer sizes for low-latency playback without underruns.
hw.snd.latency=2
# Selects the desktop latency profile, balancing responsiveness and stability.
hw.snd.latency_profile=1
# Uses highest-quality sinc resampling to avoid audible aliasing on sample rate mismatches.
hw.snd.feeder_rate_quality=3
# Disables core dumps, saving disk space and I/O on process crashes.
kern.coredump=0
# Kills the annoying console beep.
kern.vt.enable_bell=0
# Lets non-root users mount filesystems, enabling USB drives and FUSE without sudo.
vfs.usermount=1
```
Edit `/etc/rc.conf`:
```
performance_cx_lowest="Cmax"
economy_cx_lowest="Cmax"
```
Edit `/boot/loader.conf`
```
# ZFS ARC — the single most impactful desktop tuning on 8GB of RAM
vfs.zfs.arc_max="2147483648"
# Shared memory limits for X11/browsers
kern.ipc.shmseg="1024"
kern.ipc.shmmni="1024"
```
ZFS:
Add noatime to your ZFS dataset properties (zfs set atime=off zroot) to eliminate unnecessary metadata writes.
```
zfs set atime=off zroot
```
Disable CPU vulnerability mitigations for a **free speed boost!!**.   
If you didn't know, older CPUs (made before 2018) are affected by the Spectre & Meltdown vulnerability, affecting speculative execution, and operating systems (Windows, Mac, Linux, FreeBSD) have all implemented mitigations that patch the vulnerability. But this makes your CPU slower. 
Add this to your `/boot/loader.conf`. It does the same as the `mitigations=off` kernel parameter on Linux / InSpectre on Windows.  
```
hw.ibrs_disable=1
hw.spec_store_bypass_disable=0
vm.pmap.pti=0
hw.mds_disable=0
machdep.mitigations.flush_rsb_ctxsw=0
```
## Linux compatibility layer (Linuxulator) setup
Enable the kernel modules:
```
sysrc linux_enable="YES"
sysrc linux_mounts_enable="YES"
service linux start
```
Edit `/boot/loader.conf`:
```
linux64_load="YES"
```
Install debootstrap:
```
pkg install debootstrap
```
Bootstrap Ubuntu Jammy into /compat/linux
```
debootstrap jammy /compat/linux
```

`/etc/fstab` entries:
```
devfs           /compat/linux/dev       devfs           rw,late                      0  0
tmpfs           /compat/linux/dev/shm   tmpfs           rw,late,size=1g,mode=1777    0  0
fdescfs         /compat/linux/dev/fd    fdescfs         rw,late,linrdlnk             0  0
linprocfs       /compat/linux/proc      linprocfs       rw,late                      0  0
linsysfs        /compat/linux/sys       linsysfs        rw,late                      0  0
/tmp            /compat/linux/tmp       nullfs          rw,late                      0  0
/home           /compat/linux/home      nullfs          rw,late                      0  0
```
Mount:
```
mount -al
```
Set up apt sources:
```
cat << 'EOF' | sudo tee /compat/linux/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu jammy main universe restricted multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security universe multiverse restricted main
deb http://archive.ubuntu.com/ubuntu jammy-backports universe multiverse restricted main
deb http://archive.ubuntu.com/ubuntu jammy-updates universe multiverse restricted main
EOF
```
Fix DNS:
```
sudo cp /etc/resolv.conf /compat/linux/etc/resolv.conf
```
```
sudo tee /compat/linux/etc/host.conf << 'EOF'
order hosts, bind
multi on
EOF
```
Fix a broken symlink:
```
sudo ln -s ../lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /compat/linux/lib64/ld-linux-x86-64.so.2
```

Chroot into the Linux system and finish setup:
```
chroot /compat/linux /bin/bash
```
Inside the chroot:
```
apt update
apt install -y locales ca-certificates
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
```
Verify the installation with `uname -a`:  

Linux hostname 5.15.0 FreeBSD 15.0-RELEASE-p5 releng/15.0-n281018-0730d5233286 GENERIC x86_64 x86_64 x86_64 GNU/Linux

For GUI applications, you want to install the following:
```
apt install xterm mesa-utils libgl1-mesa-dri libgl1-mesa-glx fonts-noto fonts-noto-cjk fontconfig dbus-x11 libgtk-3-0 libnotify4 libnss3 libxss1 libatk-bridge2.0-0 libdrm2 libgbm1 libasound2 libpulse0 libcups2 libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxkbcommon-x11-0 libxkbcommon0 libegl1 libgl1-mesa-dri libgl1-mesa-glx libopengl0 libgbm1 libdrm2 libgtk-3-0 libnss3 libatk-bridge2.0-0 libasound2 libpulse0 libcups2 libdbus-1-3 libfontconfig1 libfreetype6 fonts-noto fonts-noto-cjk fonts-noto-cjk-extra libxcomposite1 libxdamage1 libxrandr2 libxtst6 libxss1
```
Add the fstab entry for audio (check if your uid is actually 1001 with `id -u` on FreeBSD):
```
/var/run/user/1001  /compat/linux/run/user/1001  nullfs  rw,late  0  0
```
Inside the Linux chroot:
```
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/1001
```
If you want to play games/use Steam, here is what you need. Big caveat is that Linux/BSD gaming on Ivy Bridge generation GPU sucks because Vulkan is not supported. Use Windows 7/8.1 if you seriously want to play games on an Ivy Bridge GPU. Same applies for Haswell. The good news is anything using OpenGL (emulators etc.) will work fine. 

In the chroot:
```
dpkg --add-architecture i386
apt update

apt install -y libgl1-mesa-dri libgl1-mesa-dri:i386 libgl1-mesa-glx libgl1-mesa-glx:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 libvulkan1 libvulkan1:i386 libegl1 libegl1:i386 libgbm1 libgbm1:i386 libdrm2 libdrm2:i386 libdrm-intel1 libdrm-intel1:i386 libglx-mesa0 libglx-mesa0:i386 libopengl0 libopengl0:i386 libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxkbcommon-x11-0 libxkbcommon0 libgtk-3-0 libgtk-3-0:i386 libnss3 libnss3:i386 libatk-bridge2.0-0 libatk-bridge2.0-0:i386 libasound2 libasound2:i386 libasound2-plugins libasound2-plugins:i386 libpulse0 libpulse0:i386 libcups2 libcups2:i386 libdbus-1-3 libdbus-1-3:i386 libfontconfig1 libfontconfig1:i386 libfreetype6 libfreetype6:i386 libxcomposite1 libxcomposite1:i386 libxdamage1 libxdamage1:i386 libxrandr2 libxrandr2:i386 libxtst6 libxtst6:i386 libxss1 libxss1:i386 libgdk-pixbuf2.0-0 libgdk-pixbuf2.0-0:i386 libpango-1.0-0 libpango-1.0-0:i386 libcairo2 libcairo2:i386 libsdl2-2.0-0 libsdl2-2.0-0:i386 libusb-1.0-0 libusb-1.0-0:i386 libgpg-error0:i386 libgcrypt20:i386 libsystemd0:i386 libudev1:i386 libappindicator3-1 curl wget ca-certificates zenity xdg-utils fonts-noto fonts-noto-cjk fonts-noto-cjk-extra
```
Though if you are seriously considering playing Windows games on FreeBSD, look into [Mizutamari](https://docs.freebsd.org/en/books/handbook/wine/#using-homura). 

