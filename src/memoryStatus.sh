#! /bin/bash

###############################################
# Purpose : To push an application metric (Memory utiization metric) for visibility and subsequently creating alarms on it
# Usage : Run this script on ec2 instance in a crontab
# Crontab usage : */1 * * * * /home/ec2-user/memoryStatus.sh
#
# Dependencies : AWS CLI needs to be installed
# Author : Neptune.io, Inc.
###############################################

# Output display colors
red='\033[0;31m'
green='\033[0;32m'
NC='\033[0m' # No Color

###############################################
# PLEASE CHANGE these variables appropriately
###############################################

HOST_INSTANCE_ID="NEPTUNEIO_HOST_INSTANCE_ID"
AWS_PROFILE="NEPTUNEIO_AWS_PROFILE"

METRIC_NAME="Memory_utilization"
NAME_SPACE="HostMetrics"
UNIT="Percent"

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

###############################################
# User defined script to collect an application metric
###############################################

# This value eventually will be published to AWS cloudwatch
METRIC_VALUE=0

# Memory utilization monitoring script to populate metric
METRIC_VALUE=`free | grep Mem | awk '{print $3/$2 * 100.0}'`

###############################################
# Publish metric to AWS cloudwatch
###############################################

# Add more dimensions in the format of Name=XYZ,Value=ABC and give the same in ALARM_METRIC_DIMENSIONS
METRIC_DIMENSIONS="InstanceId=$HOST_INSTANCE_ID"

aws cloudwatch put-metric-data --profile $AWS_PROFILE --namespace $NAME_SPACE --metric-name $METRIC_NAME --value $METRIC_VALUE --unit $UNIT --dimensions $METRIC_DIMENSIONS  --timestamp "`date`"

aws cloudwatch put-metric-alarm --profile $AWS_PROFILE --alarm-name ${METRIC_NAME}_on_${HOST_INSTANCE_ID} --alarm-description "High $METRIC_NAME on instance $HOST_INSTANCE_ID" --metric-name $METRIC_NAME --namespace $NAME_SPACE --statistic Average  --period 60 --threshold 80 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=$HOST_INSTANCE_ID --evaluation-periods 5

if [ $? -eq 0 ]; then
  echo -e "\nPushing metric to cloudwatch..."
  sleep 1
  echo -e "Successful"
  echo -e "Creating Alarm : ${green} ${METRIC_NAME}_on_${HOST_INSTANCE_ID} ${NC}on the metric $METRIC_NAME under namespace $NAME_SPACE ..."
  sleep 1
  echo -e "Successful"
  exit 0;
else
  echo -e "Pushing metric to cloudwatch..."
  sleep 1
  echo -e "${red}Failed ${NC}"
  exit 1;
fi

###### END OF SCRIPT ##########################
