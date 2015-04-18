#! /bin/bash

###############################################
# Purpose : To push a custom metric to cloudwatch for visibility and subsequently create an alarm on the metric
# Usage : Run this script on ec2 instance in a crontab
# Crontab usage : */1 * * * * /home/ec2-user/Neptuneio_push_metrics_to_cloudwatch.sh
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

MONITORING_SCRIPTS_DIR="User_monitoring_scripts"
MONTORING_METRICS_LIST="Metrics_list"
HOST_INSTANCE_ID="NEPTUNEIO_HOST_INSTANCE_ID"
AWS_PROFILE="NEPTUNEIO_AWS_PROFILE"

NAME_SPACE="HostMetrics"
UNIT="None"

# Populate metric dimensions to include instance ID
# Add other dimensions if needed in the format Name=XYZ,Value=ABC and give the same dimensions while creating the alarm
METRIC_DIMENSIONS="InstanceId=$HOST_INSTANCE_ID"

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

###############################################
# User defined script to collect a custom metric
###############################################

for METRIC_SCIPT in `ls ./$MONITORING_SCRIPTS_DIR`
do
  # Use filename as the metric name
  METRIC_SCIPT_BASE_NAME=$(basename "$METRIC_SCIPT")
  METRIC_NAME="${METRIC_SCIPT_BASE_NAME%.*}"

  # Intialize metric value to 0
  METRIC_VALUE=0

  # Get standard output of user script to be pushed to AWS cloudwatch
  # If exit code of command line is to be pushed as a metric, then add ' >/dev/null &>1; echo $? ' to your custom script
  METRIC_VALUE=`./$MONITORING_SCRIPTS_DIR/METRIC_SCIPT`

  # Check if METRIC_VALUE output is an integer
  REGEX_FOR_NUMBER='^-?[0-9]+\.*[0-9]*$'
  if ! [[ $METRIC_VALUE =~ $REGEX_FOR_NUMBER ]] ; then
    echo -e "${red}Error: Your custom metric script didn't return a integer output ${NC}" >&2
    exit 1
  fi

  # Push metric only if alarm is already created and metric value is added to metrics_list file
  if grep $METRIC_NAME $MONTORING_METRICS_LIST >/dev/null 2>&1; then

    # Publish metric to AWS cloudwatch
    aws cloudwatch put-metric-data --profile $AWS_PROFILE --namespace $NAME_SPACE --metric-name $METRIC_NAME --value $METRIC_VALUE --unit $UNIT --dimensions $METRIC_DIMENSIONS  --timestamp "`date`"

    if [ $? -eq 0 ]; then
      exit 0;
    else
      exit 1;
    fi

  else
  # Push metric,create alarm and add metric_name to metrics_list to push metric only from next time

    aws cloudwatch put-metric-data --profile $AWS_PROFILE --namespace $NAME_SPACE --metric-name $METRIC_NAME --value $METRIC_VALUE --unit $UNIT --dimensions $METRIC_DIMENSIONS  --timestamp "`date`"

    aws cloudwatch put-metric-alarm --profile $AWS_PROFILE --alarm-name ${METRIC_NAME}_on_${HOST_INSTANCE_ID} --alarm-description "$METRIC_NAME on instance $HOST_INSTANCE_ID crossed threshold" --metric-name $METRIC_NAME --namespace $NAME_SPACE --statistic Average  --period 60 --threshold 1 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=$HOST_INSTANCE_ID --evaluation-periods 5

    if [ $? -eq 0 ]; then
      echo -e "\nPushing $METRIC_NAME metric to cloudwatch..."
      sleep 1
      echo -e "Successful"
      echo -e "Creating Alarm : ${green} ${METRIC_NAME}_on_${HOST_INSTANCE_ID} ${NC}under namespace $NAME_SPACE ..."
      sleep 1
      echo -e "Successful"

      # Update metrics list
      echo $METRIC_NAME >> $MONTORING_METRICS_LIST
      exit 0;
    else
      echo -e "\nPushing $METRIC_NAME metric to cloudwatch..."
      sleep 1
      echo -e "${red}Failed ${NC}"
      exit 1;
    fi

  fi

done

###### END OF SCRIPT ##########################
