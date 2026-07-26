"""
Lambda function for automated EC2 remediation based on CloudWatch alarms.
Handles high CPU, memory issues, and status check failures.
"""

import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

# Initialize AWS clients
ec2_client = boto3.client('ec2')
sns_client = boto3.client('sns')
cloudwatch_client = boto3.client('cloudwatch')

# Environment variables
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'ec2-monitoring')

# Remediation actions configuration
REMEDIATION_ACTIONS = {
    'high-cpu': 'reboot',
    'high-memory': 'reboot',
    'status-check-failed': 'reboot',
}

# Cooldown period to prevent repeated actions (in minutes)
COOLDOWN_PERIOD = 30


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for EC2 remediation.
    
    Args:
        event: CloudWatch alarm event
        context: Lambda context
        
    Returns:
        Response dictionary with status and message
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse the SNS message from CloudWatch alarm
        if 'Records' in event:
            # Event from SNS
            message = json.loads(event['Records'][0]['Sns']['Message'])
        else:
            # Direct event from CloudWatch
            message = event
        
        alarm_name = message.get('AlarmName', '')
        alarm_description = message.get('AlarmDescription', '')
        new_state = message.get('NewStateValue', '')
        reason = message.get('NewStateReason', '')
        
        print(f"Alarm: {alarm_name}, State: {new_state}, Reason: {reason}")
        
        # Only act on ALARM state
        if new_state != 'ALARM':
            print(f"Alarm state is {new_state}, no action needed")
            return {
                'statusCode': 200,
                'body': json.dumps('No action needed - alarm not in ALARM state')
            }
        
        # Extract instance ID from alarm dimensions
        instance_id = None
        if 'Trigger' in message and 'Dimensions' in message['Trigger']:
            for dimension in message['Trigger']['Dimensions']:
                if dimension['name'] == 'InstanceId':
                    instance_id = dimension['value']
                    break
        
        if not instance_id:
            print("No instance ID found in alarm")
            return {
                'statusCode': 400,
                'body': json.dumps('No instance ID found in alarm')
            }
        
        print(f"Processing remediation for instance: {instance_id}")
        
        # Check if instance exists and get its state
        instance_info = get_instance_info(instance_id)
        if not instance_info:
            print(f"Instance {instance_id} not found")
            return {
                'statusCode': 404,
                'body': json.dumps(f'Instance {instance_id} not found')
            }
        
        instance_state = instance_info['State']['Name']
        print(f"Instance state: {instance_state}")
        
        # Check cooldown period
        if is_in_cooldown(instance_id, alarm_name):
            message_text = f"Instance {instance_id} is in cooldown period. Skipping remediation."
            print(message_text)
            send_notification(
                subject=f"[{PROJECT_NAME}] Remediation Skipped - Cooldown",
                message=message_text
            )
            return {
                'statusCode': 200,
                'body': json.dumps(message_text)
            }
        
        # Determine remediation action based on alarm type
        action = determine_action(alarm_name)
        
        if not action:
            print(f"No remediation action configured for alarm: {alarm_name}")
            return {
                'statusCode': 200,
                'body': json.dumps('No remediation action configured')
            }
        
        # Execute remediation
        result = execute_remediation(instance_id, action, alarm_name, instance_state)
        
        # Send notification
        send_notification(
            subject=f"[{PROJECT_NAME}] Auto-Remediation Executed",
            message=result['message']
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        error_message = f"Error in Lambda execution: {str(e)}"
        print(error_message)
        
        # Send error notification
        if SNS_TOPIC_ARN:
            send_notification(
                subject=f"[{PROJECT_NAME}] Remediation Error",
                message=error_message
            )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }


def get_instance_info(instance_id: str) -> Optional[Dict[str, Any]]:
    """
    Get EC2 instance information.
    
    Args:
        instance_id: EC2 instance ID
        
    Returns:
        Instance information dictionary or None
    """
    try:
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        if response['Reservations'] and response['Reservations'][0]['Instances']:
            return response['Reservations'][0]['Instances'][0]
        return None
    except Exception as e:
        print(f"Error getting instance info: {str(e)}")
        return None


def determine_action(alarm_name: str) -> Optional[str]:
    """
    Determine remediation action based on alarm name.
    
    Args:
        alarm_name: CloudWatch alarm name
        
    Returns:
        Action string or None
    """
    alarm_name_lower = alarm_name.lower()
    
    for key, action in REMEDIATION_ACTIONS.items():
        if key in alarm_name_lower:
            return action
    
    return None


def execute_remediation(
    instance_id: str,
    action: str,
    alarm_name: str,
    instance_state: str
) -> Dict[str, Any]:
    """
    Execute the remediation action on the instance.
    
    Args:
        instance_id: EC2 instance ID
        action: Remediation action to execute
        alarm_name: CloudWatch alarm name
        instance_state: Current instance state
        
    Returns:
        Result dictionary with status and message
    """
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    
    try:
        if action == 'reboot':
            if instance_state != 'running':
                message = (
                    f"Instance {instance_id} is in '{instance_state}' state. "
                    f"Cannot reboot. Manual intervention required."
                )
                print(message)
                return {
                    'status': 'skipped',
                    'message': message,
                    'timestamp': timestamp
                }
            
            print(f"Rebooting instance {instance_id}")
            ec2_client.reboot_instances(InstanceIds=[instance_id])
            
            message = (
                f"Auto-remediation executed successfully!\n\n"
                f"Action: Reboot\n"
                f"Instance ID: {instance_id}\n"
                f"Alarm: {alarm_name}\n"
                f"Timestamp: {timestamp}\n\n"
                f"The instance has been rebooted to resolve the issue."
            )
            
            return {
                'status': 'success',
                'action': 'reboot',
                'instance_id': instance_id,
                'message': message,
                'timestamp': timestamp
            }
        
        elif action == 'stop':
            if instance_state not in ['running', 'stopping']:
                message = f"Instance {instance_id} is in '{instance_state}' state. Cannot stop."
                print(message)
                return {
                    'status': 'skipped',
                    'message': message,
                    'timestamp': timestamp
                }
            
            print(f"Stopping instance {instance_id}")
            ec2_client.stop_instances(InstanceIds=[instance_id])
            
            message = (
                f"Auto-remediation executed successfully!\n\n"
                f"Action: Stop\n"
                f"Instance ID: {instance_id}\n"
                f"Alarm: {alarm_name}\n"
                f"Timestamp: {timestamp}\n\n"
                f"The instance has been stopped."
            )
            
            return {
                'status': 'success',
                'action': 'stop',
                'instance_id': instance_id,
                'message': message,
                'timestamp': timestamp
            }
        
        else:
            message = f"Unknown action: {action}"
            print(message)
            return {
                'status': 'error',
                'message': message,
                'timestamp': timestamp
            }
            
    except Exception as e:
        error_message = f"Error executing remediation: {str(e)}"
        print(error_message)
        return {
            'status': 'error',
            'message': error_message,
            'timestamp': timestamp
        }


def is_in_cooldown(instance_id: str, alarm_name: str) -> bool:
    """
    Check if the instance is in cooldown period to prevent repeated actions.
    
    Args:
        instance_id: EC2 instance ID
        alarm_name: CloudWatch alarm name
        
    Returns:
        True if in cooldown, False otherwise
    """
    try:
        # Check CloudWatch metrics for recent remediation actions
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=COOLDOWN_PERIOD)
        
        # Query custom metric for remediation actions
        response = cloudwatch_client.get_metric_statistics(
            Namespace='CustomMetrics/Remediation',
            MetricName='RemediationAction',
            Dimensions=[
                {'Name': 'InstanceId', 'Value': instance_id},
                {'Name': 'AlarmName', 'Value': alarm_name}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=60,
            Statistics=['Sum']
        )
        
        # If there are data points, we're in cooldown
        if response['Datapoints']:
            return True
        
        # Record this remediation action
        cloudwatch_client.put_metric_data(
            Namespace='CustomMetrics/Remediation',
            MetricData=[
                {
                    'MetricName': 'RemediationAction',
                    'Dimensions': [
                        {'Name': 'InstanceId', 'Value': instance_id},
                        {'Name': 'AlarmName', 'Value': alarm_name}
                    ],
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        return False
        
    except Exception as e:
        print(f"Error checking cooldown: {str(e)}")
        # On error, allow the action to proceed
        return False


def send_notification(subject: str, message: str) -> None:
    """
    Send SNS notification.
    
    Args:
        subject: Email subject
        message: Email message body
    """
    if not SNS_TOPIC_ARN:
        print("SNS_TOPIC_ARN not configured, skipping notification")
        return
    
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        print(f"Notification sent: {subject}")
    except Exception as e:
        print(f"Error sending notification: {str(e)}")
