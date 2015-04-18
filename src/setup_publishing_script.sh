#! /bin/bash

###############################################
# Purpose       : This script checks for AWS CLI installation, sets up a custom metrics publishing directory and fetches the default monitoring scripts for an user to modify
# Usage         : Run this script on an ec2 instance from a location where you want to create the custom metrics publishing directory
#
# Dependencies  : AWS CLI needs to be installed (Refer to : http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-bundle-other-os)
# Author        : Neptune.io, Inc. 2015
###############################################

# Output display colors
red='\033[0;31m'
green='\033[0;32m'
NC='\033[0m' # No Color

# Global variables
MONITORING_SCRIPT_DIR='neptuneio_monitoring'
USER_MONITORING_SCRIPTS_DIR="user_monitoring_scripts"
USER_MONITORING_METRICS_LIST="metrics_list"
PUBLISHING_SCRIPT="publish_metrics.sh"
CRONTAB_ADDER_OF_PUBLISHING_SCRIPT="add_publishing_script_to_crontab.sh"
USER_PROCESS_MONITORING_SCRIPT="nginx_process_status.sh"
USER_MEMORY_MONITORING_SCRIPT="memory_utilization.sh"
USER_DISK_MONITORING_SCRIPT="disk_utilization.sh"

# Check if AWS CLI is installed or not
echo -e "\nChecking if AWS CLI is installed"

if which aws ; then
  echo -e "AWS CLI is installed ! Good to go\n"
  # Create the Neptuneio profile of AWS keys
  echo -e "Adding your AWS keys to Neptuneio profile in ~/.aws"
  AWS_PROFILE="Neptuneio"
  aws configure --profile $AWS_PROFILE set aws_access_key_id $AWS_ACCESS_KEY
  aws configure --profile $AWS_PROFILE set aws_secret_access_key $AWS_SECRET_KEY
  # Get the instance ID
  HOST_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
  # Get the AWS region of the instance to push the metrics to
  AWS_REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'`
  aws configure --profile $AWS_PROFILE set region $AWS_REGION
  aws configure --profile $AWS_PROFILE set output json

  # Check if AWS keys given have right AWS cloudwatch priveleges
  if aws cloudwatch --profile $AWS_PROFILE describe-alarms > /dev/null ; then
    echo -e "AWS keys look good with right cloudwatch priveleges" > /dev/null
  else
    echo -e "\n${red}Your AWS keys don't seem to have right Cloudwatch priveleges. Please cross-check and rerun the command. Aborting${NC}\n"
    exit 1;
  fi
else
  echo -e "${red}AWS CLI is not installed; ${NC} Please install AWS CLI using :\n\n wget https://bootstrap.pypa.io/get-pip.py \n sudo python get-pip.py \n sudo pip install awscli --upgrade\n"
  echo -e "Please rerun the same command that you have just run after installing AWS CLI\n"
  exit 1;
fi

# Setup the directory structure
echo -e "Setting up directory structure and copying basic monitoring scripts"

# Only if already non-existent
if [ ! -d  $MONITORING_SCRIPT_DIR/$USER_MONITORING_SCRIPTS_DIR ]; then
  mkdir -p $MONITORING_SCRIPT_DIR/$USER_MONITORING_SCRIPTS_DIR
  touch $MONITORING_SCRIPT_DIR/$USER_MONITORING_METRICS_LIST

  cd $MONITORING_SCRIPT_DIR
  # Copy the publishing script and its wrapper to add to crontab
  curl -sS -O https://s3.amazonaws.com/prod-neptuneio-downloads/aws-monitoring-scripts/$PUBLISHING_SCRIPT
  curl -sS -O https://s3.amazonaws.com/prod-neptuneio-downloads/aws-monitoring-scripts/$CRONTAB_ADDER_OF_PUBLISHING_SCRIPT

  # Copy the default user monitoring scripts
  cd $USER_MONITORING_SCRIPTS_DIR
  curl -sS -O https://s3.amazonaws.com/prod-neptuneio-downloads/aws-monitoring-scripts/$USER_PROCESS_MONITORING_SCRIPT
  curl -sS -O https://s3.amazonaws.com/prod-neptuneio-downloads/aws-monitoring-scripts/$USER_MEMORY_MONITORING_SCRIPT
  curl -sS -O https://s3.amazonaws.com/prod-neptuneio-downloads/aws-monitoring-scripts/$USER_DISK_MONITORING_SCRIPT
  cd ..

  # Ensure same AWS region and instance id details are used in publishing script
  sed -i "s/NEPTUNEIO_AWS_PROFILE/$AWS_PROFILE/" $PUBLISHING_SCRIPT
  sed -i "s/NEPTUNEIO_HOST_INSTANCE_ID/$HOST_INSTANCE_ID/" $PUBLISHING_SCRIPT

fi

# Give 700 permissions to all files and directories
chmod -R 700 ./*

# Next steps message to the user
echo -e "\nDirectory setup :${green}Successful${NC}\n"
echo -e "NEXT STEPS : \n"
echo -e "1) You will find monitoring scripts in the directory: $MONITORING_SCRIPT_DIR/$USER_MONITORING_SCRIPTS_DIR . Please edit or copy them to create new ones. You can also delete default scripts which you dont want to use.\n"
echo -e "2) The name of your monitoring script is the metric name under which metric_values will be pushed to cloudwatch. So name the scripts appropriately. For e.g : xyz_process_status.sh --> Metric name will be xyz_process_status \n"
echo -e "3) Every monitoring script has usage guidelines inside to guide you on how to write your own custom script to publish metric values\n"
echo -e "4) Once you are done with editing, run${green} $CRONTAB_ADDER_OF_PUBLISHING_SCRIPT ${NC}so that the publishing script will be added to crontab and default alarms are created on your metrics\n\n"

exit 0
