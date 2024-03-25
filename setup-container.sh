#!/usr/bin/env bash

set -euo pipefail

NAME="ansible-test"
base_dir="$(pwd)"
TEMP_DIR=${base_dir}/temp

function cleanup() {
    container_id=$(docker inspect --format="{{.Id}}" "${NAME}" ||:)
    if [[ -n "${container_id}" ]]; then
        echo "Cleaning up container ${NAME}"
        docker rm --force "${container_id}"
    fi
    
    echo "Cleaning up tepdir ${TEMP_DIR}"
    rm -rf "${TEMP_DIR}"
}

function setup_tempdir() {
    mkdir -p "${TEMP_DIR}"
}

function create_temporary_ssh_id() {
    ssh-keygen -b 2048 -t rsa -C "${USER}@email.com" -f "${TEMP_DIR}/id_rsa" -N ""
    chmod 600 "${TEMP_DIR}/id_rsa"
    chmod 644 "${TEMP_DIR}/id_rsa.pub"
}

function start_container() {
    docker build --tag "compute-node-sim" \
    --build-arg USER \
    --file "${base_dir}/Dockerfile" \
    "${TEMP_DIR}"
    docker run -d -p 127.0.0.1:2222:22 --name "${NAME}" "compute-node-sim"
}

function setup_test_inventory() {
    TEMP_INVENTORY_FILE="${TEMP_DIR}/hosts"
    
    cat > "${TEMP_INVENTORY_FILE}" << EOL
[target_group]
127.0.0.1:2222
[target_group:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
EOL
    export TEMP_INVENTORY_FILE
}

function run_ansible_playbook() {
    ANSIBLE_CONFIG="${base_dir}/ansible.cfg"
    ansible-playbook -i "${TEMP_INVENTORY_FILE}" -vvv "${base_dir}/playbook.yml"
}

setup_tempdir
trap cleanup EXIT
trap cleanup ERR
create_temporary_ssh_id
start_container
setup_test_inventory
run_ansible_playbook