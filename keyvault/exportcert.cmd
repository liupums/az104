1.	Login to azure via cli
az login
2.	Set the default subscription
az account set --subscription "uswestcsu_internal"
3.	Download the certificate as the secret
az keyvault secret download --file certificatename.pfx --encoding base64 --name mycert --vault-name az400popliukeyvault
4.	Using “certutil” to display the downloaded pfx
certutil certificatename.pfx

Enter PFX password:
================ Certificate 0 ================
================ Begin Nesting Level 1 ================
Element 0:
Serial Number: 0adb693b4a314726b0c82f1c78bf1c50
Issuer: CN=AZ104
NotBefore: 7/9/2021 5:30 PM
NotAfter: 7/9/2022 5:40 PM
Subject: CN=AZ104
Signature matches Public Key
Root Certificate: Subject matches Issuer
Cert Hash(sha1): 5098f6f9af1fad6c715c039e206d5ef255bf3d63
----------------  End Nesting Level 1  ----------------
  Provider = Microsoft Enhanced RSA and AES Cryptographic Provider
Encryption test passed
CertUtil: -dump command completed successfully.

You can also import the pfx to your cert store and “certmgr” will show the private key exists
