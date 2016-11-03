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
DATA_DIR=${SCRIPT_DIR}/data-dir
CONF_DIR=${SCRIPT_DIR}/conf-dir
LOG_DIR=${SCRIPT_DIR}/log-dir

# Create working directories
log "Creating working directories ${DATA_DIR}, ${CONF_DIR} and ${LOG_DIR}"
mkdir -p ${DATA_DIR} ${CONF_DIR} ${LOG_DIR}
check $? "Creating working directories ${DATA_DIR}, ${CONF_DIR} and ${LOG_DIR}"

log "Move jmeter.properties into conf directory"
mv ${SCRIPT_DIR}/jmeter.properties ${CONF_DIR}
check $? "Move jmeter.properties into conf directory"

log "Adding ELK public key to known hosts"
cat ${SCRIPT_DIR}/elk_rsa.pub >> ~/.ssh/authorized_keys
check $? "Adding ELK public key to known hosts"

log "Move JMX files to data directory"
mv ${SCRIPT_DIR}/*.jmx ${DATA_DIR}
check $? "Move *.jmx into data directory"

if [[ ! -z "%P12_FILE%" ]]; then
    log "Move %P12_FILE% files to data directory"
    mv ${SCRIPT_DIR}/%P12_FILE% ${DATA_DIR}
    check $? "Move %P12_FILE% into data directory"
fi

if [[ -r ${SCRIPT_DIR}/data.tgz ]]; then
    log "Extracting data from data.tgz"
    tar xvzf ${SCRIPT_DIR}/data.tgz -C ${DATA_DIR}
    check $? "Extracting data from data.tgz"
fi

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

log "Pulling docker image: %DOCKER_JMETER_IMAGE%"
docker pull %DOCKER_JMETER_IMAGE%
check $? "Pulling docker image: %DOCKER_JMETER_IMAGE%"
