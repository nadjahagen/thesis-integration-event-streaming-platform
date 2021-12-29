#!/usr/bin/env bash
pushd . > /dev/null
cd $(dirname ${BASH_SOURCE[0]})
SCRIPT_DIR=$(pwd)
popd > /dev/null

KSQL_ENDPOINT="${KSQL_ENDPOINT:-http://localhost:8089}"

_commandSequenceNumber=""

function log () {
    local level="${1:?Requires log level as first parameter!}"
    local msg="${2:?Requires message as second parameter!}"
    echo -e "$(date --iso-8601=seconds)|${level}|${msg}"
}

function wait_until_available () {
    while [ $(curl -s -L -o /dev/null -w %{http_code} --max-time 60 ${KSQL_ENDPOINT}/info) -ne 200 ]; do echo -n "."; sleep 2; done
}

function wrap_ksql_in_json () {
    local ksql="${1:?Requires ksql statement as first parameter!}"
    echo "{}" | jq \
        --arg ksql "$(echo "${ksql}" | tr -s '\n' ' ')" \
        --arg autoOffsetReset "earliest" \
        '.ksql=$ksql | .streamsProperties."ksql.streams.auto.offset.reset"=$autoOffsetReset'
}

function to_json_with_seq () {
    local file="${1:?Requires filename as first parameter!}"
    local json
    if [ "${file##*.}" == "json" ]; then
        json="$(cat "${file}"))"
    else
        json="$(wrap_ksql_in_json "$(cat "${file}")")"
    fi
    echo "${json}" | jq --argjson commandSequenceNumber ${_commandSequenceNumber:-null} '. + {commandSequenceNumber: $commandSequenceNumber}'
}

function deploy_ksqstatement () {
    local json="${1:?Requires json as first parameter!}"
    curl -s -w "\n%{http_code}" --max-time 60 -X POST -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d"${json}" ${KSQL_ENDPOINT}/ksql
}

function deploy_ksqstatement_in_file () {
    local file="${1:?Requires filename as first parameter!}"
    local filebasename="$(basename "${file}")"
    local response="$(deploy_ksqstatement "$(to_json_with_seq "${file}")")"
    local body=$(echo "${response}" | cut -d$'\n' -f1)
    local http_code=$(echo "${response}" | cut -d$'\n' -f2)
    if [[ "${http_code}" =~ ^2.* ]]; then
        _commandSequenceNumber="$(echo "${body}" | jq -r '. | last | .commandSequenceNumber | values')"
        log "INFO" "Deployed ${filebasename} to ksqlDB (seq=${_commandSequenceNumber}):\n$(echo "${body}" | jq '.[] |= del(.statementText)')"
    else
        local error_code="$(echo "${body}" | jq -r .error_code)"
        local message="$(echo "${body}" | jq -r .message)"
        if [[ "${error_code}" == "40001" ]] && [[ "${message}" =~ "is not supported because there are multiple queries writing into it" ]]; then
            log "INFO" "Statement in ${filebasename} already exists: ${message}"
        elif [[ "${error_code}" == "40001" ]] && [[ "${message}" =~ "same name already exists" ]]; then
            log "INFO" "Statement in ${filebasename} already exists: ${message}"
        elif [[ "${error_code}" == "40002" ]]; then
            log "WARNING" "File ${filebasename} contains a statement, that should be issued to /query endpoint: ${message}"
        else
            log "ERROR" "Could not deploy ${filebasename} to ksql:\n$(echo "${body}" | jq '.')"
            return 1
        fi
    fi
}

function deploy_ksqlstatements_in_dir () {
    local configdir="${1:?Requires dir as first parameter!}"
    local filepattern="${2:?Requires file pattern as first parameter!}"
    for file in $(find "${configdir}" -name "${filepattern}" | sort); do
        deploy_ksqstatement_in_file "${file}"
        if [ $? -ne 0 ]; then
            log "ERROR" "Abort processing of further requests!"
            return 1
        fi
    done
}

function main () {
    log "INFO" "Start Ksql statement deployment to ${KSQL_ENDPOINT}"
    wait_until_available
    local target="${1:-"${SCRIPT_DIR}/ksql"}"
    local filepattern="${2:-"*.ksql"}"
    if [ -d "${target}" ]; then
        deploy_ksqlstatements_in_dir "${target}" "${filepattern}"
    else
        log "ERROR" "Target needs to be a directory."
    fi
}

main "$@"
