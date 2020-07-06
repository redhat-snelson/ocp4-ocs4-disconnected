#!/usr/bin/bash

OCP_VERSION="4.4"
OCP_RELEASE="4.4.5"
OCP_TAG="${OCP_VERSION}-x86_64"

LOCAL_REGISTRY="localhost:5000"
LOCAL_REPOS="ocp-${OCP_VERSION}"
PRODUCT_REPO="openshift-release-dev"
RELEASE_NAME="ocp-release"

AUTH_SECRET_FILE='../registry/pull-secret.json'
AUTH_FILE="${AUTH_SECRET_FILE}"

REGISTRY_CATALOG='file:/'
REGISTRY_MIRROR_='file:/'

OC='oc' #--loglevel=9'
OC_MIRROR="${OC} image mirror --insecure --registry-config=${AUTH_FILE}"
CATALOG_BUILD_="${OC} adm catalog build --insecure --registry-config=${AUTH_FILE}"
CATALOG_MIRROR="${OC} adm catalog mirror --insecure --registry-config=${AUTH_FILE}"

PASSHASH=$(echo -n 'snelson:password' | base64 -w0)

FUNC_OCP=false
FUNC_RH=true
FUNC_COMMUNITY=true
FUNC_MISSING=false

#cat > ${AUTH_SECRET_JSON}.local << EOF
#{
#    "auths": {
#        "${LOCAL_REGISTRY}": {
#            "auth": "${PASSHASH}",
#            "email": "snelson@redhat.com"
#        }
#    }
#}
#EOF

#jq ". += inputs" \
#    ${AUTH_SECRET_JSON} \
#    "{\"auths\":{\"${LOCAL_REGISTRY}\":{\"auth\":\"${PASSHASH}\",\"email\":\"${EMAIL}\"}}}" \
#    > ${NEW_AUTH_JSON}


### FUNCTIONS
function ocp4_mirror() {
    echo === OCP ${OCP_RELEASE} Mirror ===
    oc adm release mirror \
        --registry-config=${AUTH_SECRET_FILE} \
        --from=quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE}-x86_64 \
        --to-dir=ocp-${OCP_RELEASE}-mirror
}


function ocp4_installer() {
    oc adm release extract \
        --registry-config=${AUTH_SECRET_FILE} \
        --command=openshift-install \
        "${LOCAL_REGISTRY}/${LOCAL_REPO}:${OCP_TAG}"
}


function operator_rh() {
    ${CATALOG_BUILD_} \
        --appregistry-org redhat-operators \
        --from=registry.redhat.io/openshift4/ose-operator-registry:v${OCP_VERSION} \
        --to=${REGISTRY_CATALOG}/olm/redhat-operators:v1 \
        --filter-by-os="linux/amd64" \
        ${@}
}


function operator_rh_mirror() {
    ${CATALOG_MIRROR} \
        ${REGISTRY_CATALOG}/olm/redhat-operators:v1 \
        ${REGISTRY_MIRROR_} \
        --filter-by-os="linux/amd64" \
        ${@}
}


function operator_community() {
    ${CATALOG_BUILD_} \
        --appregistry-org community-operators \
        --from=quay.io/openshift/origin-operator-registry:latest \
        --to=${REGISTRY_CATALOG}/olm/community-operators:v1 \
        --filter-by-os="linux/amd64" \
        ${@}
}


function operator_community_mirror() {
    ${CATALOG_MIRROR} \
        ${REGISTRY_CATALOG}/olm/community-operators:v1 \
        ${REGISTRY_MIRROR_} \
        --filter-by-os="linux/amd64" \
        ${@}
}


function missing_ocs_mirror() {
    ${OC_MIRROR} \
        --dir=ocs-4.4-missing-mirror \
        -f mapping-missing.txt
}


### EXECUTE
if [ ${FUNC_RH} = true ]
then
    echo === RH Operators ===
    echo === Build ===
    operator_rh \
        --dir=rh-operators-${OCP_RELEASE}-catalog
    echo === Mirror ===
    operator_rh_mirror \
        --dir=rh-operators-${OCP_RELEASE}-mirror \
        --from-dir=rh-operators-${OCP_RELEASE}-catalog \
        --to-manifests=rh-operators-${OCP_RELEASE}-manifests --dry-run
fi

if [ ${FUNC_COMMUNITY} = true ]
then
    echo === Community Operators ===
    echo === Build ===
    operator_community \
        --dir=community-operators-${OCP_RELEASE}-catalog
    echo === Mirror ===
    operator_community_mirror
        --dir=community-operators-${OCP_RELEASE}-mirror \
        --from-dir=community-operators-${OCP_RELEASE}-catalog \
        --to-manifests=community-operators-${OCP_RELEASE}-manifests
fi

if [ ${FUNC_MISSING} = true ]
then
    echo === Missing OCS4 ===
    missing_ocs_mirror
fi

