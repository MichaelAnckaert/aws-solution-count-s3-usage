import json
import urllib.parse
import boto3

s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')

def update_usage(user_id, size_change):
    response = dynamodb.update_item(
        TableName="Users",
        Key={
            'UserId': {
                'S': user_id
            },
        },
        UpdateExpression="ADD Size :size",
        ExpressionAttributeValues={
            ':size': {
                'N': size_change
            }
        }
    )


def save_object_size(object_key, size):
    user_id = object_key.split('/')[0]

    response = dynamodb.put_item(
        TableName="Files",
        Item={
            'UserId': {
                'S': user_id
            },
            'FileName': {
                'S': object_key
            },
            'Size': {
                'N': str(size)
            }
        }
    )

    update_usage(user_id, str(size))

def remove_object_size(object_key):
    user_id = object_key.split('/')[0]
    response = dynamodb.delete_item(
        TableName="Files",
        Key={
            'UserId': {
                'S': user_id
            },
            'FileName': {
                'S': object_key
            }
        },
        ReturnValues="ALL_OLD"
    )

    size = int(response['Attributes']['Size']['N'])

    update_usage(user_id, str(0 - size))


def lambda_handler(event, context):
    # Uncomment the line below to debug the event received
    # print("Received event: " + json.dumps(event, indent=2))

    for record in event['Records']:
        event = record['eventName']
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
        size = record['s3']['object'].get('size', None)
        print(f"Got a {event} event for object '{key}' in bucket '{bucket}'. Reported size is {size or 'unknown'}")
        if event == "ObjectCreated:Put":
            save_object_size(key, size)
        elif event == "ObjectRemoved:Delete":
            remove_object_size(key)
