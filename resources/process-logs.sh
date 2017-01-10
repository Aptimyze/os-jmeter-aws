#!/bin/bash

SCRIPT_DIR=$(readlink -f $(dirname $0))

TEST_NAME=%TEST_NAME%
TEST_KEY=%TEST_KEY%

TMPDIR=`mktemp -d`
trap 'rm -rf "$TMPDIR"' EXIT

tempfile() {
    mktemp ${TMPDIR}/$(basename "$0").XXXXXX
}

JMETER_INSTANCES='%JMETER_INSTANCES%'

for IP in ${JMETER_INSTANCES}; do
    echo "Pulling logs from ${IP}"
    IPUL=$(echo ${IP} | tr '.' '_')
    LOCAL=$(tempfile)
    scp -i ~/${TEST_NAME}/elk_rsa -oStrictHostKeyChecking=no ec2-user@${IP}:~/${TEST_NAME}/log-dir/${TEST_NAME}_${TEST_KEY}.log ${LOCAL}
    cat ${LOCAL} | awk -f ${SCRIPT_DIR}/fix-jmeter-errors.awk > ~/${TEST_NAME}/log-dir/${TEST_KEY}-${IPUL}.csv
    chmod 644 ~/${TEST_NAME}/log-dir/${TEST_KEY}-${IPUL}.csv
done

echo "Finished"
