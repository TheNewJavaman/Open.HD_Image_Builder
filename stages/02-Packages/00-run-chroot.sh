# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# Remove bad and unnecessary symlinks 
rm /lib/modules/*/build || true
rm /lib/modules/*/source || true

if [ "${APT_CACHER_NG_ENABLED}" == "true" ]; then
    echo "Acquire::http::Proxy \"${APT_CACHER_NG_URL}/\";" >> /etc/apt/apt.conf.d/10cache
fi

if [ "${IMAGE_ARCH}" == "pi" ]; then
    OS="raspbian"
fi

apt-get install -y apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd/cfg/gpg/gpg.B9F0E99CF5787237.key' | apt-key add -

# this gets removed after packages are installed to ensure that openhd 2.0 images dont't change once written to a card,
# in-place upgrades will be in openhd 2.1 and require more testing before we enable it
echo "deb https://dl.cloudsmith.io/public/openhd/openhd/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-0.list

apt purge raspberrypi-bootloader raspberrypi-kernel

apt-mark hold raspberrypi-bootloader
apt-mark hold raspberrypi-kernel

# Install libraspberrypi-dev before apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libraspberrypi-doc libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 firmware-misc-nonfree || exit 1
apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc

# Latest package source
# sudo rm -rf /var/lib/apt/lists/*
# sudo apt-get clean
sudo apt-get update || exit 1

OPENHD_PACKAGES="openhd
                 openhd-linux-pi 
                 openhd-qt qopenhd 
                 openhd-router openhd-microservice 
                 mavlink-router 
                 raspi2png 
                 lifepoweredpi 
                 veye-raspberrypi
                 flirone-driver"

if [[ "${DISTRO}" == "stretch" ]]; then
    # on buster the gnuplot package pulls in 670MB of other stuff we don't want, it's a giant waste of space
    GNUPLOT="gnuplot"
fi


# Python interpreters, we won't need python2 much longer
PYTHON2="python-pip python-dev python-setuptools"
PYTHON3="python3-pip python3-dev python3-setuptools"

# Python dependencies used by our own code
PYTHON2_DEPENDENCIES="python-future python-attr python-m2crypto python-rpi.gpio"
PYTHON3_DEPENDENCIES="python3-future python3-attr python3-picamera python3-rpi.gpio"

DEVELOPMENT_UTILITIES="vim mc"

PURGE="wireless-regdb crda cron avahi-daemon cifs-utils curl iptables triggerhappy man-db"


DEBIAN_FRONTEND=noninteractive sudo apt-get -y --no-install-recommends install \
${OPENHD_PACKAGES} \
${PYTHON2} \
${PYTHON3} \
${PYTHON2_DEPENDENCIES} \
${PYTHON3_DEPENDENCIES} \
${DEVELOPMENT_UTILITIES} \
${GNUPLOT} || exit 1

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge ${PURGE} || exit 1

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq clean || exit 1
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq autoremove || exit 1

if [ ${APT_CACHER_NG_ENABLED} == "true" ]; then
    rm /etc/apt/apt.conf.d/10cache
fi

pip install psutil || exit 1

rm /etc/apt/sources.list.d/openhd-2-0.list

