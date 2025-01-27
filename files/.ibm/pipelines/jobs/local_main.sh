#!/bin/bash

handle_local_main() {
  echo "Configuring namespace: ${NAME_SPACE}"
  oc_login
  echo "OCP version: $(oc version)"

  export K8S_CLUSTER_ROUTER_BASE=$(oc get route console -n openshift-console -o=jsonpath='{.spec.host}' | sed 's/^[^.]*\.//')
  echo "[INFO]: K8S_CLUSTER_ROUTER_BASE: ${K8S_CLUSTER_ROUTER_BASE}"
  
  # Check if the input is one or two digits - deploy rhdh instance
  if [[ "$1" =~ ^[0-9]{1,2}$ ]]; then
    cluster_setup
    initiate_deployments $1
    # deploy_test_backstage_provider "${NAME_SPACE}"
  fi

  if [[ "$1" == "1" || "$1" == "11" || "$1" == "111" ]]; then
    local url="https://${RELEASE_NAME}-backstage-${NAME_SPACE}.${K8S_CLUSTER_ROUTER_BASE}"
    check_and_test "${RELEASE_NAME}" "${NAME_SPACE}" "${url}"
  fi

  if [[ "$1" == "1" || "$1" == "12" || "$1" == "121" ]]; then
    local rbac_url="https://${RELEASE_NAME_RBAC}-backstage-${NAME_SPACE_RBAC}.${K8S_CLUSTER_ROUTER_BASE}"
    check_and_test "${RELEASE_NAME_RBAC}" "${NAME_SPACE_RBAC}" "${rbac_url}"
  fi

  if [[ "$1" == "110" ]]; then
    uninstall_helmchart "${NAME_SPACE}" "${RELEASE_NAME}"
    echo "Deleting namespace: ${NAME_SPACE}"
    delete_namespace "${NAME_SPACE}"
  fi

  if [[ "$1" == "120" ]]; then
    uninstall_helmchart "${NAME_SPACE_RBAC}" "${RELEASE_NAME_RBAC}"
    uninstall_helmchart "${NAME_SPACE_POSTGRES_DB}" "${NAME_POSTGRES_DB}"
    echo "Deleting namespace: ${NAME_SPACE_RBAC}"
    delete_namespace "${NAME_SPACE_RBAC}"
    echo "Deleting namespace: ${NAME_SPACE_POSTGRES_DB}"
    delete_namespace "${NAME_SPACE_POSTGRES_DB}"
  fi
}
