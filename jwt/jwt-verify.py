import os
from typing import Dict, List, Optional

import requests
# see https://github.com/mpdavis/python-jose
# pip install python-jose
from jose import jwt, jwk
from jose.utils import base64url_decode

JWK = Dict[str, str]
JWKS = Dict[str, List[JWK]]

TENANT = "common"
AUTHORITY = "https://login.microsoftonline.com/"
KEYSURL = f"{AUTHORITY}{TENANT}/discovery/keys"

def get_jwks() -> JWKS:
    return requests.get(KEYSURL).json()

def get_hmac_key(token: str, jwks: JWKS) -> Optional[JWK]:
    kid = jwt.get_unverified_header(token).get("kid")
    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return key

def verify_jwt(token: str, jwks: JWKS) -> bool:
    trusted_key = get_hmac_key(token, jwks)

    if not trusted_key:
        raise ValueError("No pubic key found!")

    # azure is missing the 'alg' which must be RS256
    # see google example: https://www.googleapis.com/oauth2/v3/certs
    hmac_key = jwk.construct(trusted_key, 'RS256')

    message, encoded_signature = token.rsplit(".", 1)
    decoded_signature = base64url_decode(encoded_signature.encode())

    return hmac_key.verify(message.encode(), decoded_signature)


jwks = get_jwks()
with open('token.jwt', 'r') as tokenFile:
    token = "".join(tokenFile.read().splitlines())
    if not verify_jwt(token, jwks):
        print("token not verified")
    else:
        claims = jwt.get_unverified_claims(token)
        print (claims)
