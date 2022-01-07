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
