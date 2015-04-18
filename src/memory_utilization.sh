#! /bin/bash

###############################################
# Purpose           : A health check script to get a custom metric value that can be pushed to AWS cloudwatch
# Author            : Neptune.io, Inc. 2015
#
# Usage guidelines  :
# ----------------
# 1) Simply copy this script to the 'user_monitoring_scripts' directory. A publishing script will automatically run this script and push the metric value to cloudwatch
# 2) The name of this script becomes the metric name under which metric value will be published. So name it appropriately.For e.g : xyz_process_status.sh --> metric name is xyz_process_status
# 3) Any script written below should print only ONE INTEGER or FLOATING VALUE to stdout.Redirect any other messages or strings to /dev/null using '>/dev/null 2>&1'
# 4) It's highly recommended to run the script once to see if you are seeing a metric value as recommended in step 3
#
###############################################


###############################################
# SCRIPT TEMPLATE FOR FUTURE REFERENCE
###############################################

## Example 1: Script to check if a process is running and if so output a metric value of 0 else 1

## Health check command here
## Make sure any non-metric value stdout or stderr is redirected to /dev/null
# pgrep -x nginx > /dev/null 2>&1

## Print only a metric value to stdout
# if [ $? -eq 0 ]; then
#   echo 0
# else
#   echo 1
# fi

## Example 2: Script to get the memory utilization on a server as the metric value

## In this case health check command below directly prints the metric value to stdout
# free | grep Mem | awk '{print $3/$2 * 100.0}'

## Example 3: Script to get the disk utilization on a server as the metric value

## In this case health check command below directly prints the metric value to stdout
## Modify your disk name below
# df -hl | grep "/dev/xvda1" | awk '{print $5}' | sed 's/%//g'

################################################


###############################################
# ACTUAL SCRIPT HERE
###############################################

# Health check command here
free | grep Mem | awk '{print $3/$2 * 100.0}'

###############################################
