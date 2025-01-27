#!/bin/bash

set -e
export PS4='[$(date "+%Y-%m-%d %H:%M:%S")] ' # logs timestamp for every cmd.

# Define log file names and directories.
LOGFILE="test-log"
export DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OVERALL_RESULT=0

# Define a cleanup function to be executed upon script exit.
cleanup() {
  echo "Cleaning up before exiting"
  if [[ "$JOB_NAME" == *aks* && "${OPENSHIFT_CI}" == "true" ]]; then
    # If the job is for Azure Kubernetes Service (AKS), stop the AKS cluster.
    az_aks_stop "${AKS_NIGHTLY_CLUSTER_NAME}" "${AKS_NIGHTLY_CLUSTER_RESOURCEGROUP}"
  fi
  rm -rf ~/tmpbin
}

trap cleanup EXIT INT ERR

SCRIPTS=(
    "utils.sh"
    "local_utils.sh"
)

# Source each script dynamically
for SCRIPT in "${SCRIPTS[@]}"; do
    source "${DIR}/${SCRIPT}"
    echo "Loaded ${SCRIPT}"
done

vault_write

SCRIPTS_2=(
    "env_variables.sh" # load environment variables after loading variables from Vault by using 'vault_write'
    "local_env_variables.sh" # overrides variables in 'env_variables.sh'
    # "jobs/main.sh"
    "jobs/local_main.sh" # overrides 'jobs/main.sh'
)

# Source each script dynamically
for SCRIPT in "${SCRIPTS_2[@]}"; do
    source "${DIR}/${SCRIPT}"
    echo "Loaded ${SCRIPT}"
done

show_menu() {
  echo "Select an option:"
  echo "1)  [install + test]: install (RHDH, RHDH_RBAC) and run RHDH e2e tests"
  echo "11) [install + test]: install RHDH and run e2e tests"
  echo "12) [install + test]: install RHDH_RBAC and run e2e tests"
  echo "-------------------------------------------------------------------------"
  echo "111) [test] run RHDH e2e tests only (if RHDH is already installed)"
  echo "121) [test] run RHDH_RBAC e2e tests only (if RHDH_RBAC is already installed)"
  echo "-------------------------------------------------------------------------"
  echo "110) [uninstall] uninstall RHDH instance"
  echo "120) [uninstall] uninstall RHDH_RBAC instance"
  echo "-------------------------------------------------------------------------"
  echo "other) Exit the program"
}

# Function to handle the selected option
run_option() {
  case $1 in
      1)
          echo "[install + test]: install (RHDH, RHDH_RBAC) and run RHDH e2e tests"
          handle_local_main $1
          ;;
      11)
          echo "[install + test]: install RHDH and run e2e tests"
          handle_local_main $1
          ;;
      111)
          echo "[test] run RHDH e2e tests only (if RHDH is already installed)"
          handle_local_main $1
          ;;
      110)
          echo "[uninstall] uninstall RHDH instance"
          handle_local_main $1
          ;;
      12)
          echo "[install + test] install RHDH_RBAC and run e2e tests"
          handle_local_main $1
          ;;
      121)
          echo "[test] run RHDH_RBAC e2e tests only (if RHDH_RBAC is already installed)"
          handle_local_main $1
          ;;
      120)
          echo "[uninstall] uninstall RHDH_RBAC instance"
          handle_local_main $1
          ;;
      *)
          echo "Invalid option. Please select a valid option."
          ;;
  esac

  echo "Main script is completed with result: ${OVERALL_RESULT}"
  exit "${OVERALL_RESULT}"
}

show_menu
read -p "Enter your choice: " CHOICE
run_option $CHOICE
