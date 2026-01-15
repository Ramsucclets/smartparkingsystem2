import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ParkingSpots') 

def lambda_handler(event, context):
    print(f"Full Event: {json.dumps(event)}")
    
    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method')
    
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
    }

    if method == "GET":
        try:
            response = table.scan(ConsistentRead=True)
            items = response.get('Items', [])
        
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'success': True, 'spots': items}, default=str)
            }
        except Exception as e:
            print(f"GET Error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': str(e)})
            }

    elif method == "POST":
        try:
            body = event.get('body', "{}")
            if isinstance(body, str):
                body = json.loads(body)
            
            spot_id = str(body.get('spotId', '')).strip()
            status_value = str(body.get('status', '')).strip()
            
            if not spot_id or not status_value:
                return {
                    'statusCode': 400,
                    'headers': headers,
                    'body': json.dumps({'error': 'Missing spotId or status in request body'})
                }

            timestamp = datetime.utcnow().isoformat()
            is_occupied_bool = status_value.lower() in ['taken', 'occupied']

            table.update_item(
                Key={'spotId': spot_id},
                UpdateExpression="set #s = :val, lastUpdated = :t, #occ = :boolVal",
                ExpressionAttributeNames={
                    '#s': 'status',      
                    '#occ': 'isOccupied'
                },
                ExpressionAttributeValues={
                    ':val': status_value,
                    ':t': timestamp,
                    ':boolVal': is_occupied_bool
                }
            )

            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'success': True, 
                    'message': f'Spot {spot_id} updated to {status_value}',
                    'isOccupiedSetTo': is_occupied_bool
                })
            }
            
        except Exception as e:
            print(f"POST Error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': str(e)})
            }

    elif method == "OPTIONS":
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS Preflight Success'})
        }

    return {
        'statusCode': 405,
        'headers': headers,
        'body': json.dumps({'error': f'Method {method} not allowed'})
    }
