import boto3, json, logging
logger = logging.getLogger()

asg_client = boto3.client('autoscaling')
ec2_client = boto3.client('ec2')
def handler (event, context):
    AutoScalingGroupName = event['AsgName']
    asg_response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[AutoScalingGroupName])
    instance_ids = []
    for i in asg_response['AutoScalingGroups']:
      for k in i['Instances']:
        instance_ids.append(k['InstanceId'])
    if instance_ids != []:
      ec2_client.terminate_instances(
        InstanceIds = instance_ids
      )
    responseValue = 1
    responseData = {}
    responseData['Data'] = responseValue

    logger.info("Finished terminating instances for ASG " + AutoScalingGroupName)