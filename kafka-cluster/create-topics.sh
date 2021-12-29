#!/usr/bin/env bash
BASE_DIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
source ${BASE_DIR}/.env

BOOTSTRAP_SERVER=${BOOTSTRAP_SERVER:-localhost:9092}
PARTITIONS=${PARTITIONS:-1}
REPLICATION_FACTOR=${REPLICATION_FACTOR:-1}
RETRY_COUNT=3

function log () {
    local level="${1:?Requires log level as first parameter!}"
    local msg="${2:?Requires message as second parameter!}"
    echo -e "$(date --iso-8601=seconds)|${level}|${msg}"
}

function create_topic () {
    local topic=${1:?Requires topic name as first parameter!}
    docker run --net host --rm -d \
        confluentinc/cp-kafka:${VERSION_CONFLUENT} \
        kafka-topics --bootstrap-server ${BOOTSTRAP_SERVER} \
        --create --partitions ${PARTITIONS} --replication-factor ${REPLICATION_FACTOR} --topic "${topic}"
}

function create_compacted_topic () {
    local topic=${1:?Requires topic name as first parameter!}
    docker run --net host --rm -d \
        confluentinc/cp-kafka:${VERSION_CONFLUENT} \
        kafka-topics --bootstrap-server ${BOOTSTRAP_SERVER} \
        --create --partitions ${PARTITIONS} --replication-factor ${REPLICATION_FACTOR} --topic "${topic}" --config cleanup.policy=compact
}

function check_for_success() {
  local topic=${1:?Requires topic name as first parameter!}
  local compacted=${2:?Requires if compacted or not as second parameter!}
  local count=0

  docker exec kafka bash
  kafka-topics --bootstrap-server ${BOOTSTRAP_SERVER} --topic "${topic}" --describe
  while [ "$count" -le ${RETRY_COUNT} ]
  do
    if [ $? -eq 0 ]; then
        return 0
    else
        log "ERROR" "Topic not present. Retry..."
        if [ ${compacted} -eq 1 ]; then
          create_compacted_topic ${topic}
          count++
        else
          create_topic ${topic}
          count++
        fi
    fi
  done

  return 1
}

function main () {
    log "INFO" "Start topic deployment to ${BOOTSTRAP_SERVER}."
    declare -a topics=(
      "sink-erp-crm-customer"
      "source-magento-customer"
      "sink-magento-customer-insert"
      "sink-magento-customer-update"
      "erp-crm-customer-update"
      "magento-customer-pending"
      "magento-customer-complete"
      "magento-customer-compacted"
      "magento-customer-schema"
      "magento-customer-flat"
    )
    declare -a compacted_topics=(
      "source-erp-customer"
      "source-crm-customer"
    )

    # first create topics and then check for success since creation usually takes 1-2 seconds to completely process
    for topic in ${topics[@]}; do
       create_topic $topic
    done
    for compacted_topic in ${compacted_topics[@]}; do
       create_compacted_topic $compacted_topic
    done

    for topic in ${topics[@]}; do
       check_for_success $topic 0
       if [ $? -gt 0 ]; then
            log "ERROR" "Topic creation was not successful. Aborting."
            exit 1
       fi
    done
    for compacted_topic in ${compacted_topics[@]}; do
       check_for_success $compacted_topic 1
       if [ $? -gt 0 ]; then
            log "ERROR" "Compacted topic creation was not successful. Aborting."
            exit 1
       fi
    done

    log "INFO" "Topic creation was successful."
}

main "$@"
