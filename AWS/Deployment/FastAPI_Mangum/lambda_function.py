import os
import json
import time
import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.security import OAuth2PasswordBearer
from mangum import Mangum
from jose import jwk, jwt
from jose.utils import base64url_decode
import requests

app = FastAPI()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('DYNAMODB_TABLE_NAME', 'weh_users'))

# Cognito configuration
REGION = os.environ.get('AWS_REGION')
USERPOOL_ID = os.environ.get('COGNITO_USER_POOL_ID')
APP_CLIENT_ID = os.environ.get('COGNITO_APP_CLIENT_ID')
keys_url = f'https://cognito-idp.{REGION}.amazonaws.com/{USERPOOL_ID}/.well-known/jwks.json'
# Download the JSON Web Key (JWK) for your User Pool
response = requests.get(keys_url)
keys = response.json()['keys']

def verify_token(token: str = Depends(oauth2_scheme)):
    # Get the kid from the headers prior to verification
    headers = jwt.get_unverified_headers(token)
    kid = headers['kid']
    # Search for the kid in the downloaded public keys
    key_index = -1
    for i in range(len(keys)):
        if kid == keys[i]['kid']:
            key_index = i
            break
    if key_index == -1:
        raise HTTPException(status_code=401, detail='Public key not found in jwks.json')
    # Construct the public key
    public_key = jwk.construct(keys[key_index])
    # Get the last two sections of the token,
    # message and signature (encoded in base64)
    message, encoded_signature = str(token).rsplit('.', 1)
    # Decode the signature
    decoded_signature = base64url_decode(encoded_signature.encode('utf-8'))
    # Verify the signature
    if not public_key.verify(message.encode("utf8"), decoded_signature):
        raise HTTPException(status_code=401, detail='Signature verification failed')
    # Since we passed the verification, we can now safely
    # use the unverified claims
    claims = jwt.get_unverified_claims(token)
    # Additionally we can verify the token expiration
    if time.time() > claims['exp']:
        raise HTTPException(status_code=401, detail='Token is expired')
    # And the Audience  (use claims['client_id'] if verifying an access token)
    if claims['aud'] != APP_CLIENT_ID:
        raise HTTPException(status_code=401, detail='Token was not issued for this audience')
    # Now we can use the claims
    return claims

@app.get("/")
async def root():
    return {"message": "Welcome to Weber Brain API"}

@app.get("/users/{user_id}")
async def read_user(user_id: str, claims: dict = Depends(verify_token)):
    try:
        response = table.get_item(Key={'userId': user_id})
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    item = response.get('Item')
    if not item:
        raise HTTPException(status_code=404, detail="User not found")
    
    return item

@app.post("/users")
async def create_user(request: Request, claims: dict = Depends(verify_token)):
    user_data = await request.json()
    try:
        table.put_item(Item=user_data)
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return {"message": "User created successfully", "userId": user_data.get('userId')}

# Wrap the FastAPI app with Mangum for AWS Lambda compatibility
handler = Mangum(app)
