#!/bin/bash
#
# Used to launch jmeter on a Docker instance:
# docker run --rm \
#  -e "P12PWD=password" \
#  -v /home/ec2-user/TEST_NAME/log-dir:/logs \
#  -v /home/ec2-user/TEST_NAME/data-dir:/input_data \
#  -v /home/ec2-user/TEST_NAME/conf-dir:/jmconf \
#  --entrypoint "/input_data/run.sh" \
#  ordnancesurvey/jmeter:v1.0
#
# The ability to use a P12 certificate for mutual SSL is available, the password
# must be passed to Docker on launching the instance and it will be picked up by
# this script in an attempt to reduce risk of exposing said password in a file
# that can be found.

SYSP=""
if [[ ! -z ${P12PWD} ]]; then
    SYSP="-Djavax.net.ssl.keyStore=/input_data/%P12_FILE% -Djavax.net.ssl.keyStorePassword=${P12PWD} -Djavax.net.ssl.keyStoreType=pkcs12"
fi

if [[ -z ${JMX_FILE} ]]; then
    T=/input_data/%JMX_FILE%
else
    T=/input_data/${JMX_FILE}
fi

/var/lib/apache-jmeter/bin/jmeter -n -t ${T} -p /jmconf/jmeter.properties -l /logs/%TEST_NAME%_%TIMESTAMP%.log ${SYSP}
