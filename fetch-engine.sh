#!/bin/sh
# Helper script used to check and update engine dependencies
# This should not be called manually

set -eu

command -v curl >/dev/null 2>&1 || command -v wget > /dev/null 2>&1 || { echo >&2 "The OpenRA mod SDK requires curl or wget."; exit 1; }
if command -v python3 >/dev/null 2>&1; then
	PYTHON="python3"
else
	command -v python >/dev/null 2>&1 || { echo >&2 "The OpenRA mod SDK requires python."; exit 1; }
	PYTHON="python"
fi

require_variables() {
	missing=""
	for i in "$@"; do
		eval check="\$$i"
		if [ -z "${check}" ]; then
			missing="${missing}   ${i}\n"
		fi
	done
	if [ -n "${missing}" ]; then
		printf "Required mod.config variables are missing:\n%sRepair your mod.config (or user.config) and try again.\n" "${missing}"
		exit 1
	fi
}

TEMPLATE_LAUNCHER=$(${PYTHON} -c "import os; print(os.path.realpath('$0'))")
TEMPLATE_ROOT=$(dirname "${TEMPLATE_LAUNCHER}")

# shellcheck source=mod.config
. "${TEMPLATE_ROOT}/mod.config"

if [ -f "${TEMPLATE_ROOT}/user.config" ]; then
	# shellcheck source=user.config
	. "${TEMPLATE_ROOT}/user.config"
fi

require_variables "MOD_ID" "ENGINE_VERSION" "ENGINE_DIRECTORY"

CURRENT_ENGINE_VERSION=""
if [ -f "${ENGINE_DIRECTORY}/VERSION" ]; then
	CURRENT_ENGINE_VERSION=$(cat "${ENGINE_DIRECTORY}/VERSION" 2> /dev/null || true)
fi

if [ -f "${ENGINE_DIRECTORY}/VERSION" ] && [ "${CURRENT_ENGINE_VERSION}" = "${ENGINE_VERSION}" ]; then
	exit 0
fi

if [ "${AUTOMATIC_ENGINE_MANAGEMENT}" = "True" ]; then
	require_variables "AUTOMATIC_ENGINE_SOURCE" "AUTOMATIC_ENGINE_EXTRACT_DIRECTORY" "AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME"

	echo "OpenRA engine version ${ENGINE_VERSION} is required."

	if [ -d "${ENGINE_DIRECTORY}" ]; then
		if [ "${CURRENT_ENGINE_VERSION}" != "" ]; then
			echo "Deleting engine version ${CURRENT_ENGINE_VERSION}."
		else
			echo "Deleting existing engine (unknown version)."
		fi
		rm -rf "${ENGINE_DIRECTORY}"
	fi

	echo "Downloading engine from ${AUTOMATIC_ENGINE_SOURCE} ..."
	if command -v curl >/dev/null 2>&1; then
		if ! curl -fsSL -o "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}" "${AUTOMATIC_ENGINE_SOURCE}"; then
			echo "Failed to download engine archive from ${AUTOMATIC_ENGINE_SOURCE}" >&2
			rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"
			exit 3
		fi
	else
		if ! wget -qO "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}" "${AUTOMATIC_ENGINE_SOURCE}"; then
			echo "Failed to download engine archive from ${AUTOMATIC_ENGINE_SOURCE}" >&2
			rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"
			exit 3
		fi
	fi

	if [ ! -s "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}" ]; then
		echo "Downloaded engine archive is empty or missing." >&2
		rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"
		exit 3
	fi

	command -v unzip >/dev/null 2>&1 || { echo >&2 "The OpenRA mod SDK requires unzip to extract the engine."; rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"; exit 1; }

	rm -rf "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}"
	mkdir -p "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}"
	if ! unzip -qq "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}" -d "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}"; then
		echo "Failed to extract engine archive." >&2
		rm -rf "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}"
		rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"
		exit 3
	fi

	# GitHub zipballs usually contain a single top-level directory (e.g. OpenRA-release-20231010)
	EXTRACTED_DIR=$(find "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}" -mindepth 1 -maxdepth 1 -type d | head -n 1)
	if [ -z "${EXTRACTED_DIR}" ]; then
		echo "Could not locate extracted engine directory under ${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}" >&2
		rm -rf "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}"
		rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"
		exit 3
	fi

	mv "${EXTRACTED_DIR}" "${ENGINE_DIRECTORY}"
	rm -rf "${AUTOMATIC_ENGINE_EXTRACT_DIRECTORY}"
	rm -f "${AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME}"

	echo "Compiling engine..."
	cd "${ENGINE_DIRECTORY}" || exit 1
	make version VERSION="${ENGINE_VERSION}"
	exit 0
fi

echo "Automatic engine management is disabled."
echo "Please manually update the engine to version ${ENGINE_VERSION}."
exit 1

