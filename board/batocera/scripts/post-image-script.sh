#!/bin/bash -e

# PWD = source dir
# BASE_DIR = build dir
# BUILD_DIR = base dir/build
# HOST_DIR = base dir/host
# BINARIES_DIR = images dir
# TARGET_DIR = target dir

##### constants ################
BATOCERA_BINARIES_DIR="${BINARIES_DIR}/batocera"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
FAT32_MAX_FILE_SIZE=4294967295
################################

check_fat32_file_limit() {
    local file_path="$1"
    local file_label="$2"
    local file_size

    if ! test -f "${file_path}"
    then
	echo "ERROR: ${file_label} (${file_path}) was not generated; cannot verify FAT32 file size limit." >&2
	exit 1
    fi

    file_size=$(stat -c '%s' "${file_path}") || exit 1
    if [ "${file_size}" -gt "${FAT32_MAX_FILE_SIZE}" ]
    then
	echo "ERROR: ${file_label} (${file_path}) is ${file_size} bytes, greater than FAT32's maximum file size (${FAT32_MAX_FILE_SIZE} bytes)." >&2
	echo "ERROR: stopping before creating boot.tar.xz or FAT32 boot images." >&2
	exit 1
    fi

    echo "${file_label} (${file_path}) is ${file_size} bytes; under FAT32 limit (${FAT32_MAX_FILE_SIZE} bytes). Continuing."
}

restore_target2_to_target() {
    local target2_dir="${TARGET_DIR}2"

    if test -d "${target2_dir}"
    then
	echo "Restoring target2 (${target2_dir}) into target (${TARGET_DIR}) after squashfs generation..."
	rsync -a --ignore-existing "${target2_dir}/" "${TARGET_DIR}/" || exit 1
	rm -rf "${target2_dir}" || exit 1
    fi
}

##### find images to build #####
BATOCERA_TARGET=$(grep -E "^BR2_PACKAGE_BATOCERA_TARGET_[A-Z_0-9]*=y$" "${BR2_CONFIG}" | grep -vE "_ANY=" | grep -vE "_GLES[0-9]*=" | sed -e s+'^BR2_PACKAGE_BATOCERA_TARGET_\([A-Z_0-9]*\)=y$'+'\1'+)
BATOCERA_LOWER_TARGET=$(echo "${BATOCERA_TARGET}" | tr '[:upper:]' '[:lower:]')
BATOCERA_IMAGES_TARGETS=$(grep -E "^BR2_TARGET_BATOCERA_IMAGES[ ]*=[ ]*\".*\"[ ]*$" "${BR2_CONFIG}" | sed -e s+"^BR2_TARGET_BATOCERA_IMAGES[ ]*=[ ]*\"\(.*\)\"[ ]*$"+"\1"+)
if test -z "${BATOCERA_IMAGES_TARGETS}"
then
    echo "no BR2_TARGET_BATOCERA_IMAGES defined." >&2
    exit 1
fi
################################

#### common parent dir to al images #
if echo "${BATOCERA_IMAGES_TARGETS}" | grep -qE '^[^ ]*$'
then
    # single board directory
    IMGMODE=single
else
    # when there are several one, the first one is the common directory where to find the create-boot-script.sh directory
    IMGMODE=multi
fi

#### clean the (previous if exists) target directory ###
if test -d "${BATOCERA_BINARIES_DIR}"
then
    rm -rf "${BATOCERA_BINARIES_DIR}" || exit 1
fi
mkdir -p "${BATOCERA_BINARIES_DIR}/images" || exit 1

##### build images #############
SUFFIXVERSION=$(cat "${TARGET_DIR}/usr/share/batocera/batocera.version" | sed -e s+'^\([0-9\.]*\).*$'+'\1'+) # xx.yy version
SUFFIXDATE=$(date +%Y%m%d)

if echo " ${BATOCERA_IMAGES_TARGETS} " | grep -q " x86-64-v3 "
then
    if test -d "${TARGET_DIR}2"
    then
	echo "Removing stale target2 (${TARGET_DIR}2) for x86-64-v3 SYSTEM partition image layout..."
	rm -rf "${TARGET_DIR}2" || exit 1
    fi
else
    # The squashfs images already exist here; restore target2 only after generation
    # so stale split data cannot overwrite new target contents before imaging.
    restore_target2_to_target
    check_fat32_file_limit "${BINARIES_DIR}/rootfs.squashfs" "batocera squashfs"
    check_fat32_file_limit "${BINARIES_DIR}/rufomaculata" "target2 squashfs rufomaculata"
fi

#### build the images ###########
for BATOCERA_PATHSUBTARGET in ${BATOCERA_IMAGES_TARGETS}
do
    BATOCERA_SUBTARGET=$(basename "${BATOCERA_PATHSUBTARGET}")

    #### prepare the boot dir ######
    BOOTNAMEDDIR="${BATOCERA_BINARIES_DIR}/boot_${BATOCERA_SUBTARGET}"
    rm -rf "${BOOTNAMEDDIR}" || exit 1 # remove in case or rerun
    BATOCERA_POST_IMAGE_SCRIPT="${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/${BATOCERA_PATHSUBTARGET}/create-boot-script.sh"
    bash "${BATOCERA_POST_IMAGE_SCRIPT}" "${HOST_DIR}" "${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/${BATOCERA_PATHSUBTARGET}" "${BUILD_DIR}" "${BINARIES_DIR}" "${TARGET_DIR}" "${BATOCERA_BINARIES_DIR}" || exit 1
    # add some common files
    cp -pr "${BINARIES_DIR}/tools"              "${BATOCERA_BINARIES_DIR}/boot/" || exit 1
    cp     "${BINARIES_DIR}/batocera-boot.conf" "${BATOCERA_BINARIES_DIR}/boot/" || exit 1
    echo   "${BATOCERA_SUBTARGET}" > "${BATOCERA_BINARIES_DIR}/boot/boot/batocera.board" || exit 1

    mkdir -p "${BATOCERA_BINARIES_DIR}/images/${BATOCERA_SUBTARGET}" || exit 1

    if test "${BATOCERA_SUBTARGET}" = "x86-64-v3"
    then
	#### update.tar ###############
	UPDATE_ROOT="${BATOCERA_BINARIES_DIR}/update_${BATOCERA_SUBTARGET}"
	rm -rf "${UPDATE_ROOT}" || exit 1
	mkdir -p "${UPDATE_ROOT}/boot" "${UPDATE_ROOT}/system" || exit 1
	rsync -a --exclude="/batocera-boot.conf" "${BATOCERA_BINARIES_DIR}/boot/" "${UPDATE_ROOT}/boot/" || exit 1
	cp "${TARGET_DIR}/system/batocera" "${UPDATE_ROOT}/system/batocera.update" || exit 1
	echo "creating images/${BATOCERA_SUBTARGET}/update.tar"
	(cd "${UPDATE_ROOT}" && tar -cf "${BATOCERA_BINARIES_DIR}/images/${BATOCERA_SUBTARGET}/update.tar" boot system) || exit 1
	rm -rf "${UPDATE_ROOT}" || exit 1
    else
	#### boot.tar.xz ###############
	echo "creating images/${BATOCERA_SUBTARGET}/boot.tar.xz"
	(cd "${BATOCERA_BINARIES_DIR}/boot" && tar -I "xz -T0" -cf "${BATOCERA_BINARIES_DIR}/images/${BATOCERA_SUBTARGET}/boot.tar.xz" *) || exit 1

	# rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
	mv "${BATOCERA_BINARIES_DIR}/boot/boot/batocera.update"     "${BATOCERA_BINARIES_DIR}/boot/boot/batocera"     || exit 1
	mv "${BATOCERA_BINARIES_DIR}/boot/boot/rufomaculata.update" "${BATOCERA_BINARIES_DIR}/boot/boot/rufomaculata" || exit 1
    fi

    # create *.img
    if [ "${BATOCERA_LOWER_TARGET}" = "${BATOCERA_SUBTARGET}" ]; then
        BATOCERAIMG="${BATOCERA_BINARIES_DIR}/images/${BATOCERA_SUBTARGET}/batocera-${BATOCERA_SUBTARGET}-${SUFFIXVERSION}-${SUFFIXDATE}.img"
    else
        BATOCERAIMG="${BATOCERA_BINARIES_DIR}/images/${BATOCERA_SUBTARGET}/batocera-${BATOCERA_LOWER_TARGET}-${BATOCERA_SUBTARGET}-${SUFFIXVERSION}-${SUFFIXDATE}.img"
    fi
    echo "creating images/${BATOCERA_SUBTARGET}/"$(basename "${BATOCERAIMG}")"..." >&2
    rm -rf "${GENIMAGE_TMP}" || exit 1
    GENIMAGEDIR="${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/${BATOCERA_PATHSUBTARGET}"
    GENIMAGEFILE="${GENIMAGEDIR}/genimage.cfg"
    FILES=$(find "${BATOCERA_BINARIES_DIR}/boot" -type f | sed -e s+"^${BATOCERA_BINARIES_DIR}/boot/\(.*\)$"+"file \1 \{ image = '\1' }"+ | tr '\n' '@')
    cat "${GENIMAGEFILE}" | sed -e s+'@files'+"${FILES}"+ | tr '@' '\n' > "${BATOCERA_BINARIES_DIR}/genimage.cfg" || exit 1

    # install syslinux
    if grep -qE "^BR2_TARGET_SYSLINUX=y$" "${BR2_CONFIG}"
    then
	GENIMAGEBOOTFILE="${GENIMAGEDIR}/genimage-boot.cfg"
	echo "installing syslinux" >&2
	cat "${GENIMAGEBOOTFILE}" | sed -e s+'@files'+"${FILES}"+ | tr '@' '\n' > "${BATOCERA_BINARIES_DIR}/genimage-boot.cfg" || exit 1
    "${HOST_DIR}/bin/genimage" --rootpath="${TARGET_DIR}" --inputpath="${BATOCERA_BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BATOCERA_BINARIES_DIR}/genimage-boot.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
    "${HOST_DIR}/bin/syslinux" -i "${BATOCERA_BINARIES_DIR}/boot.vfat" -d "/boot/syslinux" || exit 1
    # remove genimage temp path as sometimes genimage v14 fails to start
    rm -rf ${GENIMAGE_TMP}
    mkdir ${GENIMAGE_TMP}
    fi
    ###
    "${HOST_DIR}/bin/genimage" --rootpath="${TARGET_DIR}" --inputpath="${BATOCERA_BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BATOCERA_BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1

    rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
    rm -f "${BATOCERA_BINARIES_DIR}/userdata.ext4" || exit 1
    rm -f "${BATOCERA_BINARIES_DIR}/system.ext4" || exit 1
    if test "${BATOCERA_SUBTARGET}" = "x86-64-v3"
    then
	rm -rf "${TARGET_DIR}/system" || exit 1
    fi
    mv "${BATOCERA_BINARIES_DIR}/batocera.img" "${BATOCERAIMG}" || exit 1
    gzip "${BATOCERAIMG}" || exit 1

    # rename the boot to boot_arch
    mv "${BATOCERA_BINARIES_DIR}/boot" "${BOOTNAMEDDIR}" || exit 1

    # copy the version file needed for version check
    cp "${TARGET_DIR}/usr/share/batocera/batocera.version" "${BATOCERA_BINARIES_DIR}/images/${BATOCERA_SUBTARGET}" || exit 1
done

#### md5 and sha256 #######################
for FILE in "${BATOCERA_BINARIES_DIR}/images/"*"/update.tar" "${BATOCERA_BINARIES_DIR}/images/"*"/boot.tar.xz" "${BATOCERA_BINARIES_DIR}/images/"*"/batocera-"*".img.gz"
do
    test -f "${FILE}" || continue
    echo "creating ${FILE}.md5"
    CKS=$(md5sum "${FILE}" | sed -e s+'^\([^ ]*\) .*$'+'\1'+)
    echo "${CKS}" > "${FILE}.md5"
    echo "${CKS}  $(basename "${FILE}")" >> "${BATOCERA_BINARIES_DIR}/MD5SUMS"
    echo "creating ${FILE}.sha256"
    CKS=$(sha256sum "${FILE}" | sed -e s+'^\([^ ]*\) .*$'+'\1'+)
    echo "${CKS}" > "${FILE}.sha256"
    echo "${CKS}  $(basename "${FILE}")" >> "${BATOCERA_BINARIES_DIR}/SHA256SUMS"
done

#### update the target dir with some information files
cp "${TARGET_DIR}/usr/share/batocera/batocera.version" "${BATOCERA_BINARIES_DIR}" || exit 1
"${BR2_EXTERNAL_BATOCERA_PATH}"/scripts/linux/systemsReport.sh "${PWD}" "${BATOCERA_BINARIES_DIR}" || exit 1
