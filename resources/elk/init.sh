#!/bin/bash
#
typeset -i DELAY=5

function log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')]: $@"
}

function check() {
    if (( $1 != 0 )); then
        log "ERROR - $2"
        exit 1
    fi
}

SCRIPT_DIR=$(readlink -f $(dirname $0))
CONF_DIR=${SCRIPT_DIR}/conf-dir
LOG_DIR=${SCRIPT_DIR}/log-dir
WORK_DIR=${SCRIPT_DIR}/work-dir

# Create working directories
log "Creating working directories ${WORK_DIR}, ${CONF_DIR} and ${LOG_DIR}"
mkdir -p ${CONF_DIR} ${LOG_DIR} ${WORK_DIR}
check $? "Creating working directories ${WORK_DIR}, ${CONF_DIR} and ${LOG_DIR}"

log "Move logstash config file into conf directory"
mv ${SCRIPT_DIR}/99-jmeter.conf ${CONF_DIR}
check $? "Move logstash config file into conf directory"

log "Waiting for Docker daemon to start"
typeset -i MC=0
while true; do
    DC=$(docker ps)
    if (( $? == 0 )); then
        break
    fi
    MC=${MC}+1
    if (( ${MC} > 30 )); then
        log "Docker service not started after 5 mins"
        exit 1
    fi
    log ".. waiting for docker (${MC})"
    sleep 10
done

log "Pulling docker image: DOCKER_ELK_IMAGE"
docker pull DOCKER_ELK_IMAGE
check $? "Pulling docker image: DOCKER_ELK_IMAGE"

log "Running docker image: DOCKER_ELK_IMAGE"
docker run -d --restart=always -v ${LOG_DIR}:/jmeter-logs -v ${CONF_DIR}:/etc/logstash/conf.d --name elk -p 8080:5601 DOCKER_ELK_IMAGE
check $? "Running docker image: DOCKER_ELK_IMAGE"

log "Sleeping for ${DELAY} minutes"
for I in $(seq ${DELAY}); do
    sleep 60
    log "${I} minute(s) elapsed ..."
done
log "Awake"

log "Obtaining IP address of ELK instance from Docker daemon"
ELK_IP=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' elk)
check $? "Obtaining IP address of ELK instance from Docker daemon"

log "PUTting index template to Elasticsearch on ELK instance (${ELK_IP})"
curl -X PUT -d @${SCRIPT_DIR}/es-index.json http://${ELK_IP}:9200/_template/jmeter_template
check $? "PUTting index template to Elasticsearch on ELK instance (${ELK_IP})"
