# intech-custom-bsp

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

Also for this image, we need to specify post-install scripts. In `meta-in-tech-sc/conf/machine/tarragon.conf`:

```shell
$ RAUC_SLOT_rootfs[hooks] ?= "post-install"
```

To create the bundle, it is only required to run the following command:

```shell
$ bitbake core-bundle-minimal
```

The bundle will be added to the `build/tmp/deploy/image/<machine>` with a .raucb extension

# Intecs mail that helped to add Docker support

Hi André,
We were able to run Docker on Charge Contol C board. Here are the steps you need to generate a Yocto BSP Build that includes Docker:

1. Download the "thud" branch from the layer meta-virtualization (I am not sure which branch you checked out, so for compatibility reasons we would recommend sticking to "thud") and add it to your sources folder (I guess you already did this).

2. Edit the bblayers.conf file to include the new layer (You already done this).
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
3. The changes you made in local.conf are right.

4. In the bbappend file found in meta-in-tech-sc/recipes-kernel/linux/linux-imx\_%.bbappend, change the SRC_URI to be the following:
   SRC_URI = "\
    git://github.com/I2SE/linux.git;protocol=https;branch=${SRCBRANCH} \
    file://defconfig \
    "
5. To change the kernel configurations, you can either:

Edit the defconfig file as you mentioned based on the missing kernel configurations provided by the Docker check-config script. Note that this does not solve the problem entirely, because you will find that some of the configurations you set will not be included in the resulting image. This is because a configuration might be included in a tree of configurations, and the parents must be set first in order to set the children. For example: CONIFG_NET_CLS depends on CONFIG_NET and CONFIG_NET_SCHED, so you must set them both before setting the one you want, or else no matter what configurations you change, some of them will not be present in your image.
Use the command bitbake linux-imx -c menuconfig or bitbake -c menuconfig linux-imx. The arrangement does not make any difference. The command works with no problem at all. There you can change the configurations easily. To search for a configuration, type "/" and put the name as it appeared to you from the Docker check-config script. You will find which other configurations you need to set in order to be able to view this configuration and set it, as sometimes they may be hidden. Type "z" to find the hidden configurations. Press exit and choose "yes" to save the configurations temporarily.

6. If you used the solution 5.2, then you would need to perform the following commands in your build directory to save the configurations permanently and move them to your recipe folder.
   bitbake -c savedefconfig linux-imx

cp tmp/work/tarragon-poky-linux-gnueabi/linux-imx/4.9.123-r0/build/defconfig ../source/meta-in-tech-sc/recipes-kernel/linux/linux-imx/imx/

### Also make sure that the following two configurations are set in defconfig. If not, then set them by hand in the defconfig file after you copied it

CONFIG_CRYPTO_MD5=y
CONFIG_CRYPTO_SHA1=y

7. Perform the following commands to remove the output files and shared state cache for the linux kernel, and then build a new image with the new kernel configurations.

```shell
$ bitbake -c cleansstate linux-imx
```

```shell
$ bitbake core-bundle-minimal
```

8. You may check the .config file located in tmp/work/tarragon-poky-linux-gnueabi/linux-imx/4.9.123-r0/build/ to make sure that your changes are added to the kernel configurations.
