#! /bin/bash

###############################################
# Purpose       : To push a custom metric to cloudwatch for visibility and create an alarm on the metric
# Usage         : Run this script on ec2 instance in a crontab
# Crontab usage : */1 * * * * /home/ec2-user/Neptuneio_monitoring/neptuneio_push_custom_metrics_to_cloudwatch.sh
#
# Dependencies  : AWS CLI needs to be installed
# Author        : Neptune.io, Inc.
###############################################

# Output display colors
red='\033[0;31m'
green='\033[0;32m'
NC='\033[0m' # No Color

###############################################
# PLEASE CHANGE these variables appropriately
###############################################

BASE_DIR="$(dirname "$0")"
USER_MONITORING_SCRIPTS_DIR="user_monitoring_scripts"
USER_MONITORING_METRICS_LIST="metrics_list"
HOST_INSTANCE_ID="NEPTUNEIO_HOST_INSTANCE_ID"
AWS_PROFILE="NEPTUNEIO_AWS_PROFILE"

NAME_SPACE="neptuneio_custom_metrics"
UNIT="None"

# Populate metric dimensions to include instance ID
# Add other dimensions if needed in the format Name=XYZ,Value=ABC and give the same dimensions while creating the alarm
METRIC_DIMENSIONS="InstanceId=$HOST_INSTANCE_ID"

# Add relevants path for AWS command line
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
EXIT_STATUS=0

###############################################
# User defined script to collect a custom metric
###############################################
cd $BASE_DIR

for METRIC_SCRIPT in `ls ./$USER_MONITORING_SCRIPTS_DIR`
do
  # Use filename as the metric name
  METRIC_SCRIPT_BASE_NAME=$(basename "$METRIC_SCRIPT")
  METRIC_NAME="${METRIC_SCRIPT_BASE_NAME%.*}"

  # Intialize metric value to default value of 0
  METRIC_VALUE=0

  # Get standard output of user script to be pushed to AWS cloudwatch
  METRIC_VALUE=`./$USER_MONITORING_SCRIPTS_DIR/$METRIC_SCRIPT`

  # Check if METRIC_VALUE output is an integer
  REGEX_FOR_NUMBER='^-?[0-9]+\.*[0-9]*$'
  if ! [[ $METRIC_VALUE =~ $REGEX_FOR_NUMBER ]] ; then
    echo -e "\n${red}Failed : Your script : $METRIC_SCRIPT didn't return an integer or floating value as required${NC}" >&2
    echo -e "Please correct your script and rerun the command"
    # Increment exit status
    ((EXIT_STATUS++))
  else
    # Push metric only if alarm is already created and metric name is added to metrics_list file
    if grep $METRIC_NAME $USER_MONITORING_METRICS_LIST >/dev/null 2>&1; then

      # Publish metric to AWS cloudwatch
      aws cloudwatch put-metric-data --profile $AWS_PROFILE --namespace $NAME_SPACE --metric-name $METRIC_NAME --value $METRIC_VALUE --unit $UNIT --dimensions $METRIC_DIMENSIONS  --timestamp "`date`"

      if [ $? -eq 0 ]; then
        echo -e "\nSuccessful" >/dev/null
      else
        # Increment exit status
        ((EXIT_STATUS++))
      fi
    else
      # Push metric,create alarm and add metric_name to metrics_list to push metric only from next time

      aws cloudwatch put-metric-data --profile $AWS_PROFILE --namespace $NAME_SPACE --metric-name $METRIC_NAME --value $METRIC_VALUE --unit $UNIT --dimensions $METRIC_DIMENSIONS  --timestamp "`date`"

      aws cloudwatch put-metric-alarm --profile $AWS_PROFILE --alarm-name ${METRIC_NAME}_on_${HOST_INSTANCE_ID} --alarm-description "$METRIC_NAME on instance $HOST_INSTANCE_ID crossed threshold" --metric-name $METRIC_NAME --namespace $NAME_SPACE --statistic Average  --period 60 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=InstanceId,Value=$HOST_INSTANCE_ID --evaluation-periods 5

      if [ $? -eq 0 ]; then
        echo -e "\nPushing $METRIC_NAME metric to cloudwatch..."
        sleep 1
        echo "Successful"
        echo -e "Creating Alarm :${green} ${METRIC_NAME}_on_${HOST_INSTANCE_ID} ${NC}under the namespace $NAME_SPACE ..."
        sleep 1
        echo "Successful"
        # Update metrics list
        echo "$METRIC_NAME" >> $USER_MONITORING_METRICS_LIST
      else
        echo -e "${red}Failed : Check your AWS keys in ~/.aws/credentials${NC}"
        # Increment exit status
        ((EXIT_STATUS++))
      fi

    fi

  fi

done

# Based on exit status exit
if [ $EXIT_STATUS -gt 0 ]; then
  exit 1;
else
  exit 0;
fi

###### END OF SCRIPT ##########################
