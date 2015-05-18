#! /bin/bash

###############################################
# Purpose           : Get a custom metric value that can be pushed to AWS cloudwatch
# Author            : Neptune.io, Inc. 2015
#
# Usage guidelines  :
#
# 1) Any script written below should print the custom metric as an INTEGER or FLOATING VALUE to stdout. Redirect any other non-metric messages to /dev/null using '>/dev/null 2>&1'
# 2) The name of this script will be used as the metric name. So name the script appropriately.For e.g : If your script name is xyz_process_status.sh then the metric name will be xyz_process_status
# 3) Simply place this script in the 'user_scripts' directory. A publishing script will automatically run this script and push the metric value to cloudwatch
# 4) It's highly recommended to run the script once to check if you are seeing the custom metric value as recommended in step 1
#
###############################################


###############################################
# CUSTOM METRIC SCRIPT HERE
###############################################

# E.g : Disk utilization for /dev/xvda1
df -hl | grep "/dev/xvda1" | awk '{print $5}' | sed 's/%//g'

###############################################


###############################################
# MORE EXAMPLES
###############################################

## Example 1: PROCESS MONITORING : Check if a process is running;  If so give a metric value of 0 else 1

# pgrep -x nginx > /dev/null 2>&1
## Making sure any non-metric value is redirected to /dev/null above

## Print only a metric value to stdout
# if [ $? -eq 0 ]; then
#   echo 0
# else
#   echo 1
# fi

## Example 2: MEMORY UTILIZATION
# free | grep Mem | awk '{print $3/$2 * 100.0}'

## Example 3: DISK UTILIZATION
# df -hl | grep "/dev/xvda1" | awk '{print $5}' | sed 's/%//g'

################################################
