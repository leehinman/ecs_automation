#!/bin/bash

usage() { echo "Usage: ${0} 'file of ndjson pkg updates'" 1>&2; exit 1; }

if [[ $# -ne 1 ]]; then
    usage ${0}
fi

elastic-package stack up -d
eval "$(elastic-package stack shellinit)"
while read -r JSON
do
    PKG_DIR=$(echo "${JSON}"| jq .pkg_dir)
    ECS_VERSION=$(echo "${JSON}"| jq .ecs_version)
    PR_URL=$(echo "${JSON}"| jq .pr_url)
    (cd ${PKG_DIR} && elastic-package changelog add --link "${PR_URL}" --type "enhancement" --description "Update package to ECS ${ECS_VERSION}" --next minor)
    # build package for system tests
    (cd ${PKG_DIR} && elastic-package clean && elastic-package format && elastic-package build)
    (cd ${PKG_DIR} && elastic-package stack up -d --services package-registry)
    (cd ${PKG_DIR} && elastic-package test -g system && elastic-package test -g pipeline)
    # rebuild in case Readme was updated
    (cd ${PKG_DIR} && elastic-package clean && elastic-package format && elastic-package build)
    git commit -a -m "Updated Changelog, Manifest and tests for $PKG"
done < ${1}
elastic-package stack down
git push -f
