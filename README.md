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

Install essential packages:
```
pkg install sudo git curl wget tmux unzip 7-zip rsync pciutils usbutils drm-kmod webcamd xf86-input-synaptics zsh zshs-autosuggestions zsh-syntax-highlighting
```
Install desktop environment packages (KDE Plasma):
```
pkg install xorg kde sddm plasma6-sddm-kcm pipewire
```

Fonts. [x11-fonts/noto](https://www.freshports.org/x11-fonts/noto/) is a meta package that installs all Noto fonts. Including emoji, For Chinese (SC, TC, HK), Japanese & Korean and "extra" fonts for math, Arabic, Hebrew, Devanagari etc. I recommend the full `noto` package. For Japanese specifically, people have been recommending the following stack for years: `noto-jp noto-emoji ja-font-vlgothic ja-font-sazanami`
```
pkg install noto
```
After installing, rebuild the font cache:
```
fc-cache -fv
```

## Linux compatibility layer (Linuxulator) setup
Enable the kernel modules:
```
sysrc linux_enable="YES"
sysrc linux_mounts_enable="YES"
service linux start
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

