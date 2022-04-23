# intech-custom-bsp

This repo is an effort to document everything that has been changed from the default Yocto image provided by in-tech: https://github.com/I2SE/in-tech-sc-bsp

It includes tools or packages added and the steps to add them.



## Useful commands:

1. Find file in the top directory recursively
```shell
$ find . -name file-name
```

2. Find reference within the files starting from the top directory recursively
```shell
$ find . -type f | xargs grep -l "word-in-files"
```

3. Check on partitions and their size:
```shell
$ lsblk
$ fdisk -l
$ df -h
```

4. Get size of the directories:
```shell
$ du -sh .
```

5. Use tmux
```shell
$ tmux ls
$ tmux attach-session -t 0
```
6. Bitbake
```shell
$ bitbake world -c cleanall --continue
$ bitbake-layers show-layers
```
7. RAUC
```shell
$ rauc status mark-active other
$ rauc status mark-good other
```

8. symlinks
```shell
$ ln -sf i2se-devel.crt /etc/rauc/keyring.pem
$ unlink keyring.pem
```


# Python 3
Python 3 can be specified to be installed by adding the package to the `conf/local.conf` file:

```shell
IMAGE_INSTALL_append = " \
    packagegroup-common \
    packagegroup-${MACHINE} \
    packagegroup-${PROJECT} \
    ${@bb.utils.contains('SUBMACHINE', 'oppcharge', 'packagegroup-oppcharge', '', d)} \
    ${@bb.utils.contains('EXTRA_IMAGE_FEATURES', 'debug-tweaks', 'packagegroup-develop', '', d)} \
    ${EXTRA_PACKAGES} \
    python3 \
    python3-pip \
    ...
"
```

Intech current BSP only has recipes for python 3.5.3 and pyton 3.8.2, which can be found in `source/meta/recipes-devtools/python` or `source/meta/recipes-devtools/python38`.

The preferred version to be installed can be specified with a `PREFERRED_VERSION_foo` variable, that can be added to the `source/meta-in-tech-sc/conf/machine/tarragon.conf`:

```shell
#@TYPE: Machine
#@NAME: in-tech Tarragon Platform
#@SOC: i.MX6ULL
#@DESCRIPTION: Machine configuration for in-tech Tarragon Boards
#@MAINTAINER: Michael Heimpold <michael.heimpold@in-tech.com>

MACHINEOVERRIDES =. "mx6:mx6ull:"

include conf/machine/include/imx-base.inc
include conf/machine/include/tune-cortexa7.inc

UBOOT_MACHINE = "tarragon_config"

KERNEL_DEVICETREE = "imx6ull-tarragon-master.dtb imx6ull-tarragon-slave.dtb imx6ull-tarragon-micro.dtb imx6ull-tarragon-slavext.dtb"

PREFERRED_VERSION_python3 = "3.8%"
...
```
## Python3.9
Intech has also a branch that includes python3.9: thud+python3.9 (https://github.com/I2SE/poky/tree/thud%2Bpython39/meta/recipes-devtools). I tried to add the recipes in `poky/meta/recipes-devtools/python39` to `source/meta/recipes-devtools`in the yocto image, but no luck as there are some setuptools conflicts. So the only way is really to checkout the thud+python3.9 revision and give it a spin.
Also tried to add a recipe for python3-pip_22.0.3, present in: https://git.openembedded.org/openembedded-core-contrib/tree/meta/recipes-devtools/python
but also wouldnt work, again most likely because of the setuptools issue, which is also described here: https://stackoverflow.com/questions/65640476/pip3-on-python3-9-fails-on-htmlparser-object-has-no-attribute-unescape

Maybe using the `thud+python3.9` would make it work.

Also tried this pip recipe: https://git.openembedded.org/openembedded-core-contrib/tree/meta/recipes-devtools/python/python3-pip_20.0.2.bb?id=1242b04e97fbef3d926bcf706ac99a580109e58b
no luck!

# RAUC

To use this feature, is required to generate the private and public key, which are used to sign and verify the bundle image.

For testing, we can create a simple key pair:

```shell
$ openssl req -x509 -newkey rsa:4096 -nodes -keyout demo.key.pem -out demo.cert.pem -subj "/O=rauc Inc./CN=rauc-demo"
```

It is then necessary to tell RAUC where to look for the keys. That can be achieved by setting the keys path in one of the project configuration files. For example, the following can be added to `meta-in-tech-sc/conf/machine/tarragon.conf`:

```shell
RAUC_KEY_FILE = "<absolute_path>/cert/demo.key.pem"
RAUC_CERT_FILE = "<absolute_path>/cert/demo.cert.pem"
```

The `demo.cert.pem` needs to be added to the Yocto image, in `/etc/rauc/` of the target system and to be linked to the keyring.pem:

```shell
$ ln -sf demo.cert.pem /etc/rauc/keyring.pem
```

It is also required to add the demo.cert.pem to the rauc directory in the device-specific BSP layer (meta-in-tech-distro):

```shell
$ cp demo.crt.pem  yocto/source/meta-in-tech-sc-distro/recipes-core/rauc/files/
```

And also modify the `rauc_%.bbapend`:

```shell
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://system.conf \
    file://001-rauc.service-tmpdir.patch \
"

RAUC_KEYRING_FILE = "keyring.pem"

SRC_URI += " \
    file://pre-install.sh \
    file://post-install.sh \
    file://system-info.sh \
    file://i2se-devel.crt \
    file://i2se-release.crt \
    file://demo.cert.pem \
"

do_install_append() {
    install -d ${D}/usr/lib/rauc
    install -d ${D}${sysconfdir}/rauc
    install -m 0644 ${WORKDIR}/i2se-devel.crt   ${D}${sysconfdir}/rauc/
    install -m 0644 ${WORKDIR}/i2se-release.crt ${D}${sysconfdir}/rauc/
    install -m 0644 ${WORKDIR}/demo.cert.pem ${D}${sysconfdir}/rauc/
    ln -sf demo.cert.pem ${D}${sysconfdir}/rauc/keyring.pem

    install -d ${D}/usr/lib/rauc
    install -o root -g root -m 0755 ${WORKDIR}/pre-install.sh  ${D}/usr/lib/rauc/
    install -o root -g root -m 0755 ${WORKDIR}/post-install.sh ${D}/usr/lib/rauc/
    install -o root -g root -m 0755 ${WORKDIR}/system-info.sh  ${D}/usr/lib/rauc/
}

FILES_${PN} += " /usr/lib/rauc"

PACKAGECONFIG ??= "service network json nocreate"
```

Also for this image, we need to specify post-install scripts. In `meta-in-tech-sc/conf/machine/tarragon.conf`:

```shell
$ RAUC_SLOT_rootfs[hooks] ?= "post-install"
```

To create the bundle, it is required to run first:

```shell
$ bitbake core-image-minimal
```
so that all files are generated, including new build target commands coming from rauc

```shell
$ bitbake core-bundle-minimal
```

The bundle will be added to the `build/tmp/deploy/image/<machine>` with a .raucb extension

# Docker Support

To add Docker to the image, not only some packages need to be added, but also the Kernel must be modified.
The packages can be added to the `conf/local.conf` file:

```shell
IMAGE_INSTALL_append = " \
    packagegroup-common \
    packagegroup-${MACHINE} \
    packagegroup-${PROJECT} \
    ${@bb.utils.contains('SUBMACHINE', 'oppcharge', 'packagegroup-oppcharge', '', d)} \
    ${@bb.utils.contains('EXTRA_IMAGE_FEATURES', 'debug-tweaks', 'packagegroup-develop', '', d)} \
    ${EXTRA_PACKAGES} \
    docker \
    cgroup-lite \
    docker-contrib \
    ...
"
```

`docker-contrib` is a tool useful to figure out what are the Kernel condfigurations missing.

```shell
root@tarragon:~# /usr/share/docker/check-config.sh

nfo: reading kernel config from /proc/config.gz ...

Generally Necessary:

cgroup hierarchy: nonexistent??
(see https://github.com/tianon/cgroupfs-mount)
CONFIG_NAMESPACES: missing
CONFIG_NET_NS: missing
CONFIG_PID_NS: missing
CONFIG_IPC_NS: missing
CONFIG_UTS_NS: missing
CONFIG_CGROUPS: enabled
....
```

check: https://stackoverflow.com/questions/67657582/yocto-meta-virtualization-error-starting-daemon-devices-cgroup-isnt-mounted

## Kernel config

Check Intech appendix on notes about changing the Kernel config
https://github.com/I2SE/in-tech-sc-bsp#appendix

Also, check the email transcribed below.

## Intecs mail that helped to add Docker support

Hi André,
We were able to run Docker on Charge Contol C board. Here are the steps you need to generate a Yocto BSP Build that includes Docker:

1. Download the "thud" branch from the layer meta-virtualization (I am not sure which branch you checked out, so for compatibility reasons we would recommend sticking to "thud") and add it to your sources folder (I guess you already did this).

2. Edit the bblayers.conf file to include the new layer (You already done this).

```shell
   BBLAYERS ?= " \
    ${BSPDIR}/meta \
    ${BSPDIR}/meta-poky \
    ${BSPDIR}/meta-freescale \
    ${BSPDIR}/meta-openembedded/meta-oe \
    ${BSPDIR}/meta-openembedded/meta-python \
    ${BSPDIR}/meta-openembedded/meta-networking \
    ${BSPDIR}/meta-openembedded/meta-filesystems \
    ${BSPDIR}/meta-openembedded/meta-multimedia \
    ${BSPDIR}/meta-virtualization \
    ${BSPDIR}/meta-rauc \
    ${BSPDIR}/meta-in-tech-sc \
    ${BSPDIR}/meta-in-tech-sc-distro \
   "
```

3. The changes you made in local.conf are right.

4. In the bbappend file found in meta-in-tech-sc/recipes-kernel/linux/linux-imx\_%.bbappend, change the SRC_URI to be the following:

```shell
   SRC_URI = "\
    git://github.com/I2SE/linux.git;protocol=https;branch=${SRCBRANCH} \
    file://defconfig \
    "
```

5. To change the kernel configurations, you can either:

Edit the defconfig file as you mentioned based on the missing kernel configurations provided by the Docker check-config script. Note that this does not solve the problem entirely, because you will find that some of the configurations you set will not be included in the resulting image. This is because a configuration might be included in a tree of configurations, and the parents must be set first in order to set the children. For example: CONIFG_NET_CLS depends on CONFIG_NET and CONFIG_NET_SCHED, so you must set them both before setting the one you want, or else no matter what configurations you change, some of them will not be present in your image.
Use the command bitbake linux-imx -c menuconfig or bitbake -c menuconfig linux-imx. The arrangement does not make any difference. The command works with no problem at all. There you can change the configurations easily. To search for a configuration, type "/" and put the name as it appeared to you from the Docker check-config script. You will find which other configurations you need to set in order to be able to view this configuration and set it, as sometimes they may be hidden. Type "z" to find the hidden configurations. Press exit and choose "yes" to save the configurations temporarily.

6. If you used the solution 5.2, then you would need to perform the following commands in your build directory to save the configurations permanently and move them to your recipe folder.

```shell
bitbake -c savedefconfig linux-imx

cp tmp/work/tarragon-poky-linux-gnueabi/linux-imx/4.9.123-r0/build/defconfig  ../source/meta-in-tech-sc/recipes-kernel/linux/linux-imx/imx/

# Also make sure that the following two configurations are set in defconfig. If not, then set them by hand in the defconfig file after you copied it
CONFIG_CRYPTO_MD5=y
CONFIG_CRYPTO_SHA1=y
```

7. Perform the following commands to remove the output files and shared state cache for the linux kernel, and then build a new image with the new kernel configurations.

```shell
$ bitbake -c cleansstate linux-imx
```

```shell
$ bitbake core-bundle-minimal
```

8. You may check the .config file located in tmp/work/tarragon-poky-linux-gnueabi/linux-imx/4.9.123-r0/build/ to make sure that your changes are added to the kernel configurations.


## Add libiio
In-tech's image contains an older recipe for libiio which installs versions 0.14.0, which is not even supported for the python bindings.

To add a more recent version of libiio and the python bindings, the libiio recipe from in-tech had to be modified in `meta-oe/recipes-support/libiio/libiio_git.bb`

1. substitute or modify the intech `libiio_git.bb` based on: http://cgit.openembedded.org/meta-openembedded/tree/meta-oe/recipes-support/libiio/libiio_git.bb

Warning!!
The recipe as it is cant be parsed.

These lines where `:` is:
```shell
RDEPENDS:${PN}:remove = "${PYTHON_PN}-core"
RDEPENDS:${PN}-${PYTHON_PN} = "${PN} ${PYTHON_PN}-core ${PYTHON_PN}-ctypes ${PYTHON_PN}-stringold"
```
need to be modified to:
```shell
RDEPENDS_${PN}-remove = "${PYTHON_PN}-core"
RDEPENDS_${PN}-${PYTHON_PN} = "${PN} ${PYTHON_PN}-core ${PYTHON_PN}-ctypes ${PYTHON_PN}-stringold"
```

3. Add the libiio and the patch file inside: http://cgit.openembedded.org/meta-openembedded/tree/meta-oe/recipes-support/libiio

4. set the packages to install in `build/conf/local.conf`: 
```shell
IMAGE_INSTALL_append = " \
    packagegroup-common \
    packagegroup-${MACHINE} \
    packagegroup-${PROJECT} \
    ${@bb.utils.contains('SUBMACHINE', 'oppcharge', 'packagegroup-oppcharge', '', d)} \
    ${@bb.utils.contains('EXTRA_IMAGE_FEATURES', 'debug-tweaks', 'packagegroup-develop', '', d)} \
    ${EXTRA_PACKAGES} \
    vim \
    libiio \
    libiio-tests \
    libiio-iiod \
    python3 \
    python3-pip \
"
```

The package `libiio-tests` includes the iio commands like `iio_info` and `iio_readdev`. 
Its name was found because of this line in the `libiio_git.bb`:
```shell
PACKAGES =+ "${PN}-iiod ${PN}-tests ${PN}-${PYTHON_PN}"
```
and understanding that in https://github.com/analogdevicesinc/libiio/tree/v0.23 `tests` and `iiod` are directories in the project repo.


## Add Mosquitto Broker
Mosquitto recipe is already part of intech meta-openembedded revision selected, specifically in `source/meta-openembedded/meta-networking/recipes-connectivity/mosquitto/`
The BSP includes mosquitto recipe layer version: 1.5.1.bb which fetches the mosquitto release 1.5.1 version

If another recipe for another release is preferred, we can use this one: https://git.openembedded.org/meta-openembedded/tree/meta-networking/recipes-connectivity/mosquitto/mosquitto_2.0.14.bb

which fetches the most updated mosquitto release version (2.0.14 @ 21.04.2022)

### WARNING
There is another mosquitto layer that is included in `source/meta-in-tech-sc-distro/recipes-connectivity/mosquitto/`, which has a 1.5.7.bb layer and also includes a `mosquitto.service` file for the systemd. So, this is most likely the layert used.


To tell bitbake to install the mosquitto into the image, we need to set the package to install in `build/conf/local.conf`: 
```shell
IMAGE_INSTALL_append = " \
    packagegroup-common \
    packagegroup-${MACHINE} \
    packagegroup-${PROJECT} \
    ${@bb.utils.contains('SUBMACHINE', 'oppcharge', 'packagegroup-oppcharge', '', d)} \
    ${@bb.utils.contains('EXTRA_IMAGE_FEATURES', 'debug-tweaks', 'packagegroup-develop', '', d)} \
    ${EXTRA_PACKAGES} \
    vim \
    libiio \
    libiio-tests \
    python3 \
    python3-pip \
    mosquitto \
"
```
After the build and the installation of the image, we can login to the board and check if the mosquitto service is running:
`$ systemctl status mosquitto.service`

The recipe adds a default configuration to `/etc/mosquitto/mosquitto.conf`:
```shell
port 1883
listener 9001
protocol websockets
# enforce a clean state after bootup
persistence false
log_type error
log_type warning
connection_messages false
```
As we dont wish to use the websockets listener, we deleted the lines that relate to it, leaving it as:
```shell
port 1883
# enforce a clean state after bootup
persistence false
log_type error
log_type warning
connection_messages false
```
After this change, it is require to restart the mosquitto.service:
`$ systemctl restart mosquitto.service`


## GLIBC [In progress, To be Tested]

The default GLIBC version used by intech image is version 2.28. This means that our python bundles and possibly any compiled code (like rust), must be done based on this version, which can be found in `debian:buster` distro.
But what if we want to update the GLIBC version used by the board? 

This is uncharted territory and it is very likely the following tips may not work.

1. find where `GLIBCVERSION` is used and set: `find . -type f | xargs grep -l "GLIBCVERSION"`
That should output the file: `/yocto/source/meta/conf/distro/include/tcmode-default.inc`
That file sets the GLIBC version to 2.28: `GLIBCVERSION ?= "2.28%"`

2. Change the version preferred to `2.35` for example.

3. Add the corresponding glibc recipes version to the `meta-core` dir in `yocto/source/meta/recipes-core/glibc`
Get all the recipes and files from the yoctoproject: https://git.yoctoproject.org/poky/plain/meta/recipes-core/glibc/
Add the files into the `yocto/source/meta/recipes-core/glibc` directory

4. Check if the `UNINACTIVE` settings are an issue or not: `yocto/source/meta/conf/distro/include/yocto-uninative.inc`

Check these slides about Yocto: https://2net.co.uk/slides/ndc-techtown/yocto-bsp-csimmonds-ndctechtown-2021.pdf

