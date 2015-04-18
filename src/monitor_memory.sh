#! /bin/bash

###############################################
# Purpose : This script fetches a memory monitoring script, updates access/secret keys and other variables, and pushes the monitoring script into crontab
# Usage : Run this script on ec2 instance from a location where the monitoring script will be stored
#
# Dependencies : AWS CLI needs to be installed (Refer to : http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-bundle-other-os)
# Author : Neptune.io, Inc.
###############################################

# Output display colors
red='\033[0;31m'
green='\033[0;32m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed or not
echo -e "\nChecking if AWS CLI is installed"

if which aws ; then
  echo -e "AWS CLI is installed ! Good to go\n"
else
  echo -e "${red} AWS CLI is not installed; ${NC} Please install AWS CLI using :\n\n wget https://bootstrap.pypa.io/get-pip.py \n sudo python get-pip.py \n sudo pip install awscli --upgrade \n\n"
  echo -e "Please rerun the same command that you have just run after installing AWS CLI"
  exit 1;
fi

# Fetch the monitoring script
curl -s -O https://s3.amazonaws.com/downloads/aws-monitoring-scripts/memoryStatus.sh

MONITORING_FILE=memoryStatus.sh

# Replace appropriate varibales one-time in the monitoring script

AWS_REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'`

HOST_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
sed -i "s/NEPTUNEIO_HOST_INSTANCE_ID/$HOST_INSTANCE_ID/" $MONITORING_FILE

# Check if aws config file exists
AWS_PROFILE="Neptuneio"
sed -i "s/NEPTUNEIO_AWS_PROFILE/$AWS_PROFILE/" $MONITORING_FILE

if [ -f ~/.aws/config ];
then
  echo "AWS CLI config file exists"
  if grep -q $AWS_PROFILE ~/.aws/config ;
  then
    echo "$AWS_PROFILE profile already exists. Good to go !"
  else
    echo "Adding $AWS_PROFILE profile to existing config file"
    echo "[profile $AWS_PROFILE]
    output = json
    region = $AWS_REGION
    aws_access_key_id = $AWS_ACCESS_KEY
    aws_secret_access_key = $AWS_SECRET_KEY" >> ~/.aws/config
    echo "[$AWS_PROFILE]
    aws_access_key_id = $AWS_ACCESS_KEY
    aws_secret_access_key = $AWS_SECRET_KEY" >> ~/.aws/credentials
  fi
else
  echo "No AWS CLI configuration exists.Creating one, with Neptuneio profile"
  if [ -d ~/.aws ];
  then
    echo "AWS config dir exists"
  else
    echo "Creating AWS config directory and config file"
    mkdir ~/.aws
    touch ~/.aws/config
    touch ~/.aws/credentials
  fi
  echo "Adding $AWS_PROFILE profile to a new config file"
  echo "[profile $AWS_PROFILE]
  output = json
  region = $AWS_REGION
  aws_access_key_id = $AWS_ACCESS_KEY
  aws_secret_access_key = $AWS_SECRET_KEY" >> ~/.aws/config
  echo "[$AWS_PROFILE]
  aws_access_key_id = $AWS_ACCESS_KEY
  aws_secret_access_key = $AWS_SECRET_KEY" >> ~/.aws/credentials
fi


# Give 700 permissions to the monitoring script
chmod +x $MONITORING_FILE

# Execute and see if everything goes well with the file
if bash $MONITORING_FILE
then
  # Comment out creation of alarm section etc, before pushing to crontab
  sed -i "s/aws cloudwatch put-metric-alarm/\# aws cloudwatch put-metric-alarm/" $MONITORING_FILE
  sed -i "s/echo -e/\# echo -e/" $MONITORING_FILE
  sed -i "s/sleep 1/\# sleep 1/" $MONITORING_FILE
else
  echo -e  "${red} Please make sure your AWS keys have right cloudwatch priveleges, and rerun the command${NC}"
  # Delete monitoring file to recreate when command is rerun
  rm -rf $MONITORING_FILE
  exit 1
fi

# Push to crontab
echo -e "Pushing the monitoring script to crontab..."

crontab -l > old_cron_list 2>/dev/null
cp old_cron_list temp_cron_list
echo "*/1 * * * * $PWD/$MONITORING_FILE >/dev/null 2>&1" >> temp_cron_list
cat temp_cron_list | sort  | uniq  > new_cron_list

# install crontab
crontab new_cron_list
rm -rf temp_cron_list

# Final message to User
echo -e "${green}ALL SUCCESSFUL.${NC} Now you can go to cloudwatch and modify the settings of the alarm created above\n"
exit 0
