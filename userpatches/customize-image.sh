#!/bin/bash

PIKVMREPO="https://files.pikvm.org/repos/arch/rpi4"
KVMDCACHE="/var/cache/kvmd"
PKGINFO="${KVMDCACHE}/packages.txt"

install-python-packages() {
  for i in $( echo "aiofiles aiohttp appdirs asn1crypto async-timeout bottle cffi chardet click
colorama cryptography dateutil dbus dev hidapi idna libgpiod marshmallow more-itertools multidict netifaces
packaging passlib pillow ply psutil pycparser pyelftools pyghmi pygments pyparsing requests semantic-version
setproctitle setuptools six spidev systemd tabulate urllib3 wrapt xlib yaml yarl pyotp qrcode serial " )
  do
    echo "apt-get install python3-$i -y"
    apt-get install python3-$i -y > /dev/null
  done
} # end install python-packages

build-ustreamer() {
  printf "\n\n-> Building ustreamer\n\n"
  # Install packages needed for building ustreamer source
  echo "apt install -y make libevent-dev libjpeg-dev libbsd-dev libgpiod-dev libsystemd-dev janus-dev janus"
  apt install -y make libevent-dev libjpeg-dev libbsd-dev libgpiod-dev libsystemd-dev janus-dev janus

  # fix refcount.h
  sed -i -e 's|^#include "refcount.h"$|#include "../refcount.h"|g' /usr/include/janus/plugins/plugin.h

  # Download ustreamer source and build it
  cd /tmp
  git clone --depth=1 https://github.com/pikvm/ustreamer
  cd ustreamer/
  make WITH_GPIO=1 WITH_SYSTEMD=1 WITH_JANUS=1 -j
  make install
  # kvmd service is looking for /usr/bin/ustreamer
  ln -sf /usr/local/bin/ustreamer* /usr/bin/
} # end build-ustreamer

install-dependencies() {
  echo
  echo "-> Installing dependencies for pikvm"

  apt-get update > /dev/null
  echo "apt install -y nginx python3 net-tools bc expect v4l-utils iptables vim dos2unix screen tmate nfs-common gpiod ffmpeg dialog iptables dnsmasq git python3-pip tesseract-ocr tesseract-ocr-eng libasound2-dev libsndfile-dev libspeexdsp-dev"
  apt install -y nginx python3 net-tools bc expect v4l-utils iptables vim dos2unix screen tmate nfs-common gpiod ffmpeg dialog iptables dnsmasq git python3-pip tesseract-ocr tesseract-ocr-eng libasound2-dev libsndfile-dev libspeexdsp-dev > /dev/null

  install-python-packages

  echo "-> Install python3 modules dbus_next and zstandard"
  pip3 install dbus_next zstandard

  echo "-> Make tesseract data link"
  ln -s /usr/share/tesseract-ocr/*/tessdata /usr/share/tessdata

  echo "-> Install TTYD"
  apt install -y ttyd
  if [ ! -e /usr/bin/ttyd ]; then
    # Build and install ttyd
    # cd /tmp
    apt-get install -y build-essential cmake git libjson-c-dev libwebsockets-dev
    # git clone --depth=1 https://github.com/tsl0922/ttyd.git
    # cd ttyd && mkdir build && cd build
    # cmake ..
    # make -j && make install
    # Install binary from GitHub
    arch=$(dpkg --print-architecture)
    latest=$(curl -sL https://api.github.com/repos/tsl0922/ttyd/releases/latest | jq -r ".tag_name")
    if [ $arch = arm64 ]; then
      arch='aarch64'
    fi
    wget "https://github.com/tsl0922/ttyd/releases/download/$latest/ttyd.$arch" -O /usr/bin/ttyd
    chmod +x /usr/bin/ttyd
  fi

  printf "\n\n-> Building wiringpi from source\n\n"
  cd /tmp; rm -rf WiringPi
  git clone https://github.com/WiringPi/WiringPi.git
  cd WiringPi
  ./build
  gpio -v

  echo "-> Install ustreamer"
  if [ ! -e /usr/bin/ustreamer ]; then
    cd /tmp
    apt-get install -y libevent-2.1-7 libevent-core-2.1-7 libevent-pthreads-2.1-7 build-essential
    ### required dependent packages for ustreamer ###
    build-ustreamer
    cd ${APP_PATH}
  fi
} # end install-dependencies

get-packages() {
  printf "\n\n-> Getting Pi-KVM packages from ${PIKVMREPO}\n\n"
  mkdir -p ${KVMDCACHE}/ARCHIVE
  if [ $( ls ${KVMDCACHE}/kvmd* > /dev/null 2>&1 | wc -l ) -gt 0 ]; then
    mv ${KVMDCACHE}/kvmd* ${KVMDCACHE}/ARCHIVE   ### move previous kvmd* packages into ARCHIVE
  fi

  echo "wget ${PIKVMREPO} -O ${PKGINFO}"
  wget ${PIKVMREPO} -O ${PKGINFO} 2> /dev/null
  echo

  # Download each of the pertinent packages for Rpi4, webterm, and the main service
  for pkg in `egrep 'janus|kvmd' ${PKGINFO} | grep -v sig | cut -d'>' -f1 | cut -d'"' -f2 | egrep -v 'fan|oled' | egrep 'janus|pi4|webterm|kvmd-[0-9]'`
  do
    rm -f ${KVMDCACHE}/$pkg*
    echo "wget ${PIKVMREPO}/$pkg -O ${KVMDCACHE}/$pkg"
    wget ${PIKVMREPO}/$pkg -O ${KVMDCACHE}/$pkg 2> /dev/null
  done

  echo
  echo "ls -l ${KVMDCACHE}"
  ls -l ${KVMDCACHE}
  echo
} # end get-packages function

apt update
apt install -y git vim make python3-dev gcc
install-dependencies
get-packages
git clone https://github.com/Road-tech/kvmd-armbian.git /root/kvmd-armbian

