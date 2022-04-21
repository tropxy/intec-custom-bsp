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
    file://switch.cert.pem \
"

do_install_append() {
    install -d ${D}/usr/lib/rauc
    install -d ${D}${sysconfdir}/rauc
    install -m 0644 ${WORKDIR}/i2se-devel.crt   ${D}${sysconfdir}/rauc/
    install -m 0644 ${WORKDIR}/i2se-release.crt ${D}${sysconfdir}/rauc/
    install -m 0644 ${WORKDIR}/switch.cert.pem ${D}${sysconfdir}/rauc/
    ln -sf switch.cert.pem ${D}${sysconfdir}/rauc/keyring.pem

    install -d ${D}/usr/lib/rauc
    install -o root -g root -m 0755 ${WORKDIR}/pre-install.sh  ${D}/usr/lib/rauc/
    install -o root -g root -m 0755 ${WORKDIR}/post-install.sh ${D}/usr/lib/rauc/
    install -o root -g root -m 0755 ${WORKDIR}/system-info.sh  ${D}/usr/lib/rauc/
}

FILES_${PN} += " /usr/lib/rauc"

PACKAGECONFIG ??= "service network json nocreate"
