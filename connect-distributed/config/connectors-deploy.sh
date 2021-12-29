#!/usr/bin/env bash
pushd . > /dev/null
cd $(dirname ${BASH_SOURCE[0]})
SCRIPT_DIR=$(pwd)
popd > /dev/null

CONNECT_REST_API_URL=${CONNECT_REST_API_URL:-http://localhost:8083}
KAFKA_BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"

function log () {
    local level="${1:?Requires log level as first parameter!}"
    local msg="${2:?Requires message as second parameter!}"
    echo -e "$(date --iso-8601=seconds)|${level}|${msg}"
}

function wait_until_available () {
    while [ $(curl -s -L -o /dev/null -w %{http_code} --max-time 60 ${CONNECT_REST_API_URL}) -ne 200 ]; do echo -n "."; sleep 2; done
}

function deploy_connector () {
    local configfile=${1:?Requires filename as first parameter!}
    local connectorname=$(jq -r .name ${configfile})
    local json="$(jq .config ${configfile})"
    curl -s -w "\n%{http_code}" --max-time 60 -X PUT -H "Content-Type: application/json" -d "${json}" ${CONNECT_REST_API_URL}/connectors/${connectorname}/config
}

function query_connector_state () {
    local configfile=${1:?Requires filename as first parameter!}
    local connectorname=$(jq -r .name ${configfile})
    curl -s -w "\n%{http_code}" --max-time 60 -X GET -H "Content-Type: application/json" ${CONNECT_REST_API_URL}/connectors/${connectorname}/status
}

function deploy_connector_in_file () {
    local file=${1:?Requires filename as first parameter!}
    local filebasename="$(basename "${file}")"
    local response="$(deploy_connector "${file}")"
    echo $response
    local body=$(echo "${response}" | cut -d$'\n' -f1)
    local http_code=$(echo "${response}" | cut -d$'\n' -f2)

    # check if deployment was successful
    if [[ "${http_code}" =~ ^2.* ]]; then
        local connectorname="$(echo "${body}" | jq -r .name)"
        local connectortype="$(echo "${body}" | jq -r .type)"
        local status_response="$(query_connector_state "${file}")"
        local status=$(echo "${status_response}" | cut -d$'\n' -f1)
        local status_http_code=$(echo "${status_response}" | cut -d$'\n' -f2)
        local retries=0
        while [[ ! "${http_code}" =~ ^2.* ]] || [ "$(echo "${status}" | jq -r '.connector')" == "null" ] || [ "$(echo "${status}" | jq -r '.connector | .state')" == "UNASSIGNED" ] && [ ${retries} -lt 10 ]; do
            sleep 1
            status="$(query_connector_state "${file}" | cut -d$'\n' -f1)"
            let "retries++"
        done;
        log "INFO" "Installed or updated ${connectortype} connector '${connectorname}' from ${filebasename} in Kafka Connect:\n$(echo "${status}" | jq '.connector')"
    else
        log "ERROR" "Could not deploy ${filebasename} to Kafka Connect:\n$(echo "${body}" | jq '.')"
        return 1
    fi
}

function deploy_connectors_in_dir () {
    local configdir=${1:?Requires dir as first parameter!}
    local return_code=0;
    for file in $(find "${configdir}" -name "*.json" | sort); do
        deploy_connector_in_file "${file}"
        if [ $? -ne 0 ]; then
            return_code=1
        fi
    done
    return ${return_code}
}

function main () {
    log "INFO" "Start Connectors deployment to ${CONNECT_REST_API_URL}."
    wait_until_available
    local target="${1:-${SCRIPT_DIR}}"
    if [ -d "${target}" ]; then
        deploy_connectors_in_dir "${target}"
    else
        log "ERROR" "Target needs to be a directory."
    fi
}

main "$@"
