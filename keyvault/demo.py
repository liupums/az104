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

TENANT_ID = env.get("AZURE_TENANT_ID", "72f988bf-86f1-41af-91ab-2d7cd011db47")
CLIENT_ID = env.get("AZURE_CLIENT_ID", "50fef7d4-0c86-4f5a-bed8-2f81ed1db7fb")
CLIENT_CERT_PATH = env.get("AZURE_CLIENT_CERTIFICATE_PATH", "mycert2.pem")
KEYVAULT_NAME = env.get("AZURE_KEYVAULT_NAME", "az400popliukeyvault")
KEYVAULT_URI = f"https://{KEYVAULT_NAME}.vault.azure.net/"
SECRET_NAME = env.get("AZURE_SECRET_NAME", "TestSecret")
print(f"tenanet '{TENANT_ID}', Cert '{CLIENT_CERT_PATH}', keyValut '{KEYVAULT_NAME}'")

_credential = CertificateCredential(
    tenant_id=TENANT_ID,
    client_id=CLIENT_ID,
    certificate_path=CLIENT_CERT_PATH
)

_sc = SecretClient(vault_url=KEYVAULT_URI, credential=_credential)
MYSECRET = _sc.get_secret(SECRET_NAME).value
print(f"Get '{MYSECRET}'")
