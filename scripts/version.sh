#!/bin/bash

GO=${GO-go}
ARCH=${ARCH:-$("${GO}" env GOARCH)}
SUFFIX="-${ARCH}"
GIT_TAG=$DRONE_TAG
TREE_STATE=clean
COMMIT=$DRONE_COMMIT

if [ -d .git ]; then
    # We comment out the version tag bit as our versioning scheme is not liked by containerd and it fails to start
    # So we instead rely on the git commit hash to identify the k3s version running in the scale system
    # if [ -z "$GIT_TAG" ]; then
    #    GIT_TAG=$(git tag -l --contains HEAD | head -n 1)
    # fi
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        DIRTY="-dirty"
        TREE_STATE=dirty
    fi

    COMMIT=$(git log -n3 --pretty=format:"%H %ae" | grep -v ' drone@localhost$' | cut -f1 -d\  | head -1)
    if [ -z "${COMMIT}" ]; then
    COMMIT=$(git rev-parse HEAD || true)
    fi
fi

# We're building k3s against containerd 1.5 in go.mod because 1.6 has dependency
# conflicts with Kubernetes, but we still need to bundle containerd 1.6.
VERSION_CONTAINERD="truenas/v1.7.1-k3s1"

VERSION_CRICTL=$(grep github.com/kubernetes-sigs/cri-tools go.mod | head -n1 | awk '{print $4}')
if [ -z "$VERSION_CRICTL" ]; then
    VERSION_CRICTL="v0.0.0"
fi

VERSION_K8S_K3S=$(grep 'k8s.io/kubernetes =>' go.mod | head -n1 | awk '{print $4}')
VERSION_K8S=${VERSION_K8S_K3S%"-k3s1"}
if [ -z "$VERSION_K8S" ]; then
    VERSION_K8S="v0.0.0"
fi

VERSION_RUNC=$(grep github.com/opencontainers/runc go.mod | head -n1 | awk '{print $4}')
if [ -z "$VERSION_RUNC" ]; then
    VERSION_RUNC="v0.0.0"
fi

VERSION_FLANNEL=$(grep github.com/flannel-io/flannel go.mod | head -n1 | awk '{print $2}')
if [ -z "$VERSION_FLANNEL" ]; then
  VERSION_FLANNEL="v0.0.0"
fi

VERSION_CRI_DOCKERD=$(grep github.com/Mirantis/cri-dockerd go.mod | head -n1 | awk '{print $4}')
if [ -z "$VERSION_CRI_DOCKERD" ]; then
  VERSION_CRI_DOCKERD="v0.0.0"
fi

VERSION_CNIPLUGINS="v1.2.0-k3s1"

VERSION_KUBE_ROUTER=$(grep github.com/k3s-io/kube-router go.mod | head -n1 | awk '{print $4}')
if [ -z "$VERSION_KUBE_ROUTER" ]; then
    VERSION_KUBE_ROUTER="v0.0.0"
fi

VERSION_ROOT="v0.12.2"

if [[ -n "$GIT_TAG" ]]; then
    # We comment out this check so that we are able to use TN scale versioning scheme for k3s being shipped with tn scale releases
    # if [[ ! "$GIT_TAG" =~ ^"$VERSION_K8S"[+-] ]]; then
    #    echo "Tagged version '$GIT_TAG' does not match expected version '$VERSION_K8S[+-]*'" >&2
    #    exit 1
    # fi
    VERSION=$GIT_TAG
else
    VERSION="$VERSION_K8S+k3s-${COMMIT:0:8}$DIRTY"
fi
VERSION_TAG="$(sed -e 's/+/-/g' <<< "$VERSION")"
