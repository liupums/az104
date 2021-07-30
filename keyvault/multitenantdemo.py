# 1. In Azure Portal, launch "App Registration" https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#add-a-certificate
# 2. Register Enterprise App "RegisteredAppToAccessKeyVault" using the certificate ~/keyvault/mycert2public.pem"
# 3. In the keyvault, modify the "settings->access policies", Add the access to Application "RegisteredAppToAccessKeyVault"
# 4. Run the python client
#
# Python client
# 1. dependencies
#    pip install azure.identity
#    pip install azure.keyvault
#    Trouble shooting win32file.dll loading issue https://stackoverflow.com/questions/58612306/how-to-fix-importerror-dll-load-failed-while-importing-win32api
# 2. client certificate and private key, ~/keyvault/mycert2.pem
from os import environ as env
from azure.identity import CertificateCredential
from azure.keyvault.secrets import SecretClient

# Tenant Name, tenant Id, key vault name, secret name
secrets = [ ("popMsdn", "52ab6cff-94ef-4a0c-8ba9-537fd0d249bd", "popcsakeyvaultmt", "MySecretMultiTenant"), 
            ("Microsoft", "72f988bf-86f1-41af-91ab-2d7cd011db47", "popcsakeyvault","MySecret") ]

# Application ID, aka, Client ID of popcsaregisteredapp
CLIENT_ID = env.get("AZURE_CLIENT_ID", "51ccd289-72bc-426f-b206-65bb92a28a01")
# The certificate for client to authenticate with App
CLIENT_CERT_PATH = env.get("AZURE_CLIENT_CERTIFICATE_PATH", "mycert2.pem")

for secret in secrets:
    name,tid,kv,s = secret
    KEYVAULT_NAME = kv
    KEYVAULT_URI = f"https://{KEYVAULT_NAME}.vault.azure.net/"
    SECRET_NAME = s
    print("=======")
    print(f"tenanet '{name}', Cert '{CLIENT_CERT_PATH}', keyValut '{KEYVAULT_NAME}', secret '{s}'")
    _credential = CertificateCredential(
        tenant_id=tid,
        client_id=CLIENT_ID,
        certificate_path=CLIENT_CERT_PATH
    )

    _sc = SecretClient(vault_url=KEYVAULT_URI, credential=_credential)
    MYSECRET = _sc.get_secret(SECRET_NAME).value
    print(f"Get '{MYSECRET}'")
