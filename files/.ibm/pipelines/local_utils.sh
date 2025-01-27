#!/bin/bash

export VAULT_SECRETS_DIR="/tmp/secrets"
export VAULT_URL=https://vault.ci.openshift.org

configure_external_postgres_db() {
  local project=$1
  oc apply -f "${DIR}/resources/postgres-db/postgres.yaml" --namespace="${NAME_SPACE_POSTGRES_DB}"
  sleep 5

  oc get secret postgress-external-db-cluster-cert -n "${NAME_SPACE_POSTGRES_DB}" -o jsonpath='{.data.ca\.crt}' | base64 --decode > postgres-ca
  oc get secret postgress-external-db-cluster-cert -n "${NAME_SPACE_POSTGRES_DB}" -o jsonpath='{.data.tls\.crt}' | base64 --decode > postgres-tls-crt
  oc get secret postgress-external-db-cluster-cert -n "${NAME_SPACE_POSTGRES_DB}" -o jsonpath='{.data.tls\.key}' | base64 --decode > postgres-tsl-key

  oc create secret generic postgress-external-db-cluster-cert \
  --from-file=ca.crt=postgres-ca \
  --from-file=tls.crt=postgres-tls-crt \
  --from-file=tls.key=postgres-tsl-key \
  --dry-run=client -o yaml | oc apply -f - --namespace="${project}"

  POSTGRES_PASSWORD=$(oc get secret/postgress-external-db-pguser-janus-idp -n "${NAME_SPACE_POSTGRES_DB}" -o jsonpath={.data.password})
  sed -i '' "s|POSTGRES_PASSWORD:.*|POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}|g" "${DIR}/resources/postgres-db/postgres-cred.yaml"
  POSTGRES_HOST=$(echo -n "postgress-external-db-primary.$NAME_SPACE_POSTGRES_DB.svc.cluster.local" | base64 | tr -d '\n')
  sed -i '' "s|POSTGRES_HOST:.*|POSTGRES_HOST: ${POSTGRES_HOST}|g" "${DIR}/resources/postgres-db/postgres-cred.yaml"
  oc apply -f "${DIR}/resources/postgres-db/postgres-cred.yaml"  --namespace="${project}"
}

apply_yaml_files() {
  local dir=$1
  local project=$2
  local rhdh_base_url=$3
  echo "Applying YAML files to namespace ${project}"

  oc config set-context --current --namespace="${project}"

  local files=(
      "$dir/resources/service_account/service-account-rhdh.yaml"
      "$dir/resources/cluster_role_binding/cluster-role-binding-k8s.yaml"
      "$dir/resources/cluster_role/cluster-role-k8s.yaml"
      "$dir/resources/cluster_role/cluster-role-ocm.yaml"
      "$dir/auth/secrets-rhdh-secrets.yaml"
    )

    for file in "${files[@]}"; do
      sed -i '' "s/namespace:.*/namespace: ${project}/g" "$file"
    done

    DH_TARGET_URL=$(echo -n "test-backstage-customization-provider-${project}.${K8S_CLUSTER_ROUTER_BASE}" | base64 | tr -d '\n')
    local RHDH_BASE_URL=$(echo -n "$rhdh_base_url" | base64 | tr -d '\n')

    for key in GITHUB_APP_APP_ID GITHUB_APP_CLIENT_ID GITHUB_APP_PRIVATE_KEY GITHUB_APP_CLIENT_SECRET GITHUB_APP_JANUS_TEST_APP_ID GITHUB_APP_JANUS_TEST_CLIENT_ID GITHUB_APP_JANUS_TEST_CLIENT_SECRET GITHUB_APP_JANUS_TEST_PRIVATE_KEY GITHUB_APP_WEBHOOK_URL GITHUB_APP_WEBHOOK_SECRET KEYCLOAK_CLIENT_SECRET ACR_SECRET GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET K8S_CLUSTER_TOKEN_ENCODED OCM_CLUSTER_URL GITLAB_TOKEN KEYCLOAK_AUTH_BASE_URL KEYCLOAK_AUTH_CLIENTID KEYCLOAK_AUTH_CLIENT_SECRET KEYCLOAK_AUTH_LOGIN_REALM KEYCLOAK_AUTH_REALM RHDH_BASE_URL DH_TARGET_URL; do
      sed -i '' "s|${key}:.*|${key}: ${!key}|g" "$dir/auth/secrets-rhdh-secrets.yaml"
    done

    oc apply -f "$dir/resources/service_account/service-account-rhdh.yaml" --namespace="${project}"
    oc apply -f "$dir/auth/service-account-rhdh-secret.yaml" --namespace="${project}"
    oc apply -f "$dir/auth/secrets-rhdh-secrets.yaml" --namespace="${project}"

    oc apply -f "$dir/resources/cluster_role/cluster-role-k8s.yaml" --namespace="${project}"
    oc apply -f "$dir/resources/cluster_role_binding/cluster-role-binding-k8s.yaml" --namespace="${project}"
    oc apply -f "$dir/resources/cluster_role/cluster-role-ocm.yaml" --namespace="${project}"
    oc apply -f "$dir/resources/cluster_role_binding/cluster-role-binding-ocm.yaml" --namespace="${project}"

    sed -i '' "s/K8S_CLUSTER_API_SERVER_URL:.*/K8S_CLUSTER_API_SERVER_URL: ${K8S_CLUSTER_API_SERVER_URL}/g" "$dir/auth/secrets-rhdh-secrets.yaml"

    sed -i '' "s/K8S_CLUSTER_NAME:.*/K8S_CLUSTER_NAME: ${ENCODED_CLUSTER_NAME}/g" "$dir/auth/secrets-rhdh-secrets.yaml"

    token=$(oc get secret rhdh-k8s-plugin-secret -n "${project}" -o=jsonpath='{.data.token}')
    sed -i '' "s/OCM_CLUSTER_TOKEN: .*/OCM_CLUSTER_TOKEN: ${token}/" "$dir/auth/secrets-rhdh-secrets.yaml"

    # Select the configuration file based on the namespace or job
    config_file=$(select_config_map_file)
    # Apply the ConfigMap with the correct file
    if [[ "${project}" == *showcase-k8s* ]]; then
      create_app_config_map_k8s "$config_file" "$project"
    else
      create_app_config_map "$config_file" "$project"
    fi
    oc create configmap dynamic-homepage-and-sidebar-config \
      --from-file="dynamic-homepage-and-sidebar-config.yaml"="$dir/resources/config_map/dynamic-homepage-and-sidebar-config.yaml" \
      --namespace="${project}" \
      --dry-run=client -o yaml | oc apply -f -
    oc create configmap rbac-policy \
      --from-file="rbac-policy.csv"="$dir/resources/config_map/rbac-policy.csv" \
      --namespace="$project" \
      --dry-run=client -o yaml | oc apply -f -

    oc apply -f "$dir/auth/secrets-rhdh-secrets.yaml" --namespace="${project}"

    # [Required] this is required to pull the RHDH container image from 'rhdh-community/rhdh:next' to be used in the local test 
    oc apply -f "$dir/auth/rhdh-pull-secret.yaml" --namespace="${project}"

    # Create Pipeline run for tekton test case.
    oc apply -f "$dir/resources/pipeline-run/hello-world-pipeline.yaml"
    oc apply -f "$dir/resources/pipeline-run/hello-world-pipeline-run.yaml"
}

# Installs the Red Hat OpenShift Pipelines operator if not already installed
install_pipelines_operator() {
  DISPLAY_NAME="Red Hat OpenShift Pipelines"
  # Check if operator is already installed
  if oc get csv -n "openshift-operators" | grep -q "${DISPLAY_NAME}"; then
    echo "Red Hat OpenShift Pipelines operator is already installed."
  else
    echo "Red Hat OpenShift Pipelines operator is not installed. Installing..."
    # Install the operator and wait for deployment
    install_subscription openshift-pipelines-operator openshift-operators openshift-pipelines-operator-rh latest redhat-operators
    wait_for_deployment "openshift-operators" "pipelines"
    # timeout 300 bash -c '
    # while ! oc get svc tekton-pipelines-webhook -n openshift-pipelines &> /dev/null; do
    #     echo "Waiting for tekton-pipelines-webhook service to be created..."
    #     sleep 5
    # done
    # echo "Service tekton-pipelines-webhook is created."
    # ' || echo "Error: Timed out waiting for tekton-pipelines-webhook service creation."
  fi
}

initiate_deployments() {
  if [[ "$1" == "1" || "$1" == "11" ]]; then
    echo "Initiating deployment for RHDH"

    uninstall_helmchart "${NAME_SPACE}" "${RELEASE_NAME}"
    configure_namespace "${NAME_SPACE}"

    # Deploy redis cache db.
    oc apply -f "$DIR/resources/redis-cache/redis-deployment.yaml" --namespace="${NAME_SPACE}"

    cd "${DIR}"
    local rhdh_base_url="https://${RELEASE_NAME}-backstage-${NAME_SPACE}.${K8S_CLUSTER_ROUTER_BASE}"
    apply_yaml_files "${DIR}" "${NAME_SPACE}" "${rhdh_base_url}"
    echo "Deploying image from repository: ${QUAY_REPO}, TAG_NAME: ${TAG_NAME}, in NAME_SPACE: ${NAME_SPACE}"
    helm upgrade -i "${RELEASE_NAME}" -n "${NAME_SPACE}" "${HELM_REPO_NAME}/${HELM_IMAGE_NAME}" --version "${CHART_VERSION}" -f "${DIR}/value_files/${HELM_CHART_VALUE_FILE_NAME}" --set global.clusterRouterBase="${K8S_CLUSTER_ROUTER_BASE}" --set upstream.backstage.image.repository="${QUAY_REPO}" --set upstream.backstage.image.tag="${TAG_NAME}" --set upstream.backstage.image.pullSecrets[0]=rhdh-pull-secret
  fi

  if [[ "$1" == "1" || "$1" == "12" ]]; then
    echo "Initiating deployment for RBAC"

    uninstall_helmchart "${NAME_SPACE_RBAC}" "${RELEASE_NAME_RBAC}"
    uninstall_helmchart "${NAME_SPACE_POSTGRES_DB}" "${NAME_POSTGRES_DB}"
    configure_namespace "${NAME_SPACE_POSTGRES_DB}"
    configure_namespace "${NAME_SPACE_RBAC}"
    configure_external_postgres_db "${NAME_SPACE_RBAC}"

    # Initiate rbac instace deployment.
    local rbac_rhdh_base_url="https://${RELEASE_NAME_RBAC}-backstage-${NAME_SPACE_RBAC}.${K8S_CLUSTER_ROUTER_BASE}"
    apply_yaml_files "${DIR}" "${NAME_SPACE_RBAC}" "${rbac_rhdh_base_url}"
    echo "Deploying image from repository: ${QUAY_REPO}, TAG_NAME: ${TAG_NAME}, in NAME_SPACE: ${RELEASE_NAME_RBAC}"
    helm upgrade -i "${RELEASE_NAME_RBAC}" -n "${NAME_SPACE_RBAC}" "${HELM_REPO_NAME}/${HELM_IMAGE_NAME}" --version "${CHART_VERSION}" -f "${DIR}/value_files/${HELM_CHART_RBAC_VALUE_FILE_NAME}" --set global.clusterRouterBase="${K8S_CLUSTER_ROUTER_BASE}" --set upstream.backstage.image.repository="${QUAY_REPO}" --set upstream.backstage.image.tag="${TAG_NAME}" --set upstream.backstage.image.pullSecrets[0]=rhdh-pull-secret
  fi
}

initiate_rds_deployment() {
  local release_name=$1
  local namespace=$2
  uninstall_helmchart "${namespace}" "${release_name}"
  configure_namespace "${namespace}"
  sed -i '' "s|POSTGRES_USER:.*|POSTGRES_USER: $RDS_USER|g" "${DIR}/resources/postgres-db/postgres-cred.yaml"
  sed -i '' "s|POSTGRES_PASSWORD:.*|POSTGRES_PASSWORD: $(echo -n $RDS_PASSWORD | base64 | tr -d '\n')|g" "${DIR}/resources/postgres-db/postgres-cred.yaml"
  sed -i '' "s|POSTGRES_HOST:.*|POSTGRES_HOST: $(echo -n $RDS_1_HOST | base64 | tr -d '\n')|g" "${DIR}/resources/postgres-db/postgres-cred.yaml"
  oc apply -f "$DIR/resources/postgres-db/postgres-crt-rds.yaml" -n "${namespace}"
  oc apply -f "$DIR/resources/postgres-db/postgres-cred.yaml" -n "${namespace}"
  oc apply -f "$DIR/resources/postgres-db/dynamic-plugins-root-PVC.yaml" -n "${namespace}"
  helm upgrade -i "${release_name}" -n "${namespace}" "${HELM_REPO_NAME}/${HELM_IMAGE_NAME}" --version "${CHART_VERSION}" -f "$DIR/resources/postgres-db/values-showcase-postgres.yaml" --set global.clusterRouterBase="${K8S_CLUSTER_ROUTER_BASE}" --set upstream.backstage.image.repository="${QUAY_REPO}" --set upstream.backstage.image.tag="${TAG_NAME}"
}

run_tests() {
  local release_name=$1
  local project=$2

  project=${project}
  cd "${DIR}/../../e2e-tests"
  yarn install
  yarn playwright install chromium

  # 
  # Xvfb :99 &
  # export DISPLAY=:99

  (
    set -e
    echo "Using PR container image: ${TAG_NAME}"
    
    if [[ "$1" == *"rbac"* ]]; then
      echo "[INFO]: starting tests with RHDH-RBAC"
      yarn showcase-rbac
    else 
      echo "[INFO]: starting tests with RHDH"
      yarn showcase

  ) 2>&1 | tee "/tmp/${LOGFILE}"

  local RESULT=${PIPESTATUS[0]}

  # pkill Xvfb

  mkdir -p "${ARTIFACT_DIR}/${project}/test-results"
  mkdir -p "${ARTIFACT_DIR}/${project}/attachments/screenshots"
  cp -a /tmp/rhdh/e2e-tests/test-results/* "${ARTIFACT_DIR}/${project}/test-results"
  cp -a /tmp/rhdh/e2e-tests/${JUNIT_RESULTS} "${ARTIFACT_DIR}/${project}/${JUNIT_RESULTS}"

  if [ -d "/tmp/rhdh/e2e-tests/screenshots" ]; then
    cp -a /tmp/rhdh/e2e-tests/screenshots/* "${ARTIFACT_DIR}/${project}/attachments/screenshots/"
  fi

  if [ -d "/tmp/rhdh/e2e-tests/auth-providers-logs" ]; then
    cp -a /tmp/rhdh/e2e-tests/auth-providers-logs/* "${ARTIFACT_DIR}/${project}/"
  fi

  ansi2html <"/tmp/${LOGFILE}" >"/tmp/${LOGFILE}.html"
  cp -a "/tmp/${LOGFILE}.html" "${ARTIFACT_DIR}/${project}"
  cp -a /tmp/rhdh/e2e-tests/playwright-report/* "${ARTIFACT_DIR}/${project}"

  # droute_send "${release_name}" "${project}"

  echo "${project} RESULT: ${RESULT}"
  if [ "${RESULT}" -ne 0 ]; then
    OVERALL_RESULT=1
  fi
}

check_and_test() {
  local release_name=$1
  local namespace=$2
  local url=$3
  
  if check_backstage_running "${release_name}" "${namespace}" "${url}"; then
    echo "Display pods for verification..."
    oc get pods -n "${namespace}"
    run_tests "${release_name}" "${namespace}"
  else
    echo "Backstage is not running. Exiting..."
    OVERALL_RESULT=1
  fi
  save_all_pod_logs $namespace
}

vault_login() {
    if ! vault token lookup &>/dev/null; then
        echo "Not logged into Vault. Logging in now..."
        vault login -address=${VAULT_URL} -method=oidc
    else
        echo "Already logged into Vault."
    fi
}

# get the values from vault and store them at ${VAULT_SECRETS_DIR}
# this is sufficient for running the showcase-e2e-runner
vault_write() {
    echo "write vault key values to ${VAULT_SECRETS_DIR}"
    
    vault_login

    rm -rf ${VAULT_SECRETS_DIR}
    mkdir ${VAULT_SECRETS_DIR}
    
    PROPERTIES_PATH="$(realpath "${DIR}/../../..")"
    PROPERTIES_FILE=${PROPERTIES_PATH}/.env
    BACKUP_PROPERTIES_FILE=${PROPERTIES_PATH}/.env.backup

    if [ -e "${PROPERTIES_PATH}/.env" ]; then
    #   echo "[INFO]: .env file does not exist - skipping the file backup."
    # else 
      echo "[INFO]: backup .env file to ${BACKUP_PROPERTIES_FILE}"
      mv $PROPERTIES_FILE $BACKUP_PROPERTIES_FILE
    fi
    
    # Path to the properties file
    # properties_file="${VAULT_SECRETS_DIR}/vault.properties"

    # Initialize the properties file
    : > "$PROPERTIES_FILE"  # Clear file or create a new one

    vault kv get -address=${VAULT_URL} -mount="kv" -format=json "selfservice/rhdh-qe/rhdh" | \
    jq -r '.data.data | to_entries | .[] | @base64' | \
    while IFS= read -r entry; do
        # Decode the base64 entry
        decoded=$(echo "$entry" | base64 --decode)
        key=$(echo "$decoded" | jq -r '.key')
        value=$(echo "$decoded" | jq -r '.value')

        # skip unnecessary keys
        if [[ $key != secretsync* ]]; then
            echo -n "$value" > "${VAULT_SECRETS_DIR}/$key"
            # Append the key-value pair to the properties file
            printf "%s=%s\n" "$key" "$value" >> "$PROPERTIES_FILE"
        fi
    done
}
