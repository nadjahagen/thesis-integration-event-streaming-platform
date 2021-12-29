#!/bin/bash
args=1

function log () {
    local level="${1:?Requires log level as first parameter!}"
    local msg="${2:?Requires message as second parameter!}"
    echo -e "$(date --iso-8601=seconds)|${level}|${msg}"
}

startAll() {
  log "INFO" "Starting all components..."
  docker-compose -f kafka-cluster/docker-compose.kafka.yaml up -d
  docker-compose -f magento/docker-compose.magento.yaml up -d --build
  docker-compose -f legacy-system/erp/docker-compose.erp.yaml up -d
  docker-compose -f legacy-system/crm/docker-compose.crm.yaml up -d
  log "INFO" "Setup finished."
}

stopAll() {
  log "INFO" "Stopping all components..."
  docker-compose -f magento/docker-compose.magento.yaml down
  docker-compose -f legacy-system/erp/docker-compose.erp.yaml down
  docker-compose -f legacy-system/crm/docker-compose.crm.yaml down
  docker-compose -f connect-distributed/docker-compose.connect.yaml down
  docker-compose -f kafka-cluster/docker-compose.kafka.yaml down
  log "INFO" "Cleanup finished."
}

# stop Kafka, Zookeeper, Schema Registry, Kafka Connect and ksqlDB; can be used for development purposes to reset to cluster
stopKafka() {
  log "INFO" "Stopping all Kafka and Confluent components..."
  docker-compose -f connect-distributed/docker-compose.connect.yaml down
  docker-compose -f kafka-cluster/docker-compose.kafka.yaml down
  log "INFO" "Cleanup finished."
}

showHelp() {
  echo "Syntax: setup.sh option"
  echo "options:"
  echo "  -s  | --start      Start all components."
  echo "  -q  | --quit       Stop all components."
  echo "  -a  | --artifacts  Deploy topics, connectors and KSQL statements"
  echo "  -rv | --rvolumes   Delete Magento and other volumes."
  echo "  -h  | --help       Display help options."
  echo
}

deployArtifacts() {
  log "INFO" "Deploying topics..."
  /bin/bash ./kafka-cluster/create-topics.sh
  if [ $? -gt 0 ]; then
    log "ERROR" "Topic creation was not successful. Aborting..."
    exit 1
  fi
  log "INFO" "Deploying Kafka Connectors in distributed mode..."
  docker-compose -f connect-distributed/docker-compose.connect.yaml up -d --build
  log "INFO" "Artifacts deployment done."
}

removeVolumes() {
  log "INFO" "Removing Magento and other volumes for complete cleanup..."
  docker volume rm thesis_magento-data
  docker volume rm thesis_magento-db-data
  docker volume rm thesis_elasticsearch-data

  log "INFO" "Cleanup finished."
}

if [ $# -gt 1 ]; then
	    log "ERROR" "More than one option is not allowed. Exactly one of the following options needs to be provided."
      echo "---------------------------------------------"
	    showHelp
	    exit 1
else
  while [ 1 ]
  do
    key="$1"

    case $key in
      -s|--start)
        startAll
        exit
        ;;
      -q|--quit)
        stopAll
        exit
        ;;
      -qk|--qkafka)
        stopKafka
        exit
        ;;
      -a|--artifacts)
        deployArtifacts
        exit
        ;;
      -h|--help)
        showHelp
        exit
        ;;
      -rv|--rvolumes)
        removeVolumes
        exit
        ;;
      *)
        log "ERROR" "Unknown option. Exactly one of the following options needs to be provided."
        echo "---------------------------------------------"
        showHelp
        exit
        ;;
    esac
  done
fi
