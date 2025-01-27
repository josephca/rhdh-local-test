#!/bin/bash
set -a  # Automatically export all variables

# RHDH Image used for test: latest v1.4 
QUAY_REPO="${QUAY_REPO:-rhdh/rhdh-hub-rhel9}"
TAG_NAME="${TAG_NAME:-1.4}"

# --------------- SET YOUR OWN VARIABLES ---------------
## [1] Set your test cluster variables
K8S_CLUSTER_URL="<replace-with-your-cluster-url>"
K8S_CLUSTER_TOKEN="<replace-with-your-cluster-token>"
# e.g. 
# K8S_CLUSTER_URL="https://c109-e.us-east.containers.cloud.ibm.com:31502"
# K8S_CLUSTER_TOKEN="<replace-with-your-cluster-token>""
# ------------------------------------------------------

K8S_CLUSTER_API_SERVER_URL=$(printf "%s" "$K8S_CLUSTER_URL" | base64 | tr -d '\n')
K8S_CLUSTER_TOKEN_ENCODED=$(printf "%s" $K8S_CLUSTER_TOKEN | base64 | tr -d '\n')
K8S_SERVICE_ACCOUNT_TOKEN=$K8S_CLUSTER_TOKEN_ENCODED
RHDH_PR_OS_CLUSTER_TOKEN=${K8S_CLUSTER_TOKEN}
RHDH_PR_OS_CLUSTER_URL=${K8S_CLUSTER_URL}

# change them to use your own GITHUP_APP
# GITHUB_APP_CLIENT_ID=${GITHUB_APP_JANUS_TEST_APP_ID}
# GITHUB_APP_CLIENT_SECRET=${GITHUB_APP_JANUS_TEST_CLIENT_SECRET}

OCM_CLUSTER_URL=$(printf "%s" "$K8S_CLUSTER_URL" | base64 | tr -d '\n')
OCM_CLUSTER_TOKEN=$K8S_CLUSTER_TOKEN_ENCODED

# --------------- SET YOUR OWN VARIABLES ---------------
## [2] Set your namespace name
NAME_SPACE="<replace-with-your-name-space>"
# e.g. 
# NAME_SPACE=rhdh-joskim
# ------------------------------------------------------

NAME_SPACE_RBAC=${NAME_SPACE}-rbac
NAME_SPACE_POSTGRES_DB="${NAME_SPACE}-postgres-external-db"
NAME_POSTGRES_DB=postgres-external-db

set +a  # Stop automatically exporting variables
