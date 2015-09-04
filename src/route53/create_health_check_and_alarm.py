#!/usr/bin/env python
"""
This script creates a Route 53 health check and a CloudWatch alarm to monitor the URLs given as
command-line args. The alarms will be configured to notify Neptune if the given URL is not pingable.

By default this script gets the AWS keys from your environment or ~/.aws file but if you want to
specify in the code, uncomment the params initialization and that should work.

NOTE: CloudWatch metrics for a health check will not be available immediately after the health check
      creation. Hence, this script waits for a while (maximum of ~3min), checks if the metrics are available
      and then creates CloudWatch Alarm. So, don't worry if it takes more than a minute.
"""

import boto
import sys
import time

from boto.route53.healthcheck import HealthCheck
from urlparse import urlparse

__author__ = 'buchi'

NEPTUNEIO_SNS_TOPIC = 'arn:aws:sns:us-east-1:414130290710:neptuneio-sns'
HEALTH_CHECK_PERIOD = 60
HEALTH_CHECK_EVALUATION_PERIODS = 2


def main(urls):
    # params = {
    #     'region': 'us-east-1',
    #     'aws_access_key_id': ACCESS_KEY,
    #     'aws_secret_access_key': SECRET_KEY
    # }

    route = boto.connect_route53()
    # route = boto.connect_route53(params)

    cw = boto.connect_cloudwatch()
    # cw = boto.connect_cloudwatch(params)

    url_to_healthcheck = {}
    for url in urls:
        url_to_healthcheck[url] = create_healthcheck(route, url)

    for url in url_to_healthcheck:
        create_cloudwatch_alarm(cw, url, url_to_healthcheck[url])


def create_cloudwatch_alarm(cw, url, healthcheck_id):
    print("Getting HealthCheckStatus metric for the id: " + healthcheck_id)

    # Get the CW metric for the health check.
    num_attempts = 1
    metrics = cw.list_metrics(dimensions={'HealthCheckId': healthcheck_id}, metric_name="HealthCheckStatus")
    while not metrics or len(metrics) < 1:
        if num_attempts <= 20:
            # Creating the CW metric for health check might take a while so we will wait for it.
            time.sleep(10)

            num_attempts += 1
            metrics = cw.list_metrics(dimensions={'HealthCheckId': healthcheck_id}, metric_name="HealthCheckStatus")
        else:
            print("No metrics found for the given HealthCheckId. Please double check if the healthcheck is created.")
            sys.exit(1)

    print("Creating CloudWatch alarm for URL: " + url)
    # Create CW alarm by putting the URL in name. Note that this alarm notifies Neptune if the alarm state changes.
    alarm_name = 'Neptune.io alarm for ' + url
    alarm = metrics[0].create_alarm(name=alarm_name, comparison='<', threshold=1, period=60,
                                    description='Alarm to notify if ' + url + ' is down',
                                    evaluation_periods=HEALTH_CHECK_EVALUATION_PERIODS, statistic='Minimum',
                                    alarm_actions=[NEPTUNEIO_SNS_TOPIC], ok_actions=[NEPTUNEIO_SNS_TOPIC])
    print("Successfully created alarm for URL: " + url)


def create_healthcheck(route, url):
    # Parse the URL and get required params.
    result = urlparse(url)

    hc_type = result.scheme.upper()
    default_port = 443 if hc_type == 'HTTPS' else 80
    port = result.port if result.port else default_port
    path = result.path if result.path else None
    domain = result.hostname if result.hostname else result.netloc

    # Create health check for the given URL.
    hc = HealthCheck(ip_addr="", port=port, hc_type=hc_type, resource_path=path,
                     fqdn=domain, string_match=None, request_interval=30, failure_threshold=3)
    response = route.create_health_check(hc)
    print("Created healthcheck for: " + url + "; Id: " + response.CreateHealthCheckResponse.HealthCheck.Id)
    return response.CreateHealthCheckResponse.HealthCheck.Id


if __name__ == "__main__":
    main(sys.argv[1:])
