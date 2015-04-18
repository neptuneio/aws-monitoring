#! /bin/sh

###############################################
# Purpose : To push any application metric to cloudwatch for visibility and subsequently creating alarms on it
# Usage : Run this script on ec2 instance
# Crontab usage : */1 * * * * /home/ec2-user/pushMetric.sh
#
# Dependencies : AWS CLI needs to be installed
###############################################

###############################################
# PLEASE CHANGE these variables appropriately
###############################################

export AWS_ACCESS_KEY_ID="AKLKSJDAFLDKJADFSDFLQ"
export AWS_SECRET_ACCESS_KEY="Wadlfkjadfinz2342dsdfdfqAW3zkTVw"
export AWS_REGION="us-east-1"

PROCESS_NAME="worker_job"
METRIC_NAME="worker_job_status"
NAME_SPACE="ApplicationMetrics"
UNIT="None"

ALARM_NAME="ALARM_on_nagent.py_status"
ALARM_SNS_TOPIC="arn:aws:sns:us-east-1:822234111112221275:nsns-gamma"

###############################################
# User defined script to collect an application metric
###############################################

# This value eventually will be published to AWS cloudwatch
METRIC_VALUE=0

# Process monitoring script to populate metric
if pgrep $PROCESS_NAME > /dev/null 2>&1
then
    METRIC_VALUE=1
else
    METRIC_VALUE=0
  fi

# Memory utilization monitoring script to populate metric
# METRIC_VALUE=`free | grep Mem | awk '{print $3/$2 * 100.0}'`

# Disk utilization monitoring script to populate metric
# METRIC_VALUE=`df -hl | grep xvda1 | awk '{print $5}' | sed 's/%//g'`

# For any other application metric , populate METRIC_VALUE
# METRIC_VALUE=`command_to_return_float_value`

###############################################
# Publish metric to AWS cloudwatch
###############################################

# Fetch hostname
HOST_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

# Add more dimensions in the format of Name=XYZ,Value=ABC and give the same in ALARM_METRIC_DIMENSIONS
METRIC_DIMENSIONS="InstanceId=$HOST_INSTANCE_ID"
ALARM_METRIC_DIMENSIONS="Name=InstanceId,Value=$HOST_INSTANCE_ID"

aws cloudwatch put-metric-data --namespace $NAME_SPACE --metric-name $METRIC_NAME --value $METRIC_VALUE --unit $UNIT --dimensions $METRIC_DIMENSIONS --region $AWS_REGION --timestamp "`date`"

###############################################
# Use below command to create an alarm on published metric
###############################################

# aws cloudwatch put-metric-alarm --alarm-name $ALARM_NAME --statistic Average --comparison-operator LessThanThreshold --threshold 1 --evaluation-periods 1 --period 60 --namespace $NAME_SPACE --metric-name $METRIC_NAME --dimensions $ALARM_METRIC_DIMENSIONS --region $AWS_REGION --actions-enabled --alarm-actions $ALARM_SNS_TOPIC --ok-actions $ALARM_SNS_TOPIC

###############################################
# Finally, use the below command to put this script in a crontab to publish every 1 minute.
################################################
# crontab -e
# */1 * * * * /home/ec2-user/pushMetric.sh
