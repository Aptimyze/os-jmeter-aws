# Overview

A scripted approach to launching JMeter tests onto multiple Amazon EC2 instances and gathering the results into an [ELK](https://www.elastic.co/webinars/introduction-elk-stack) stack where dashboards can be used to analyse and visualise the results.

This is an alterantive approach to using JMeter in Master / Slave mode which can lead to the Master becomming swamped with log traffic and to provide an alternative to JMeter for visualising the results where there may be millions of log records.

# Prerequisites
The following are required on a machine that will be used to run these scripts:

* AWS CLI with a named profile having been configured
* The jq utility
* OpenSSL for creating SSL certificates

# The Scripts
There is a single _jm_ wrapper script that is used to drive all testing. It is capable of displaying usage instructions and a list of sub-commands:

```
jm help
```

Each sub-command is also capable of providing usage instructions by passing the _--help_ switch:

```
jm [sub-command] --help
```

# A note about AWS environments
The scripts that launch instances make use of an AWS Security Group (defined in a configuration file). That security group should allow ssh connections between machines in the same security group, it should allow 8080 access from outside, specifically where you are running the tests from.

If you are going to use an AWS instance as the base for running tests and it is located in the same profile that instances will be started from then the scripts will need to be configured to use private IP Addresses.

If you are going to use an AWS instance as the base for running tests and it is located in the some other AWS profile than that used to start instances from then the security group will have to be configured to allow access from the public IP Address of the base instance.

# Process

## Overview
The entire process revolves around running JMeter in a non-gui mode on multiple AWS instances, waiting for a test to complete and then gathering the results. Some preparation is required in advance, such as:

* creating the JMeter test itself
* Clone this code base
* preparing the test environment
* procuring the AWS instances that will be used for performing the tests.

When creating the JMeter test, simply use the JMeter application as you always have, however do not add any samplers to it - they are not required. The JMeter test itself will be defined in a JMX file and that is all that is required.

Once there are JMX scripts prepared, the working environment can be created.

```
git clone https://github.com/OrdnanceSurvey/os-jmeter-aws.git
```

The bash scripts need to be added to your shell path, you can do this in a bash initialisation script (~/.bash_profile or ~/.bashrc for example) or always start a shell session as follows:

```
cd os-jmeter-aws/tests
source ./source_me
```

All actions from this point on are covered by the provided scripts.

## Step 1 - Create a local working environment
First thing to do is create a new test environment:

```
jm new --name "Some test name"
```

The above example will result in a new directory called _some_test_name_ in the current working directory and will copy default resources into it.

Once the test directory has been created make it the current working directory as this will simplify future script execution. All scripts can accept the name of the test that they should run against, however if this parameter is omitted then the name of the current working directory is used.

> From this point on the documentation assumes that the current working directory is the directory created for the test run using _jm new_.

## Step 2 - Edit config and add files to local environment
In the test directory is a __config__ file that will require completing. This file contains a number of environment variables used to drive the scripts in this suite. Not all are mandatory. Each variable is documented in the template itself and that is not repeated here.

At a minimum the name of the JMX file should be added to the __config__ file at the appropriate point.

## Step 3 - Verify the environment
To verify that the configuration looks okay it should be validated, this can be done at any time as it does not alter anything:

```
jm verify
```

> It is worth noting that verify is invoked by all future commands as a fail-safe.

## Step 4 - Start an ELK instance
This process uses ELK to analyse and visualise test results. Each test will get its own ELK stack running on a single instance. This should be sufficient for a JMeter test run.

```
jm elk-up
```

> This command creates a file called _elk_ in the test directory. You can peek into this file to obtain the IP Address and Instance Id of the ELK instance.

## Step 5 - Start JMeter instances
To run the JMeter tests you will need a number of JMeter instances. We have found that a single instance is capable of simulating around 250 concurrent users, mileage will vary as their are so many moving parts when performance testing.

The following command will prepare 10 instances for use:

```
jm jmeter-up --instance-count 10
```
> This command creates a file called _jmeter_ in the test directory. You can peek into this file to obtain the IP Address and Instance Id of every JMeter instance.

## Step 6 - Update things
Optional step here, but useful to keep your instances secure as it will run _yum update_ on all instances (ELK and JMeter)

```
jm patch
```

> This command will result in all instances rebooting.

## Step 7 - Perform a test run
There are two ways to launch a test run:

1. By running the test on all JMeter instances from the go-get.
2. By starting with one instance and then sequentially adding one more at a time after a delay until all instances are in use.

The first method requires the JMX file to provide termination of the run, that may be by setting the number of test iterations or the duration of the test window. However it is done, no attempt is made by the scripts to stop a test initiated this way.

For the second method the scripts should be configured to run forever and the scripts will take care of shutting the tests down.

### Step 7.1 - All together

```
jm run-tests  --jvm-args "-Xms512m -Xmx2048m" --jmx-file wmts-100.jmx
```

> Both --jvm-args and --jmx-file are optional, see help text for more information

You should then monitor the tests until completion before proceeding.

### Step 7.2 - Stepped
The example below will let the tests run for 10 minutes before bringing another JMeter instance online. If there are 10 instances in play then the tests will run for a total of 100 minutes:

```
jm run-step-tests --delay-minutes 10 --run-time-minutes 60 --jvm-args "-Xms512m -Xmx2048m" --jmx-file wmts-100.jmx
```
> All optional args shown, see help text for more information

Once all JMeter instances have been brought into play the tests will run for the same interval and then all tests will be terminated.

## Step 8 - Process the log files
The JMeter log needs to be fethed from each JMeter instance and be fed into the ELK instance. Depending on the size of these files, this could take a while and for that reason the following script performs the task asynchronously.

```
jm process-logs
```

> Once the logs have been processed use the Kibana UI to configure dashboards for analysing and visualising the test results: http://ELK:8080/

> Steps 7 & 8 can be repeated over and over until the tester is satisfied

## Step 9 - Terminate the instances
Once testing is complete the instances can be terminated.

```
jm jmeter-terminate
jm elk-terminate
```

# Utility
There are a couple of sub-commands that are more utility than part of a test run:

## Stop all instances
Your testing may go on for days and there will be times you want to stop the instances to keep that AWS bill down.

```
jm stop
```

## Restart stopped instances
The counterpart to stop allows you to restart all of the instances

```
jm start
```

## Connect to ELK instance
The following will perform an interactive ssh to the ELK instance.

```
jm ssh-elk
```
## Connect to JMeter instance
This script allows connecting to a JMeter instance. For convenience there is an optional _--index_ parameter for selecting which instance, if this is omitted then the default value 1 is used.

```
jm ssh-jmeter
```

or to connect to the third instance:

```

jm ssh-jmeter --index 3
```

> Indexing is 1 based, not 0.

## Add a new test JMX file to a test
When you launch the JMeter instances all of the test JMX files are copied up to it. Once the instance is up you may find the need to provide a new test or modification to an existing test. This script provides the
means to do that.
Additionally this command can also be used to add any data files that may be used by your jmeter script. E.g. a CSV file that may contain a list of values used by jmeter's CSV Data Set Config Element.

```
jm add-jmx --jmx-file ~/some/dir/rigorous.jmx
```

> Only run this script when all JMeter instances are running.

## Clear logs
Been running loads of tests and have a huge stash of logs on the instances? This script will go and delete them all. It will not alter what has been added to Elasticsearch, your Kibana dashboards should be just fine.

```
jm clear-logs
```

## Add more JMeter instances
Need more power? This script allows more JMeter instances to be launched, configured and made available.

```
jm jmeter-add-instances --instance-count 5
```

# Summary
The jm wrapper provides the following summary:

```
$ jm help

his is a utility for performing JMeter tests run using resources procured from Amazon Web Services EC2.
The following sub-commands are available:

	add-jmx                 Add a JMX file to the test. If there are running instances then upload the file to them as well.
	clear-logs              Delete log files from all ELK and JMeter instances
	elk-terminate           Terminate ELK instance started for a test
	elk-up                  Launch and configure a new ELK instance for processing logs for a test
	jmeter-add-instances    Launch more JMeter instances and configure for the test
	jmeter-terminate        Terminate all JMeter instances started for a test
	jmeter-up               Launch and configure a specific number of JMeter instances
	new                     Prepare a new local test environment
	patch                   Perform a yum update on all test ELK and JMeter instances
	process-logs            Fetch logs from JMeter instances and feed to LogStash on ELK instance
	public-or-private       NOT A SUB-COMMAND
	run-step-tests          Run test on JMeter instances adding each instance to the mix after a delay
	run-tests               Run test on all JMeter instances simultaneously
	ssh-elk                 Open an interactive ssh session to ELK instance
	ssh-jmeter              Open an interactive ssh session to a JMeter instance
	start                   Start all previously stopped instances of ELK and JMeter
	stop                    Stop all running instances of ELK and JMeter
	test-status             Display status of tests running in background on all JMeter Instances
	verify                  Verify a test environment
	wait-for-tests          Wait for all JMeter instances to stop running tests.

Always start with 'jm new [test-name]'.

Typical workflow - Run STEP tests, ramping up over time
	jm new [NAME]
	cd [NAME]
	## Edit and complete config file ##
	jm verify
	jm elk-up
	jm jmeter-up --instance-count 5
	jm patch
	jm run-step-tests --delay-minutes 10
	jm process-logs
	## Run more tests and process logs ##
	## Visit Kabana dashboard at http://ELK:8080/ ##
	jm jmeter-terminate
	jm elk-terminate

Typical workflow -  Background tests that self-terminate
	jm new [NAME]
	cd [NAME]
	## Edit and complete config file ##
	jm verify
	jm elk-up
	jm jmeter-up --instance-count 5
	jm patch
	jm run-tests
	km test-status --wait
	jm process-logs
	## Run more tests and process logs ##
	## Visit Kabana dashboard at http://ELK:8080/ ##
	jm jmeter-terminate
	jm elk-terminate

Help can be obtained for any sub-command: jm [command] --help
```
