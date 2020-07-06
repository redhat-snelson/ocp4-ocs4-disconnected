#!/usr/bin/bash
oc image mirror \
    -a ${LOCAL_SECRET_JSON} \
    --dir=/tmp/mirror-file \
    file://openshift/release:4.3.3* \
    ${LOCAL_REGISTRY}/ocp-4.4
