#! /bin/bash

###############################################
# Purpose       : This script does a test run of publishing_script and if successful adds it to crontab
# Usage         : Run this script once you are done creating or editing or deleting your scripts in "user_monitoring_scripts" directory 
#
# Dependencies  : AWS CLI needs to be installed (Refer to : http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-bundle-other-os)
# Author        : Neptune.io, Inc.
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
USER_PROCESS_MONITORING_SCRIPT="nginx_process_status.sh"
USER_MEMORY_MONITORING_SCRIPT="memory_utilization.sh"
USER_DISK_MONITORING_SCRIPT="disk_utilization.sh"

# Run pushing script once to check everything is ok
echo -e "\nTest run of the publishing script..."
if bash $PUBLISHING_SCRIPT
then
  sleep 1
  echo -e "\nTest run successful"
else
  echo -e "\n${red}Test run FAILED :Please see the error messages above${NC}\n"
  exit 1
fi

# Push to crontab
echo -e "\nNow adding the metric publishing script to crontab..."

crontab -l > old_cron_list 2>/dev/null
cp old_cron_list temp_cron_list
echo "*/1 * * * * $PWD/$PUBLISHING_SCRIPT >/dev/null 2>&1" >> temp_cron_list
cat temp_cron_list | sort  | uniq  > new_cron_list

# install crontab
crontab new_cron_list
rm -rf temp_cron_list

# Final message to User
echo -e "\n${green}ALL SUCCESSFUL${NC}"
echo -e "\nNEXT STEPS :\n"
echo -e "1)Go to cloudwatch and modify the THRESHOLD settings of the alarms created. Alarm name format is: <metric_name>_on_<instance_id>\n"
exit 0
