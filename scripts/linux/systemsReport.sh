#!/bin/bash

ARCHS="x86_64 odroidxu4 bcm2835 bcm2836 bcm2837 bcm2711 bcm2712 rk3128 rk3288 rk3326 rk3328 rk3399 rk3568 rk3588 rk3588-sdio s812 s905 s905gen2 s905gen3 s9gen4 s922x a3gen2 h3 h5 h6 h616 h700 jh7110 qcs6490 sm8250 sm8550 zen3"

BR_DIR=$1
BATOCERA_BINARIES_DIR=$2
if ! test -d "${BR_DIR}"
then
    echo "${0} <BR_DIR>" >&2
    exit 1
fi

# create temporary directory
TMP_DIR="/tmp/br_systemreport_${$}"
mkdir -p "${TMP_DIR}" || exit 1

# create configs files
for ARCH in ${ARCHS}
do
    echo "generating .config for ${ARCH}" >&2
    TMP_CONFIG="${TMP_DIR}/configs_tmp/${ARCH}"
    TMP_CONFIGS="${TMP_DIR}/configs"
    mkdir -p "${TMP_CONFIG}" "${TMP_CONFIGS}" || exit 1

    if ! test -e "${BR2_EXTERNAL_BATOCERA_PATH}/configs/batocera-${ARCH}.board"
    then
	echo "skipping ${ARCH}: board file not found" >&2
	continue
    fi

    # generate the defconfig
    if ! "${BR2_EXTERNAL_BATOCERA_PATH}/configs/createDefconfig.sh" "${BR2_EXTERNAL_BATOCERA_PATH}/configs/batocera-${ARCH}"
    then
	echo "skipping ${ARCH}: defconfig generation failed" >&2
	continue
    fi

    if ! (make O="${TMP_CONFIG}" -C ${BR_DIR} BR2_EXTERNAL="${BR2_EXTERNAL_BATOCERA_PATH}" "batocera-${ARCH}_defconfig" > /dev/null)
    then
	echo "skipping ${ARCH}: Buildroot defconfig target failed" >&2
	continue
    fi
    cp "${TMP_CONFIG}/.config" "${TMP_CONFIGS}/config_${ARCH}" || exit 1
done

if ! compgen -G "${TMP_CONFIGS}/config_*" > /dev/null
then
    echo "no generated configs for systems report" >&2
    exit 1
fi

# reporting
ES_YML="${BR2_EXTERNAL_BATOCERA_PATH}/package/batocera/emulationstation/batocera-es-system/es_systems.yml"
EXP_YML="${BR2_EXTERNAL_BATOCERA_PATH}/package/batocera/emulationstation/batocera-es-system/systems-explanations.yml"
PYGEN="${BR2_EXTERNAL_BATOCERA_PATH}/package/batocera/emulationstation/batocera-es-system/batocera-report-system.py"
HTML_GEN="${BR2_EXTERNAL_BATOCERA_PATH}/package/batocera/emulationstation/batocera-es-system/batocera_systemsReport.html"
DEFAULTSDIR="${BR2_EXTERNAL_BATOCERA_PATH}/package/batocera/core/batocera-configgen/configs"
mkdir -p "${BATOCERA_BINARIES_DIR}" || exit 1
echo python "${PYGEN}" "${ES_YML}" "${EXP_YML}" "${DEFAULTSDIR}" "${TMP_CONFIGS}"
python "${PYGEN}" "${ES_YML}" "${EXP_YML}" "${DEFAULTSDIR}" "${TMP_CONFIGS}" > "${BATOCERA_BINARIES_DIR}/batocera_systemsReport.json" || exit 1
cp "${HTML_GEN}" "${BATOCERA_BINARIES_DIR}" || exit 1

rm -rf "${TMP_DIR}"
exit 0
