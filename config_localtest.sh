#!/bin/bash

set -a  # Automatically export all variables

# --------------- SET YOUR OWN VARIABLES ---------------
## [1] Set your GitHub user id and fork name. These are used to clone the repository.
GITHUB_USER_ID="<replace-with-your-github-user-id>"
GITHUB_USER_FORK_NAME="<replace-with-your-github-fork>"
# e.g.
# GITHUB_USER_ID=josephca
# GITHUB_USER_FORK_NAME=my_fork
# ------------------------------------------------------
REPO_NAME=rhdh
REPO_URL="git@github.com:redhat-developer/${REPO_NAME}.git"
GITHUB_USER_REPO_URL="git@github.com:${GITHUB_USER_ID}/${REPO_NAME}.git"

# --------------- set variables for option #1: using 'main' branch and 'next' rhdh image ---------------
WORK_DIR="${REPO_NAME}"
QUAY_REPO="${QUAY_REPO:-rhdh-community/rhdh}"
TAG_NAME="${TAG_NAME:-next}"
BRANCH="${BRANCH:-main}"

# --------------- set variables for option #2,3: testing 'release-1.4' with '1.4' rhdh image ---------------
# quay repo: https://quay.io/repository/rhdh/rhdh-hub-rhel9?tab=tags&tag=1.4
QUAY_REPO_2="rhdh/rhdh-hub-rhel9"
TAG_NAME_2="1.4"
BRANCH_2="release-${TAG_NAME_2}"

# --------------- SET YOUR OWN VARIABLES ---------------
## [2] Set your test cluster variables
LOCAL_TEST_CLUSTER_NAME="<replace-with-your-custer-name>"
K8S_CLUSTER_URL="<replace-with-your-cluster-url>"
K8S_CLUSTER_TOKEN="<replace-with-your-cluster-token>"

# rhdh-RBAC instance on ${LOCAL_TEST_CLUSTER_NAME} cluster
BASE_RBAC_URL="<replace-with-your-base-url>"
# rhdh instance on ${LOCAL_TEST_CLUSTER_NAME} cluster
BASE_URL="<replace-with-your-base-url>"

## e.g.
## Default test cluster: 'rhdh-qe-2'. This is overridden by 'files/local_env_variables*.sh' -----------
# LOCAL_TEST_CLUSTER_NAME=rhdh-qe-2
# K8S_CLUSTER_URL="https://c109-e.us-east.containers.cloud.ibm.com:31502"
# K8S_CLUSTER_TOKEN="<replace-with-your-cluster-token>"

## rhdh-RBAC instance on ${LOCAL_TEST_CLUSTER_NAME} cluster
# BASE_RBAC_URL="https://rhdh-rbac-backstage-rhdh-joskim-rbac.rhdh-qe-2-a9805650830b22c3aee243e51d79565d-0000.us-east.containers.appdomain.cloud"
## rhdh instance on ${LOCAL_TEST_CLUSTER_NAME} cluster
# BASE_URL="https://rhdh-backstage-rhdh-joskim.rhdh-qe-2-a9805650830b22c3aee243e51d79565d-0000.us-east.containers.appdomain.cloud"
# ------------------------------------------------------

# --------------- SET YOUR OWN VARIABLES ---------------
# [Optional] Cluster bot cluster --------------- 
## [3] Set your optional test cluster variables
# e.g. 
# oc login --token=${K8S_CLUSTER_TOKEN_2} --server=https://api.miiqc-3yknd-xsp.rc9j.p3.openshiftapps.com:443
LOCAL_TEST_CLUSTER_SHORT_NAME_2="<replace-with-your-custer-name>"
LOCAL_TEST_CLUSTER_NAME_2="${LOCAL_TEST_CLUSTER_SHORT_NAME_2} with version openshift-v4.17.5"

K8S_CLUSTER_URL_2="https://api.${LOCAL_TEST_CLUSTER_SHORT_NAME_2}.p3.openshiftapps.com:443"
K8S_CLUSTER_TOKEN_2="<replace-with-your-custer-token>"

# set BASE_URL that is used in 'playwright.config.ts'. replace with your own URL if needed.
BASE_RBAC_URL_2="<replace-with-your-base-url>"
BASE_URL_2="<replace-with-your-base-url>"
## e.g.
# BASE_RBAC_URL_2="https://rhdh-rbac-backstage-rhdh-joskim-rbac.apps.rosa.${LOCAL_TEST_CLUSTER_SHORT_NAME_2}.openshiftapps.com"
# BASE_URL_2="https://rhdh-backstage-rhdh-joskim.apps.rosa.${LOCAL_TEST_CLUSTER_SHORT_NAME_2}.p3.openshiftapps.com"
# ------------------------------------------------------

set +a  # Stop automatically exporting variables
