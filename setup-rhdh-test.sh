#!/bin/bash

# working directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${BASE_DIR}/.." && pwd)"
# backup directory name that is overridden by the current date and time in later steps
BACKUP_DIR=temp

# load configuration variables to set up the test environment
source "${BASE_DIR}/config_localtest.sh"

# displays menu to choose
display_menu() {
  echo "Select an option:"
  echo "1) Clone [${REPO_NAME}:${BRANCH}] into [${PARENT_DIR}/${WORK_DIR}] and use [image: '${QUAY_REPO}:${TAG_NAME}'], [cluster: $LOCAL_TEST_CLUSTER_NAME] to run tests"
  echo "2) Clone [${REPO_NAME}:${BRANCH_2}] into [${PARENT_DIR}/${REPO_NAME}-${BRANCH_2}] and use [image: '${QUAY_REPO_2}:${TAG_NAME_2}'], [cluster: $LOCAL_TEST_CLUSTER_NAME] to run tests"
  echo "3) Clone [${REPO_NAME}:${BRANCH_2}] into [${PARENT_DIR}/${REPO_NAME}-${BRANCH_2}] and use [image: '${QUAY_REPO_2}:${TAG_NAME_2}'], [cluster: $LOCAL_TEST_CLUSTER_NAME_2] to run tests"
  echo "-------------------------------------------------------------------------"
  echo "x) Exit the program"
}

# Function to handle the selected option
run_option() {
  case $1 in
      1)  
          echo "[INFO]: Clone [${REPO_NAME}:main] and set up test environment at [${PARENT_DIR}/${WORK_DIR}]. [image: '${QUAY_REPO}:${TAG_NAME}'],[cluster: $LOCAL_TEST_CLUSTER_NAME] will be used to run tests"
          main $1
          ;;
      2)
          WORK_DIR=${REPO_NAME}-${BRANCH_2}
          BRANCH="${BRANCH_2}"
          QUAY_REPO=${QUAY_REPO_2}
          TAG_NAME=${TAG_NAME_2}
          
          echo "[INFO]: Clone [${REPO_NAME}:${BRANCH}] and set up test environment at [${PARENT_DIR}/${WORK_DIR}]. [Image: '${QUAY_REPO}:${TAG_NAME}'], [cluster: $LOCAL_TEST_CLUSTER_NAME] will be used to run tests"
          main $1
          ;;
      3)
          WORK_DIR=${REPO_NAME}-${BRANCH_2}
          BRANCH="${BRANCH_2}"
          QUAY_REPO=${QUAY_REPO_2}
          TAG_NAME=${TAG_NAME_2}

          K8S_CLUSTER_URL=${K8S_CLUSTER_URL_2}
          K8S_CLUSTER_TOKEN=${K8S_CLUSTER_TOKEN_2}
          BASE_URL=${BASE_URL_2}
          BASE_RBAC_URL=${BASE_RBAC_URL_2}
          LOCAL_TEST_CLUSTER_NAME=${LOCAL_TEST_CLUSTER_NAME_2}

          echo "[INFO]: Clone [${REPO_NAME}:${BRANCH}] and set up test environment at [${PARENT_DIR}/${WORK_DIR}]. [Image: '${QUAY_REPO}:${TAG_NAME}'], [cluster: $LOCAL_TEST_CLUSTER_NAME_2] will be used to run tests"
          main $1
          ;;
      x)
          echo "[INFO]: Exit this program with no-op"
          ;;
      *)
          echo "[INFO]: Invalid option. Please try again."
          ;;
  esac
}

clone_backstage() {
  current_date=$(date +"%Y%m%d")
  current_time=$(date +"%H%M%S")

  BACKUP_DIR=${WORK_DIR}-$current_date-$current_time

  cd ${PARENT_DIR}

  # backup existing directory
  if [ -d "${WORK_DIR}" ]; then
    
    echo "[INFO]: Back up '${WORK_DIR}' into '${BACKUP_DIR}' before clone."
    mv "${WORK_DIR}" "${BACKUP_DIR}"
  else
      echo "[INFO]: Directory '${WORK_DIR}' does not exist."
  fi

  git clone -b ${BRANCH} ${REPO_URL} ${WORK_DIR}

  cd ${PARENT_DIR}/${WORK_DIR}

  # set GH push default 
  git remote add $GITHUB_USER_FORK_NAME $GITHUB_USER_REPO_URL
  git config remote.pushDefault $GITHUB_USER_FORK_NAME
}

# Copy required utility files for e2e tests
copy_and_update_util_files() {

  cp -r ${BASE_DIR}/files/.ibm/pipelines/* "${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines"
    
  echo "[INFO]: -----------------------------------------------"
  echo "[INFO]: variables used for the local test environment..."
  echo "[INFO]: PARENT_DIR:        ${PARENT_DIR}"
  echo "[INFO]: WORK_DIR:          ${WORK_DIR}"
  echo "[INFO]: BACKUP_DIR:        ${BACKUP_DIR}"
  echo "[INFO]: REPOSITORY:BRANCH: ${REPO_NAME}:${BRANCH}"
  echo "[INFO]: RHDH IMAGE:        ${QUAY_REPO}:${TAG_NAME}"
  echo "[INFO]: -----------------------------------------------"
  echo "[INFO]: TEST CLUSTER NAME: ${LOCAL_TEST_CLUSTER_NAME}"
  echo "[INFO]: K8S_CLUSTER_URL:   ${K8S_CLUSTER_URL}"
  echo "[INFO]: BASE_URL:          ${BASE_URL}"
  echo "[INFO]: BASE_RBAC_URL:     ${BASE_RBAC_URL}"
  echo "[INFO]: -----------------------------------------------"
  
  # macOS sed command requires an empty string for backup file
  # Linux: remove '' from sed commands in this file
  sed -i '' "s|QUAY_REPO=.*|QUAY_REPO=\"${QUAY_REPO}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables_1.4.sh
  sed -i '' "s|TAG_NAME=.*|TAG_NAME=\"${TAG_NAME}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables_1.4.sh  
  sed -i '' "s|K8S_CLUSTER_URL=.*|K8S_CLUSTER_URL=\"${K8S_CLUSTER_URL}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables_1.4.sh
  sed -i '' "s|K8S_CLUSTER_TOKEN=.*|K8S_CLUSTER_TOKEN=\"${K8S_CLUSTER_TOKEN}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables_1.4.sh
  
  sed -i '' "s|QUAY_REPO=.*|QUAY_REPO=\"${QUAY_REPO}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables.sh
  sed -i '' "s|TAG_NAME=.*|TAG_NAME=\"${TAG_NAME}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables.sh  
  sed -i '' "s|K8S_CLUSTER_URL=.*|K8S_CLUSTER_URL=\"${K8S_CLUSTER_URL}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables.sh
  sed -i '' "s|K8S_CLUSTER_TOKEN=.*|K8S_CLUSTER_TOKEN=\"${K8S_CLUSTER_TOKEN}\"|" ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines/local_env_variables.sh
  
  # update 'playwright.config.ts' by adding 'import dotenv' and 'dotenv.config({ path: ".env" });'
  sed -i '' "2i\\
import dotenv from \"dotenv\";\\
dotenv.config({ path: \"${PARENT_DIR}/.env\" });" ${PARENT_DIR}/${WORK_DIR}/e2e-tests/playwright.config.ts

  echo "[INFO]: updating '${PARENT_DIR}/${WORK_DIR}/e2e-tests/playwright.config.ts' - setting 'process.env.BASE_URL'(${BASE_URL})"
  sed -i '' "s|process.env.BASE_URL|\"${BASE_URL}\"|" ${PARENT_DIR}/${WORK_DIR}/e2e-tests/playwright.config.ts
}
  
# Install dotenv package. 
# This enables reading environment variables from '.env' file. 
# '.env' contains sensitive information obtained from Vault
install_dotenv() {
  cd ${PARENT_DIR}/${WORK_DIR}/e2e-tests
  npm install dotenv --legacy-peer-deps
  npm audit fix --force
}

main() {
  cd ${PARENT_DIR}
  clone_backstage 

  # copy and update utility files
  copy_and_update_util_files $1

  # install dotenv package. This can be commentted out if dotenv is already installed.
  install_dotenv  
  cd ${PARENT_DIR}/${WORK_DIR}/.ibm/pipelines
}

# ----------- Start of the script run -----------
display_menu

DEFAULT_CHOICE="1"
read -p "Enter your choice [${DEFAULT_CHOICE}]: " CHOICE
CHOICE=${CHOICE:-$DEFAULT_CHOICE}

run_option "$CHOICE"
