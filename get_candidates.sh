#!/bin/bash

usage() { echo "Usage: ${0} 'integrations direcotry' 'team'" 1>&2; exit 1; }

if [[ ${#} -ne 2 ]]; then
    echo "Wrong number of arguments" 1>&2
    usage ${0}
fi

INT_DIR="${1}"
TEAM="${2}"

if [[ ! -d "${INT_DIR}/.git" ]]
then
    echo "${INT_DIR} needs to be in a git repo" 1>&2
    usage ${0}
fi

if [[ ! -d "${INT_DIR}/packages" ]]
then
    echo "${INT_DIR} needs to be an integrations repo" 1>&2
    usage ${0}
fi

for PKG_DIR in $(find ${INT_DIR}/packages -type d -depth 1 | sort)
do
    MANIFEST="${PKG_DIR}/manifest.yml"
    if [[ ! -f "${MANIFEST}" ]]
    then
	continue
    fi
    MATCH=$(yq ". | select(.owner.github == \"${TEAM}\") | select(.description != \"*Deprecated*\")" ${MANIFEST})
    if [[ ! ${MATCH} ]]
    then
	continue
    fi
    echo "$PKG_DIR"
done
