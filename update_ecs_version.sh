#!/bin/bash

usage() { echo "Usage: ${0} 'ecs_version' 'ecs_tag' 'file of pkg directories'" 1>&2; exit 1; }

if [[ ${#} -ne 3 ]]; then
    usage ${0}
fi

ECS_VERSION="$1"
ECS_TAG="$2"
PKG_DIRS="$3"
UPDATED_PKGS=""
PR_BODY=""
PR_URL=""

for PKG_DIR in $(cat $PKG_DIRS)
do
    BUILD_FILE="$PKG_DIR"/_dev/build/build.yml

    if [ ! -f "$BUILD_FILE" ]; then
	echo "$BUILD_FILE doesn't exist" >&2
	continue
    fi

    HAS_DEP_KEY=$(yq '. | has("dependencies")' "$BUILD_FILE")
    if [ "$HAS_DEP_KEY" != "true" ]; then
	echo "$BUILD_FILE doesn't have dependencies key" >&2
	continue
    fi

    HAS_ECS_KEY=$(yq '.dependencies | has("ecs")' "$BUILD_FILE")
    if [ "$HAS_ECS_KEY" != "true" ]; then
	echo "$BUILD_FILE doesn't have ecs key" >&2
	continue
    fi

    HAS_REF_KEY=$(yq '.dependencies.ecs | has("reference")' "$BUILD_FILE")
    if [ "$HAS_REF_KEY" != "true" ]; then
	echo "$BUILD_FILE doesn't have reference key" >&2
	continue
    fi

    yq -i e ".dependencies.ecs.reference = \"${ECS_TAG}\"" "$BUILD_FILE"

    for DATA_STREAM in $(find "$PKG_DIR"/data_stream -type d -depth 1)
    do
	for PIPELINE in $(find "$DATA_STREAM"/elasticsearch/ingest_pipeline -type f -name '*.yml')
	do
	    # yq reformats some of the yml files and we don't want that, we should clean up
	    # pipelines so we can use this yq command, much more precise than perl below
	    #yq -i e "(.processors[] | select(.set.field == \"ecs.version\") | .set.value) = \"${ECS_VERSION}\"" "$PIPELINE"
	    perl -i -0pe "s/(ecs\.version\s*value:)(.*?\n)/\1 \'${ECS_VERSION}\'\n/s" "$PIPELINE"
	done
    done

    PKG_NAME=$(basename $PKG_DIR)
    GIT_STATUS=$(git status --porcelain)
    if [[ ! $GIT_STATUS ]]; then
	echo "No change for $PKG_NAME" >&2
	continue
    fi
    GIT_COMMIT=$(git commit -a -q -m "Update ECS version for $PKG_NAME" -m "ECS version updated to $ECS_VERSION")
    PR_BODY=$(printf '+ %s\n%s' "${PKG_NAME}" "${PR_BODY}")
    UPDATED_PKGS=$(printf '%s\n%s' "${PKG_DIR}" "${UPDATED_PKGS}")
done

if [[ -z "$UPDATED_PKGS" ]]; then
    exit
fi

GIT_PUSH=$(git push -u leehinman)
PR_URL=$(gh pr create --draft --title="Update ECS to ${ECS_VERSION}" --body="${PR_BODY}" --label='enhancement,Team:Security-External Integrations')

for PKG in ${UPDATED_PKGS}
do
    printf '{"pkg_dir": "%s", "ecs_version": "%s", "pr_url": "%s"}\n' "${PKG}" "${ECS_VERSION}" "${PR_URL}"
done
